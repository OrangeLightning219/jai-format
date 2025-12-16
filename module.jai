#scope_file
#import "Basic";
#import "File";
#import "String";
#import "Hash_Table";
#import "Reflection";
#import "Text_File_Handler";
#import "Flat_Pool";

#import "jai_parser";

#scope_export
Node_Visit_Data :: struct {}
node_visit :: ( node: *Node, user_data: Node_Visit_Data ) {}
Formatter_Config :: struct
{
    spaces_inside_parens := false;
    spaces_inside_brackets := false;
    spaces_inside_literals := false;
    spaces_around_operators := true;
    wrap_before_operators := false;

    alignment_mode := Alignment_Mode.EXACT;
    declaration_alignment_mode := Alignment_Mode.NOT_SET;
    expression_alignment_mode := Alignment_Mode.NOT_SET;
    parens_alignment_mode := Alignment_Mode.NOT_SET;
    brackets_alignment_mode := Alignment_Mode.NOT_SET;
    struct_literal_alignment_mode := Alignment_Mode.NOT_SET;

    single_statement_brace_mode := Single_Statement_Brace_Mode.DONT_MODIFY;
    single_statement_line_mode := Single_Statement_Line_Mode.DONT_MODIFY;
    single_statement_double_space := false;
    braces_on_new_line := false;
    quick_lambda_brace_on_new_line := false;
    else_on_new_line := false;
    indent_case := false;
    surround_multiple_returns_with_parens := false;
    insert_space_in_single_line_comments := true;
    keep_whitespace_before_single_line_comments := false;
    max_empty_lines_to_keep := 1;

    indent_mode := Indent_Mode.SPACES;
    indent_width := 4;
    tab_width := 4;

    no_carriage_return_on_windows := false;
}

Indent_Mode :: enum
{
    SPACES;
    TABS;
}

Single_Statement_Brace_Mode :: enum
{
    DONT_MODIFY;
    FORCE_ADD;
    FORCE_REMOVE;
}

Single_Statement_Line_Mode :: enum
{
    DONT_MODIFY;
    SAME_LINE;
    NEW_LINE;
}

Alignment_Mode :: enum
{
    NOT_SET;
    DISABLED;
    INDENT_ONLY;
    EXACT;
}

Jai_Formatter :: struct( Parser_Visit_Type: Type = Node_Visit_Data )
{
    pool: Flat_Pool;

    indent_level: int;
    indent_string: string;
    current_line: int = -1;
    previous_line: int;

    current_collumn: int;
    current_alignment: int;
    alignments: [ .. ]int;
    previous_print_type: enum { STRING; NEW_LINE; TAB; INDENT; SPACE; SEMICOLON; }
    new_scope_started: bool;

    current_min_source_collumn: int;
    current_max_source_collumn: int;
    last_node: *Node;

    inside_arguments: bool;
    inside_arguments_count: int;
    inside_code_argument: bool;
    inside_code_argument_count: int;
    aligned_inside_assignment: bool;

    current_comment_index: int;

    parser: Parser( Parser_Visit_Type );
    buffer_allocator: Allocator;
    buffer: []u8;
    max_buffer_size: int;

    using config: Formatter_Config;

    #if FORMATTER_ENABLE_PROFILING
    {
        lexing_time: float64;
        parsing_time: float64;
        formatting_time: float64;
    }
}

FORMATTER_ENABLE_PROFILING :: true;
// FORMATTER_ENABLE_PROFILING :: false;

make_formatter :: ( config: Formatter_Config ) -> Jai_Formatter( Node_Visit_Data )
{
    f: Jai_Formatter( Node_Visit_Data );
    init( *f.pool );
    f.buffer_allocator = context.allocator;
    f.config = config;
    f.indent_string = get_indent_string( config );

    // NOTE: Start with 1MB
    f.max_buffer_size = 1024 * 1024;
    f.buffer = NewArray( f.max_buffer_size, u8 );
    f.buffer.count = 0;

    return f;
}

reset_formatter :: ( f: *Jai_Formatter )
{
    reset( *f.pool );
    f.buffer.count = 0;
}

deinit_formatter :: ( f: *Jai_Formatter )
{
    fini( *f.pool );
    free( f.buffer.data,, f.buffer_allocator );
    free( f.indent_string,, f.buffer_allocator );
}

Formatter_Status :: enum
{
    OK;
    ERROR;
    SKIPPED;
}

format_file :: ( f: *Jai_Formatter, file: string ) -> Formatter_Status, string
{
    reset_formatter( f );
    push_allocator( get_allocator( *f.pool ) );

    filename := path_filename( file );
    if !ends_with( filename, ".jai" ) || starts_with( filename, ".added_strings" )
    {
        return .SKIPPED, "";
    }

    log( "Reading file '%'.", file, flags = .VERBOSE_ONLY );
    source_code, ok := read_entire_file( file );
    if !ok
    {
        log_error( "Failed to read file: %.", file );
        return .ERROR, "";
    }
    log( "Reading file '%' done.", file, flags = .VERBOSE_ONLY );

    nodes := get_nodes( f, source_code, file );
    if nodes.count == 0
    {
        log_error( "Failed to parse file '%'. Parser returned 0 nodes.", file );
        return .ERROR, "";
    }

    status, output := format_from_nodes( f, nodes, file );
    return status, output;
}

// NOTE: file is only passed for logging purposes
format_from_string :: ( f: *Jai_Formatter, source_code: string, file := "" ) -> Formatter_Status, string
{
    reset_formatter( f );
    push_allocator( get_allocator( *f.pool ) );

    nodes := get_nodes( f, source_code, file );
    if nodes.count == 0
    {
        log_error( "Failed to parse '%'. Parser returned 0 nodes.", ifx file else "string" );
        return .ERROR, "";
    }

    status, result := format_from_nodes( f, nodes, file );
    return status, result;
}

load_config :: ( file: string ) -> Formatter_Config
{
    result: Formatter_Config;

    handler: Text_File_Handler;
    handler.do_version_number = false;

    log( "Loading config file: '%'.", file, flags = .VERBOSE_ONLY );
    start_file( *handler, "config", file );
    if handler.failed
    {
        log_error( "Failed to load config '%'. Using default configuration.", file );
        return result;
    }
    defer deinit( *handler );

    unique_keys: Table( string, bool );
    while true
    {
        line, found := consume_next_line( *handler );
        if !found then break;

        key, value := break_by_spaces( line );
        if !value
        {
            log_error( "Missing value for option: '%'.", key );
            continue;
        }

        if table_contains( *unique_keys, key )
        {
            log_error( "Ignoring duplicated option: '%' at line %.", key, handler.line_number );
            continue;
        }

        table_add( *unique_keys, key, true );

        field := get_field( type_info( Formatter_Config ), key );
        if field
        {
            any: Any;
            any.type = field.type;
            any.value_pointer = ( *result ).( *u8 ) + field.offset_in_bytes;
            ok := set_value_from_string( any, value );
            if !ok
            {
                log_error( "Failed to set option '%'. Value was: '%'.", key, value );
            }
        }
        else
        {
            log_error( "Invalid configuration option '%' at line %", key, handler.line_number );
        }
    }

    result.max_empty_lines_to_keep = max( 0, result.max_empty_lines_to_keep );
    result.indent_width = max( 0, result.indent_width );

    log( "Loading config file: '%' done.", file, flags = .VERBOSE_ONLY );
    return result;
}

#scope_file

get_nodes :: ( f: *Jai_Formatter, source_code: string, file := "" ) -> [ .. ]*Node
{
    log( "Lexing '%'.", ifx file else "string", flags = .VERBOSE_ONLY );
    #if FORMATTER_ENABLE_PROFILING { lexing_start := seconds_since_init(); }
    // TODO: Catch lexing/parsing errors and don't format if there are any.
    lexer := New( Lexer );
    lexer.* = create_lexer( source_code, file );
    #if FORMATTER_ENABLE_PROFILING { f.lexing_time = seconds_since_init() - lexing_start; }
    log( "Lexing '%' done.", ifx file else "string", flags = .VERBOSE_ONLY );

    nodes: [ .. ]*Node;
    if lexer.tokens.count == 0
    {
        log_error( "Failed to lex '%'. Looks like it's empty.", ifx file else "string" );
    }
    else
    {
        f.parser = .{};
        f.parser.node_visit = node_visit;
        f.parser.lexer = lexer;

        log( "Parsing '%'.", ifx file else "string", flags = .VERBOSE_ONLY );
        #if FORMATTER_ENABLE_PROFILING { parsing_start := seconds_since_init(); }
        while !end( f.parser.lexer )
        {
            node := parse( *f.parser, null );
            if node
            {
                array_add( *nodes, node );
            }
        }
        #if FORMATTER_ENABLE_PROFILING { f.parsing_time = seconds_since_init() - parsing_start; }
        log( "Parsing '%' done.", ifx file else "string", flags = .VERBOSE_ONLY );
    }

    return nodes;
}

// NOTE: file is only passed for logging purposes
format_from_nodes :: ( f: *Jai_Formatter, nodes: []*Node, file := "" ) -> Formatter_Status, string
{
    push_allocator( get_allocator( *f.pool ) );

    if f.parser.lexer.has_syntax_errors
    {
        log_error( "Not formatting because code has syntax errors." );
        return .ERROR, "";
    }

    log( "Formatting '%'.", ifx file else "string", flags = .VERBOSE_ONLY );
    #if FORMATTER_ENABLE_PROFILING { formatting_start := seconds_since_init(); }
    for nodes
    {
        print_node( f, xx it );
    }

    for f.current_comment_index..f.parser.lexer.comments.count - 1
    {
        // NOTE: Print any leftover comments
        print_comment( f );
    }

    #if FORMATTER_ENABLE_PROFILING { f.formatting_time = seconds_since_init() - formatting_start; }
    log( "Formatting '%' done.", ifx file else "string", flags = .VERBOSE_ONLY );

    #if FORMATTER_ENABLE_PROFILING
    {
        total := f.lexing_time + f.parsing_time + f.formatting_time;
        log( "Lexing time:     %\n", f.lexing_time, flags = .VERBOSE_ONLY );
        log( "Parsing time:    %\n", f.parsing_time, flags = .VERBOSE_ONLY );
        log( "Formatting time: %\n", f.formatting_time, flags = .VERBOSE_ONLY );
        log( "Total time:      %\n", total, flags = .VERBOSE_ONLY );
    }

    if !ends_with( xx f.buffer, "\n" )
    {
        maybe_print_new_line( f, true );
    }

    return .OK, xx f.buffer;
}

// ============== Printing fucntions ============== 

print_node :: ( f: *Jai_Formatter, node: *Node, no_semicolon := false )
{
    if !node then return;

    print_comments( f, node );

    if node.location.l0 > f.current_line
    {
        f.current_max_source_collumn = 0;
        f.current_min_source_collumn = 1000;
    }

    lines_added := insert_new_lines( f, node );
    if lines_added == 0 && f.previous_print_type == .SEMICOLON &&
       !node_is( node, .NOTE ) // TODO: Are there any other nodes that don't need this space?
    {
        space( f );
    }

    f.current_min_source_collumn = min( f.current_min_source_collumn, node.location.c0 );
    f.current_max_source_collumn = max( f.current_max_source_collumn, node.location.c1 );

    log( "print node: %, %", node.kind, node.location );

    if node.kind ==
    {
    case .BLOCK;
        print_block( f, xx node );
        if node.location.l1 > f.current_line
        {
            f.previous_line = f.current_line;
            f.current_line = node.location.l1;
        }
    case .IDENTIFIER; print_identifier( f, xx node, no_semicolon );
    case .TYPE_INSTANTIATION; print_type_instantiation( f, xx node );
    case .DECLARATION; print_declaration( f, xx node, no_semicolon = no_semicolon );
    case .COMPOUND_DECLARATION; print_compound_declaration( f, xx node );
        // NOTE: This should only be called from print_compound_declaration;
        // case .COMPOUND_DECLARATION_ITEM; print_compound_declaration_item(f, xx node);
    case .COMMA_SEPARATED_EXPRESSION; print_comma_separated_expression( f, xx node );
    case .NOTE; print_note( f, xx node );

    case .PROCEDURE; print_procedure( f, xx node );
    case .PROCEDURE_CALL; print_procedure_call( f, xx node, no_semicolon );
    case .POLYMORPHIC_CONSTANT; print_polymorphic_constant( f, xx node );
    case .RETURN_VALUE; print_return_value( f, xx node );
    case .RETURN; print_return( f, xx node );

    case .OPERATOR_OVERLOAD; print_operator_overload( f, xx node );
    case .BINARY_OPERATION; print_binary_operation( f, xx node, no_semicolon );
    case .UNARY_OPERATION; print_unary_operation( f, xx node );
    case .ARRAY_TYPE; print_array_type( f, xx node );
    case .ARRAY_SUBSCRIPT; print_array_subscript( f, xx node );
    case .LITERAL; print_literal( f, xx node );

    case .IF; print_if( f, xx node );
    case .CASE; print_case( f, xx node );
    case .FOR; print_for( f, xx node );
    case .WHILE; print_while( f, xx node );
    case .BREAK; print_break( f, xx node, no_semicolon );
    case .REMOVE; print_remove( f, xx node, no_semicolon );
    case .CONTINUE; print_continue( f, xx node, no_semicolon );
    case .DEFER; print_defer( f, xx node );

    case .STRUCT; print_struct( f, xx node );
    case .ENUM; print_enum( f, xx node );
    case .UNION; print_union( f, xx node );

    case .CAST; print_cast( f, xx node );
    case .USING; print_using( f, xx node );
    case .QUICK_LAMBDA; print_quick_lambda( f, xx node );
    case .PUSH_CONTEXT; print_push_context( f, xx node );
    case .INLINE_ASSEMBLY; print_inline_assembly( f, xx node );
    case .INITIALIZE_ZERO;
        print( f, "---" );
    case;
        #insert -> string
        {
            FORMAT :: #string,\% DONE
            if node.kind ==
            {
                %
            }
            DONE

            builder: String_Builder;
            ti := type_info( Node.Kind );

            for ti.names
            {
                if starts_with( it, "DIRECTIVE" )
                {
                    type_name := to_lower_copy( it );
                    type_name[ 0 ] = to_upper( type_name[ 0 ] );
                    for type_name
                    {
                        if it == #char "_" && it_index + 1 < type_name.count
                        {
                            type_name[ it_index + 1 ] = to_upper( type_name[ it_index + 1 ] );
                        }
                    }
                    print( *builder, "case .%; print_directive(f, cast(*%)node, no_semicolon);\n", it, type_name );
                }
            }

            print( *builder, "case; print( \"Unsupported node kind: \%\\n\", node.kind );\n" );
            return tprint( FORMAT, builder_to_string( *builder ) );
        }
    }

    f.last_node = node;
}

print_block :: ( f: *Jai_Formatter, b: *Block, is_modify := false )
{
    // TODO: Make sure that clearing the alignment is ok here. 
    clear_alignment( f );
    f.previous_line = f.current_line;
    f.current_line = b.location.l0;
    single_line := b.location.l0 == b.location.l1;
    on_new_line: bool;
    parent_is_lambda_or_code := parent_is( b, .QUICK_LAMBDA ) || parent_is( b, .DIRECTIVE_CODE );
    if parent_is_lambda_or_code
    {
        on_new_line = f.quick_lambda_brace_on_new_line && b.members.count != 0;
    }
    else
    {
        // NOTE: If we're below the parent in the original code that means insert_new_lines already inserted a proper amount of new lines. 
        same_line_as_parent := f.previous_print_type == .STRING || f.previous_print_type == .SEMICOLON;
        // same_line_as_parent := b.location.l0 == b.parent.location.l0;
        on_new_line = f.braces_on_new_line && ( ( !same_line_as_parent && single_line ) || ( !single_line && same_line_as_parent ) );
    }

    if b.no_aoc
    {
        print( f, "#no_aoc" );
    }

    maybe_print_new_line( f, on_new_line );
    space_already_added := f.previous_print_type == .SPACE;
    maybe_print_space( f, !space_already_added && ( !f.braces_on_new_line || ( single_line && !on_new_line ) ) );

    if on_new_line
    {
        indent( f );
    }
    print( f, "{" );
    f.new_scope_started = true;

    is_empty := b.members.count == 0;
    first_member_on_same_line := !is_empty && b.members[ 0 ].location.l0 == b.location.l0;

    if !single_line
    {
        f.indent_level += 1;
    }

    maybe_print_space( f, single_line && !is_empty && f.spaces_inside_parens );
    new_line_after_brace := !single_line && ( is_empty || first_member_on_same_line );
    maybe_print_new_line( f, new_line_after_brace, should_indent = first_member_on_same_line );

    for b.members
    {
        print_node( f, it );
        maybe_print_space( f, single_line && it_index != b.members.count - 1 );
    }

    comments_printed := print_comments( f, b, true, new_line_after_brace && is_empty );

    maybe_print_space( f, single_line && !is_empty && f.spaces_inside_parens );
    maybe_print_new_line( f, comments_printed || ( !single_line && !is_empty ) );

    if !single_line
    {
        f.indent_level -= 1;
    }

    if !single_line
    {
        indent( f );
    }
    print( f, "}" );

    f.new_scope_started = false;
}

print_identifier :: ( f: *Jai_Formatter, i: *Identifier, no_semicolon := false )
{
    if i.backticked then print( f, "`" );
    print( f, i.name );
    if !f.inside_arguments && standalone_expression( i ) && !no_semicolon then semicolon( f );
}

print_type_instantiation :: ( f: *Jai_Formatter, t: *Type_Instantiation )
{
    if t.pointer
    {
        print( f, "*" );
    }

    print_node( f, t.expression );
}

print_declaration :: ( f: *Jai_Formatter, d: *Declaration, compound_type := Compound_Declaration_Item.Item_Kind.DECLARATION, no_semicolon := false )
{
    if d.backticked then print( f, "`" );

    print( f, d.name );

    // NOTE: Name is not set in compound declarations 
    compound := d.name.count == 0;

    if d.type_inst
    {
        print( f, ":" );
        space( f );
        print_node( f, d.type_inst );
    }

    if d.expression
    {
        maybe_print_space( f, f.spaces_around_operators && !( d.const && d.type_inst ) );
        op: string;
        if d.const
        {
            op = ifx d.type_inst then ":" else "::";
        }
        else
        {
            if compound
            {
                op = ifx d.type_inst then "=" else ifx compound_type == .DECLARATION then ":=" else "=";
            }
            else
            {
                op = ifx d.type_inst then "=" else ":=";
            }
        }
        print( f, op );

        maybe_print_space( f, f.spaces_around_operators );

        standalone := standalone_expression( d );
        if standalone then push_alignment( f, f.declaration_alignment_mode );
        print_node( f, d.expression );
        if standalone then pop_alignment( f );
    }

    if d.has_elsewhere
    {
        print( f, " #elsewhere" );
        if d.elsewhere
        {
            print( f, " %", d.elsewhere );
            if d.elsewhere_alias
            {
                print( f, " \"%\"", d.elsewhere_alias );
            }
        }
    }

    if d.alignment > 0
    {
        print( f, " #align %", d.alignment );
    }

    check := d.expression;
    if !d.expression && d.type_inst
    {
        check = d.type_inst;
        if node_is( d.type_inst, .UNARY_OPERATION )
        {
            check = d.type_inst.( *Unary_Operation ).expression;
        }
        else if node_is( d.type_inst, .ARRAY_TYPE )
        {
            check = d.type_inst.( *Array_Type ).element_type;
        }
    }

    // TODO: This is ugly. Figure out something better here
    is_insert_with_block := node_is( check, .DIRECTIVE_INSERT ) && node_is( check.( *Directive_Insert ).expression, .BLOCK );
    is_run_with_block := node_is( check, .DIRECTIVE_RUN ) && node_is( check.( *Directive_Run ).expression, .BLOCK );
    is_code_with_block := node_is( check, .DIRECTIVE_CODE ) && node_is( check.( *Directive_Code ).expression, .BLOCK );
    ti := d.type_inst;
    not_struct_ti := !ti || ( ti && !node_is( ti, .STRUCT ) &&
                              !node_is( ti, .ENUM ) &&
                              !node_is( ti, .UNION ) );
    not_struct_exp := !node_is( d.expression, .STRUCT ) &&
                      !node_is( d.expression, .ENUM ) &&
                      !node_is( d.expression, .UNION );
    if !node_is( d.expression, .PROCEDURE ) &&
       !node_is( d.expression, .DIRECTIVE_STRING ) &&
       !is_insert_with_block &&
       !is_run_with_block &&
       !is_code_with_block &&
       not_struct_ti &&
       not_struct_exp &&
       // !compound &&
       !f.inside_arguments &&
       !no_semicolon
    {
        semicolon( f );
    }

    for d.notes
    {
        print_node( f, it );
    }
}

print_compound_declaration :: ( f: *Jai_Formatter, d: *Compound_Declaration )
{
    last_type := d.members[ d.members.count - 1 ].( *Compound_Declaration_Item ).item_kind;

    for d.members
    {
        print_compound_declaration_item( f, xx it, it_index == d.members.count - 1, last_type );
        maybe_print_comma( f, d.members, it_index );
    }

    if d.type_inst
    {
        print_declaration( f, d.type_inst, last_type );
    }
}

print_compound_declaration_item :: ( f: *Jai_Formatter, i: *Compound_Declaration_Item, last: bool, last_type: Compound_Declaration_Item.Item_Kind )
{
    print_node( f, i.expression );
    if last || i.item_kind == last_type then return;
    if i.item_kind ==
    {
    case .DECLARATION;
        print( f, ":" );
    case .ASSIGN;
        print( f, "=" );
    }
}

print_comma_separated_expression :: ( f: *Jai_Formatter, e: *Comma_Separated_Expression )
{
    if e.surrounded_with_parens then open_paren( f );
    else push_alignment( f, f.expression_alignment_mode );
    comma_separated_node_list( f, e.members );
    if e.surrounded_with_parens then close_paren( f );
    else pop_alignment( f );
}

print_note :: ( f: *Jai_Formatter, n: *Note )
{
    print( f, " @%", n.value );
}

print_procedure :: ( f: *Jai_Formatter, p: *Procedure )
{
    if is_set( p, .INLINE ) then print( f, "inline " );
    empty_args := p.arguments.count == 0;
    open_paren( f, !empty_args );

    begin_arguments( f );
    for p.arguments
    {
        print_node( f, it );
        maybe_print_comma( f, p.arguments, it_index );
    }
    end_arguments( f );

    close_paren( f, !empty_args );

    if p.returns
    {
        print( f, " -> " );

        with_parens := f.surround_multiple_returns_with_parens || p.returns_surrounded_with_parens;
        if with_parens then open_paren( f );
        if !with_parens then push_alignment( f, f.expression_alignment_mode );

        begin_arguments( f );
        for p.returns
        {
            print_node( f, it );
            maybe_print_comma( f, p.returns, it_index );
        }
        end_arguments( f );

        if with_parens then close_paren( f );
        if !with_parens then pop_alignment( f );
    }

    print_directive :: ( directive: string ) #expand
    {
        print( `f, " #%", directive );
    }

    if is_set( p, .MACRO ) then print_directive( "expand" );
    if is_set( p, .NO_CONTEXT ) && !is_set( p, .C_CALL ) then print_directive( "no_context" );
    if is_set( p, .DEBUG_DUMP ) then print_directive( "dump" );
    if is_set( p, .CPP_METHOD ) then print_directive( "cpp_method" );
    if is_set( p, .CPP_RETURN_TYPE_IS_NON_POD ) then print_directive( "cpp_return_type_is_non_pod" );
    if is_set( p, .NO_DEBUG ) then print_directive( "no_debug" );
    if is_set( p, .C_CALL ) then print_directive( "c_call" );
    if is_set( p, .COMPILER ) then print_directive( "compiler" );
    if is_set( p, .NO_CALL ) then print_directive( "no_call" );
    if is_set( p, .NO_ALIAS ) then print_directive( "no_alias" );
    if is_set( p, .RUNTIME_SUPPORT ) then print_directive( "runtime_support" );
    if is_set( p, .SYMMETRIC ) then print_directive( "symmetric" );
    if is_set( p, .NO_ABC ) then print_directive( "no_abc" );
    if is_set( p, .NO_AOC ) then print_directive( "no_aoc" );

    if is_set( p, .INTRINSIC )
    {
        print_directive( "intrinsic" );
        if p.intrinsic
        {
            if p.intrinsic_is_string
            {
                print( f, " \"%\"", p.intrinsic );
            }
            else
            {
                print( f, " %", p.intrinsic );
            }
        }
    }

    if is_set( p, .ELSEWHERE )
    {
        print_directive( "elsewhere" );
        if p.elsewhere
        {
            print( f, " %", p.elsewhere );
            if p.elsewhere_alias
            {
                print( f, " \"%\"", p.elsewhere_alias );
            }
        }
    }

    if is_set( p, .FOREIGN )
    {
        print_directive( "foreign" );
        print( f, " %", p.foreign_lib );
        if p.foreign_alias
        {
            print( f, " \"%\"", p.foreign_alias );
        }
    }

    if is_set( p, .DEPRECATED )
    {
        print_directive( "deprecated" );
        if p.deprecated_note
        {
            print( f, " \"%\"", p.deprecated_note );
        }
    }

    if p.modify_block
    {
        maybe_print_new_line( f, true );
        print( f, "#modify" );
        print_block( f, p.modify_block, true );
    }

    if p.body
    {
        print_node( f, p.body );
    }

    for p.notes
    {
        print_node( f, it );
    }

    // NOTE: If a procedure is marked as intrinsic, foreign or elsewhere there shouldn't be a body.
    if ( is_set( p, .INTRINSIC ) ||
         is_set( p, .FOREIGN ) ||
         is_set( p, .ELSEWHERE ) ) &&
       !p.body
    {
        semicolon( f );
    }
}

print_procedure_call :: ( f: *Jai_Formatter, p: *Procedure_Call, no_semicolon := false )
{
    if p.inlined
    {
        print( f, "inline " );
    }

    if p.backticked
    {
        print( f, "`" );
    }

    if p.procedure
    {
        print_node( f, p.procedure );
    }

    empty_args := p.arguments.count == 0 && p.context_changes.count == 0;
    open_paren( f, !empty_args );

    begin_arguments( f );
    for p.arguments
    {
        print_node( f, it );
        maybe_print_comma( f, p.arguments, it_index );
    }

    if p.context_changes
    {
        print( f, ",, " );
        for p.context_changes
        {
            print_node( f, it );
            maybe_print_comma( f, p.context_changes, it_index );
        }
    }

    end_arguments( f );

    close_paren( f, !empty_args );

    if standalone_expression( p ) && !no_semicolon
    {
        semicolon( f );
    }
}

print_polymorphic_constant :: ( f: *Jai_Formatter, c: *Polymorphic_Constant )
{
    print( f, "$" );
    if c.maybe_constant then print( f, "$" );
    print_node( f, c.expression );
    if c.restriction
    {
        maybe_print_space( f, f.spaces_around_operators );
        print( f, "/" );
        maybe_print_space( f, f.spaces_around_operators );
        if c.restrictions_interface then print( f, "interface " );
        print_node( f, c.restriction );
    }
}

print_return_value :: ( f: *Jai_Formatter, r: *Return_Value )
{
    if r.expression
    {
        print_node( f, r.expression );
    }

    if r.must
    {
        print( f, " #must" );
    }
}

print_return :: ( f: *Jai_Formatter, r: *Return )
{
    if r.backticked then print( f, "`" );
    print( f, "return" );
    maybe_print_space( f, r.returns.count > 0 );
    push_alignment( f, f.expression_alignment_mode );
    comma_separated_node_list( f, r.returns );
    if !parent_is( r, .DIRECTIVE_CODE )
    {
        semicolon( f );
    }
    pop_alignment( f );
}

print_operator_overload :: ( f: *Jai_Formatter, o: *Operator_Overload )
{
    print( f, "operator %", get_operator_string( o.operation ) );
    if o.procedure
    {
        space( f );
        print( f, "::" );
        space( f );
        print_node( f, o.procedure );
    }
}

print_binary_operation :: ( f: *Jai_Formatter, op: *Binary_Operation, no_semicolon := false )
{
    if op.left
    {
        print_node( f, op.left );
    }

    add_line: bool;
    if op.right
    {
        right_line := op.right.location.l0;
        add_line = right_line > f.current_line && f.wrap_before_operators;
        maybe_print_new_line( f, add_line, true );
    }
    print_operator( f, op.operation );
    if add_line then f.current_line += 1;

    standalone := standalone_expression( op );
    if op.right
    {
        if standalone && is_operator_assignment( op.operation )
        {
            f.aligned_inside_assignment = true;
            push_alignment( f, f.declaration_alignment_mode );
        }
        print_node( f, op.right );
    }
    else
    {
        if f.spaces_around_operators
        {
            remove_spaces( f, 1 );
            f.previous_print_type = .STRING;
        }
    }

    if !no_semicolon && standalone
    {
        semicolon( f );
        if f.aligned_inside_assignment
        {
            f.aligned_inside_assignment = false;
            pop_alignment( f );
        }
    }
}

print_unary_operation :: ( f: *Jai_Formatter, op: *Unary_Operation )
{
    if op.operation != .POINTER_DEREFERENCE
    {
        print_operator( f, op.operation );
    }

    if op.expression
    {
        print_node( f, op.expression );
    }

    if op.operation == .POINTER_DEREFERENCE
    {
        print_operator( f, op.operation );
    }
}

print_array_type :: ( f: *Jai_Formatter, t: *Array_Type )
{
    print( f, "[" );
    is_view := !t.resizable && t.dimension == null;
    maybe_print_space( f, f.spaces_inside_brackets && !is_view );
    if t.resizable
    {
        print( f, ".." );
    }
    else
    {
        print_node( f, t.dimension );
    }
    maybe_print_space( f, f.spaces_inside_brackets && !is_view );
    print( f, "]" );

    print_node( f, t.element_type );
}

print_array_subscript :: ( f: *Jai_Formatter, a: *Array_Subscript )
{
    print_node( f, a.expression );
    print( f, "[" );
    maybe_print_space( f, f.spaces_inside_brackets );
    push_alignment( f, f.brackets_alignment_mode );
    print_node( f, a.subscript );
    pop_alignment( f );
    maybe_print_space( f, f.spaces_inside_brackets );
    print( f, "]" );
}

print_literal :: ( f: *Jai_Formatter, l: *Literal )
{
    if l.value_type ==
    {
    case .UNINITIALIZED;
    case .INT;
        print( f, l._string );
    case .FLOAT;
        print( f, l._string );
    case .STRING;
        print( f, "\"%\"", l._string );
    case .BOOL;
        print( f, ifx l._bool then "true" else "false" );
    case .ARRAY;
        array_info := l.array_literal_info;

        if array_info.element_type
        {
            print_node( f, array_info.element_type );
        }

        is_empty := array_info.elements.count == 0;
        print( f, ".[" );
        maybe_print_space( f, f.spaces_inside_literals && !is_empty );

        push_alignment( f, f.brackets_alignment_mode );
        for array_info.elements
        {
            print_node( f, it );
            maybe_print_comma( f, array_info.elements, it_index );
        }
        pop_alignment( f );

        maybe_print_space( f, f.spaces_inside_literals && !is_empty );
        print( f, "]" );
    case .STRUCT;
        struct_info := l.struct_literal_info;

        if struct_info.type
        {
            print_node( f, struct_info.type );
        }

        is_empty := struct_info.body.count == 0;
        print( f, ".{" );
        maybe_print_space( f, f.spaces_inside_literals && !is_empty );

        push_alignment( f, f.struct_literal_alignment_mode );
        for struct_info.body
        {
            print_node( f, it );
            maybe_print_comma( f, struct_info.body, it_index );
        }
        pop_alignment( f );

        maybe_print_space( f, f.spaces_inside_literals && !is_empty );
        print( f, "}" );
    }

    if parent_is( l, .BLOCK ) then semicolon( f );
}

print_if :: ( f: *Jai_Formatter, i: *If )
{
    if i.compile_time
    {
        print( f, "#" );
    }

    if i.if_kind ==
    {
    case .IF; #through;
    case .SWITCH;
        print( f, "if" );
    case .IFX;
        print( f, "ifx" );
    }
    space( f );

    if i.marked_as_complete
    {
        print( f, "#complete " );
    }

    push_alignment( f, f.expression_alignment_mode );

    if i.condition
    {
        print_node( f, i.condition, true );
    }

    pop_alignment( f );

    if i.no_aoc
    {
        print( f, " #no_aoc" );
    }

    if i.then_keyword_used
    {
        print( f, " then" );
    }

    force_braces: bool;
    remove_braces: bool;
    if f.single_statement_brace_mode ==
    {
    case .FORCE_ADD;
        force_braces = !i.then_keyword_used && i.if_kind == .IF;
    case .FORCE_REMOVE;
        remove_braces = i.if_kind == .IF;
    }

    if force_braces then assert( remove_braces == false );
    if remove_braces then assert( force_braces == false );

    force_new_line: bool;
    remove_new_line: bool;
    if f.single_statement_line_mode ==
    {
    case .NEW_LINE;
        force_new_line = !i.then_keyword_used && i.if_kind == .IF;
    case .SAME_LINE;
        remove_new_line = i.if_kind == .IF;
    }

    then_is_block := node_is( i._then, .BLOCK );
    same_line_then: bool;
    single_line_then: bool;

    force_then_new_line: bool;
    remove_then_new_line: bool;

    if i._then
    {
        to_print := i._then;

        block: Block;
        if force_braces && !then_is_block
        {
            block = make_block_from_node( i._then );
            to_print = *block;

            if i.location.l0 != i._then.location.l0
            {
                block.location.l0 = i.location.l0;
                block.location.c0 = i.condition.location.c1 + 1;
            }
        }
        else if remove_braces && then_is_block
        {
            b := i._then.( *Block );
            if b.members.count == 1
            {
                to_print = b.members[ 0 ];
            }
        }

        then_is_block = node_is( to_print, .BLOCK );
        same_line_then = i.location.l0 == to_print.location.l0;
        single_line_then = to_print.location.l0 == to_print.location.l1;

        // NOTE: Only force or remove new lines when then is not a block
        force_then_new_line = force_new_line && !then_is_block && single_line_then && same_line_then;
        remove_then_new_line = remove_new_line && !then_is_block && single_line_then && !same_line_then;

        f.new_scope_started = true;
        if !then_is_block then f.indent_level += 1;
        add_space := !then_is_block && same_line_then && !force_then_new_line;
        maybe_print_space( f, add_space );
        if f.single_statement_double_space && add_space then space( f );

        if force_then_new_line
        {
            maybe_print_new_line( f, true, true );

            f.previous_line = f.current_line;
            f.current_line = to_print.location.l0;
        }

        if remove_then_new_line
        {
            space( f );
            f.previous_line = f.current_line;
            f.current_line = to_print.location.l0;
        }

        print_node( f, to_print, !then_is_block && i.if_kind == .IFX );
        if !then_is_block then f.indent_level -= 1;
    }

    if i._else
    {
        f.new_scope_started = true;
        single_line_if := i.location.l0 == i.location.l1;
        print_space := ( then_is_block && !f.else_on_new_line ) || i.if_kind == .IFX || single_line_if;
        maybe_print_space( f, print_space );

        else_is_block := node_is( i._else, .BLOCK );
        to_print := i._else;

        block: Block;
        if force_braces && !else_is_block
        {
            block = make_block_from_node( i._else );
            to_print = *block;

            if i.location.l0 != i._else.location.l0
            {
                block.location.l0 = i.else_location.l0;
                block.location.c0 = i.else_location.c1 + 1;
            }
        }
        else if remove_braces && else_is_block
        {
            b := i._else.( *Block );
            if b.members.count == 1
            {
                to_print = b.members[ 0 ];
            }
        }

        same_line_else := i.else_location.l0 == to_print.location.l0;
        single_line_else := to_print.location.l0 == to_print.location.l1;
        else_is_block = node_is( to_print, .BLOCK );

        else_already_on_new_line := i.else_location.l0 > i.location.l0;

        // NOTE: Only force or remove new lines when else is not a block
        force_else_new_line := force_new_line && !else_is_block && single_line_else && same_line_else;
        remove_else_new_line := remove_new_line && !else_is_block && single_line_else && !same_line_else;

        on_new_line: bool;
        if else_already_on_new_line
        {
            on_new_line = true;
            if then_is_block && !single_line_then && !f.else_on_new_line
            {
                on_new_line = false;
            }
        }
        else
        {
            if then_is_block && !single_line_then && f.else_on_new_line
            {
                on_new_line = true;
            }
            else if force_then_new_line
            {
                on_new_line = true;
            }
        }

        maybe_print_new_line( f, on_new_line, true );
        print( f, "else" );

        if on_new_line
        {
            f.previous_line = f.current_line;
            f.current_line = i.else_location.l0;
        }

        if !else_is_block && !node_is( i._else, .IF ) then f.indent_level += 1;
        add_space := !else_is_block && same_line_else && !force_else_new_line;
        maybe_print_space( f, add_space );
        if f.single_statement_double_space && add_space then space( f );

        if force_else_new_line
        {
            maybe_print_new_line( f, true, true );

            f.previous_line = f.current_line;
            f.current_line = to_print.location.l0;
        }

        if remove_else_new_line
        {
            space( f );
            f.previous_line = f.current_line;
            f.current_line = to_print.location.l0;
        }

        print_node( f, to_print, !else_is_block && i.if_kind == .IFX );
        if !else_is_block && !node_is( i._else, .IF ) then f.indent_level -= 1;
    }
}

print_case :: ( f: *Jai_Formatter, c: *Case )
{
    if !f.indent_case
    {
        f.indent_level -= 1;
        remove_indent( f, 1 );
    }

    print( f, "case" );
    maybe_print_space( f, c.expression != null );
    print_node( f, c.expression, true );
    semicolon( f );

    is_empty := c.members.count == 0;
    all_on_same_line: bool = true;
    if !is_empty
    {
        f.new_scope_started = true;
        first_location := c.members[ 0 ].location;
        for c.members
        {
            all_on_same_line &= it.location.l0 == first_location.l0;
        }
    }
    maybe_print_space( f, all_on_same_line );

    if !is_empty
    {
        first_member_on_same_line := c.members[ 0 ].location.l0 == c.location.l0;
        f.indent_level += 1;
        maybe_print_new_line( f, !all_on_same_line && first_member_on_same_line, should_indent = true );
        for c.members
        {
            print_node( f, it );
            maybe_print_space( f, all_on_same_line && it_index != c.members.count - 1 );
        }
        f.indent_level -= 1;
    }

    if !f.indent_case
    {
        f.indent_level += 1;
    }
}

print_for :: ( f: *Jai_Formatter, _for: *For )
{
    print( f, "for" );
    space( f );
    push_alignment( f, f.expression_alignment_mode );
    if _for.is_v2
    {
        print( f, "#v2" );
        space( f );
    }

    if _for.expansion
    {
        print( f, ":%", _for.expansion.( *Identifier ).name );
        space( f );
    }

    if _for.reversed_condition
    {
        print( f, "<=" );
        space( f );
        print_node( f, _for.reversed_condition, true );
        has_pointer := _for.by_pointer_condition || _for.by_pointer;
        if has_pointer then print( f, "," );
        space( f );
    }

    if _for.by_pointer_condition
    {
        print( f, "*=" );
        space( f );
        print_node( f, _for.by_pointer_condition, true );
        space( f );
    }

    if _for.reversed
    {
        print( f, "<" );
    }

    if _for.by_pointer
    {
        print( f, "*" );
    }

    if _for.value
    {
        print_node( f, _for.value, true );
    }

    if _for.index
    {
        print( f, "," );
        space( f );
        print_node( f, _for.index, true );
    }

    if _for.value
    {
        print( f, ":" );
        space( f );
    }

    force_braces := f.single_statement_brace_mode == .FORCE_ADD;
    remove_braces := f.single_statement_brace_mode == .FORCE_REMOVE;

    body_is_block := node_is( _for.body, .BLOCK );

    if _for.iterator
    {
        print_node( f, _for.iterator, true );
        add_space := ( !force_braces && !body_is_block ) || ( remove_braces && body_is_block );
        if f.single_statement_double_space && add_space then space( f );
        maybe_print_space( f, add_space );
    }

    if _for.no_abc
    {
        print( f, " #no_abc" );
    }

    if _for.no_aoc
    {
        print( f, " #no_aoc" );
    }

    pop_alignment( f );

    if _for.body
    {
        to_print := _for.body;
        block: Block;
        if force_braces && !body_is_block
        {
            body := _for.body;
            block = make_block_from_node( body );
            to_print = *block;

            if body.location.l0 > _for.location.l0
            {
                block.location.l0 = _for.location.l0;
                block.location.c0 = _for.iterator.location.c1 + 1;
            }
        }
        else if remove_braces && body_is_block
        {
            b := _for.body.( *Block );
            if b.members.count == 1
            {
                to_print = b.members[ 0 ];
            }
        }

        body_is_block = node_is( to_print, .BLOCK );
        same_line_body := to_print.location.l0 == _for.location.l0;
        single_line_body := to_print.location.l0 == to_print.location.l1;

        force_new_line: bool;
        remove_new_line: bool;
        if f.single_statement_line_mode ==
        {
        case .NEW_LINE;
            force_new_line = !body_is_block && single_line_body && same_line_body;
        case .SAME_LINE;
            remove_new_line = !body_is_block && single_line_body && !same_line_body;
        }

        if !body_is_block then f.indent_level += 1;

        if force_new_line
        {
            maybe_print_new_line( f, true, true );

            f.previous_line = f.current_line;
            f.current_line = to_print.location.l0;
        }

        if remove_new_line
        {
            f.previous_line = f.current_line;
            f.current_line = to_print.location.l0;
        }

        f.new_scope_started = true;
        print_node( f, to_print );
        if !body_is_block then f.indent_level -= 1;
    }
}

print_while :: ( f: *Jai_Formatter, w: *While )
{
    print( f, "while" );
    space( f );
    push_alignment( f, f.expression_alignment_mode );
    print_node( f, w.expression, true );

    force_braces := f.single_statement_brace_mode == .FORCE_ADD;
    remove_braces := f.single_statement_brace_mode == .FORCE_REMOVE;

    body_is_block := node_is( w.body, .BLOCK );

    add_space := ( !force_braces && !body_is_block ) || ( remove_braces && body_is_block );
    maybe_print_space( f, add_space );
    if f.single_statement_double_space && add_space then space( f );
    pop_alignment( f );
    if w.no_abc then print( f, " #no_abc" );

    to_print := w.body;
    block: Block;
    if force_braces && !body_is_block
    {
        body := w.body;
        block = make_block_from_node( body );
        to_print = *block;

        if body.location.l0 > w.location.l0
        {
            block.location.l0 = w.location.l0;
            block.location.c0 = w.expression.location.c1 + 1;
        }
    }
    else if remove_braces && body_is_block
    {
        b := w.body.( *Block );
        if b.members.count == 1
        {
            to_print = b.members[ 0 ];
        }
    }

    body_is_block = node_is( to_print, .BLOCK );
    same_line_body := to_print.location.l0 == w.location.l0;
    single_line_body := to_print.location.l0 == to_print.location.l1;

    force_new_line: bool;
    remove_new_line: bool;
    if f.single_statement_line_mode ==
    {
    case .NEW_LINE;
        force_new_line = !body_is_block && single_line_body && same_line_body;
    case .SAME_LINE;
        remove_new_line = !body_is_block && single_line_body && !same_line_body;
    }

    if !body_is_block then f.indent_level += 1;

    if force_new_line
    {
        maybe_print_new_line( f, true, true );

        f.previous_line = f.current_line;
        f.current_line = to_print.location.l0;
    }

    if remove_new_line
    {
        f.previous_line = f.current_line;
        f.current_line = to_print.location.l0;
    }

    f.new_scope_started = true;
    print_node( f, to_print );
    if !body_is_block then f.indent_level -= 1;
}

print_break :: ( f: *Jai_Formatter, b: *Break, no_semicolon := false )
{
    print( f, "break" );
    if b.expression
    {
        space( f );
        print_node( f, b.expression );
    }
    if !no_semicolon then semicolon( f );
}

print_remove :: ( f: *Jai_Formatter, r: *Remove, no_semicolon := false )
{
    print( f, "remove" );
    if r.expression
    {
        space( f );
        print_node( f, r.expression );
    }
    if !no_semicolon then semicolon( f );
}

print_continue :: ( f: *Jai_Formatter, c: *Continue, no_semicolon := false )
{
    print( f, "continue" );
    if c.expression
    {
        space( f );
        print_node( f, c.expression );
    }
    if !no_semicolon then semicolon( f );
}

print_defer :: ( f: *Jai_Formatter, d: *Defer )
{
    if d.backticked then print( f, "`" );
    print( f, "defer" );
    if d.expression
    {
        space( f );
        print_node( f, d.expression );
    }
    if d.expression.kind != .BLOCK
    {
        semicolon( f );
    }
}

print_struct :: ( f: *Jai_Formatter, s: *Struct )
{
    print( f, "struct" );

    begin_arguments( f );
    if s.polymorphic_arguments
    {
        open_paren( f );
        for s.polymorphic_arguments
        {
            print_node( f, it );
            maybe_print_comma( f, s.polymorphic_arguments, it_index );
        }
        close_paren( f );
    }
    end_arguments( f );

    for s.notes
    {
        if it.location.l0 == s.location.l0
        {
            print_node( f, it );
        }
    }

    if is_set( s, .TYPE_INFO_NO_SIZE_COMPLAINT ) then print( f, " #type_info_no_size_complaint" );
    if is_set( s, .TYPE_INFO_PROCEDURES_ARE_VOID_POINTERS ) then print( f, " #type_info_procedures_are_void_pointers" );
    if is_set( s, .TYPE_INFO_NONE ) then print( f, " #type_info_none" );

    if s.modify_block
    {
        maybe_print_new_line( f, true );
        print( f, "#modify" );
        print_block( f, s.modify_block, true );
    }

    print_node( f, s.block );

    if is_set( s, .NO_PADDING ) then print( f, " #no_padding" );

    for s.notes
    {
        if it.location.l0 != s.location.l0
        {
            print_node( f, it );
        }
    }
}

print_enum :: ( f: *Jai_Formatter, e: *Enum )
{
    if e.is_enum_flags then print( f, "enum_flags" );
    else print( f, "enum" );

    for e.notes
    {
        if it.location.l0 == e.location.l0
        {
            print_node( f, it );
        }
    }

    if e.type
    {
        space( f );
        print_node( f, e.type );
    }

    if e.specified
    {
        print( f, " #specified" );
    }

    print_node( f, e.block );

    for e.notes
    {
        if it.location.l0 != e.location.l0
        {
            print_node( f, it );
        }
    }
}

print_union :: ( f: *Jai_Formatter, u: *Union )
{
    print( f, "union" );

    begin_arguments( f );
    if u.polymorphic_arguments
    {
        open_paren( f );
        for u.polymorphic_arguments
        {
            print_node( f, it );
            maybe_print_comma( f, u.polymorphic_arguments, it_index );
        }
        close_paren( f );
    }
    end_arguments( f );

    for u.notes
    {
        if it.location.l0 == u.location.l0
        {
            print_node( f, it );
        }
    }

    print_node( f, u.block );

    for u.notes
    {
        if it.location.l0 != u.location.l0
        {
            print_node( f, it );
        }
    }
}

print_cast :: ( f: *Jai_Formatter, c: *Cast )
{
    print_modifiers :: ( $add_space: bool ) #expand
    {
        if c.truncate then print( f, ",%trunc", ifx add_space then " " else "" );
        if c.no_check then print( f, ",%no_check", ifx add_space then " " else "" );
        if c.force then print( f, ",%force", ifx add_space then " " else "" );
    }

    if c.auto
    {
        print( f, "xx" );
        print_modifiers( false );
        space( f );
        print_node( f, c.expression );
    }

    if c.function_style
    {
        print( f, "cast" );
        open_paren( f );
        print_node( f, c.cast_expression );
        print( f, ", " );
        print_node( f, c.expression );
        print_modifiers( true );
        close_paren( f );
    }
    else if c.postfix
    {
        print_node( f, c.expression );
        print( f, "." );
        open_paren( f );
        print_node( f, c.cast_expression );
        print_modifiers( true );
        close_paren( f );
    }
    else if c.cast_expression
    {
        print( f, "cast" );
        print_modifiers( false );
        open_paren( f );
        print_node( f, c.cast_expression );
        close_paren( f );
        print_node( f, c.expression );
    }
}

print_using :: ( f: *Jai_Formatter, u: *Using )
{
    print( f, "using" );
    if u.filter_type ==
    {
    case .ONLY;
        print( f, ",only" );
    case .EXCEPT;
        print( f, ",except" );
    case .MAP;
        print( f, ",map" );
    }

    if u.no_parameters
    {
        print( f, ",no_parameters" );
    }

    if u.filter_expression
    {
        space( f );
        print_node( f, u.filter_expression );
    }
    else if u.filters
    {
        open_paren( f );
        begin_arguments( f );
        for u.filters
        {
            print_node( f, it );
            maybe_print_comma( f, u.filters, it_index );
        }
        end_arguments( f );
        close_paren( f );
    }

    space( f );
    print_node( f, u.expression );
}

print_quick_lambda :: ( f: *Jai_Formatter, l: *Quick_Lambda )
{
    open_paren( f );
    begin_arguments( f );
    comma_separated_node_list( f, l.arguments );
    end_arguments( f );
    close_paren( f );

    maybe_print_space( f, f.spaces_around_operators );
    print( f, "=>" );
    maybe_print_space( f, f.spaces_around_operators );

    print_node( f, l._return );
}

print_push_context :: ( f: *Jai_Formatter, c: *Push_Context )
{
    if c.backticked then print( f, "`" );
    print( f, "push_context" );
    if c.defer_pop then print( f, ",defer_pop" );
    space( f );
    print_node( f, c.pushed );
    if c.defer_pop
    {
        semicolon( f );
    }

    // NOTE: Block will be set only for push_context without defer_pop
    print_node( f, c.block );
}

print_inline_assembly :: ( f: *Jai_Formatter, a: *Inline_Assembly )
{
    print( f, "#asm" );
    if a.expression
    {
        space( f );
        print_node( f, a.expression );
    }

    print( f, a.body );
}

print_directive :: ( f: *Jai_Formatter, d: *$T, no_semicolon := false )
{
    #if T ==
    {
    case Directive_String;
        print( f, "#string" );
        if d.cr then print( f, ",cr" );
        if d.escape_percent then print( f, ",\\\%" );
        print( f, " %", d.identifier );
        // NOTE: strings can have % in them so this "%" makes sure that the actual string value is passed to print as one of the var args and not as the format string.
        print( f, "%", d.string_value );
        print( f, "%", d.identifier );
    case Directive_Import;
        print( f, "#import" );

        if d.import_kind ==
        {
        case .FILE;
            print( f, ",file" );
        case .DIR;
            print( f, ",dir" );
        case .STRING;
            print( f, ",string" );
        }

        print( f, " \"%\"", d.module );

        if d.module_parameters
        {
            open_paren( f );
            comma_separated_node_list( f, d.module_parameters );
            close_paren( f );
        }

        if d.program_parameters
        {
            if !d.module_parameters
            {
                open_paren( f, false );
                close_paren( f, false );
            }

            open_paren( f );
            comma_separated_node_list( f, d.program_parameters );
            close_paren( f );
        }

        if !parent_is( d, .DECLARATION )
        {
            semicolon( f );
        }

    case Directive_Load;
        print( f, "#load \"%\";", d.file );

    case Directive_Scope;
        if d.scope_kind ==
        {
        case .EXPORT; print( f, "#scope_export" );
        case .FILE; print( f, "#scope_file" );
        case .MODULE; print( f, "#scope_module" );
        }

        for d.members
        {
            print_node( f, it );
        }

    case Directive_Context;
        print( f, "#Context" );

    case Directive_Run;
        print( f, "#run" );
        if d.stallable then print( f, ",stallable" );
        if d.host then print( f, ",host" );

        if d.returns
        {
            print( f, " -> " );

            with_parens := f.surround_multiple_returns_with_parens || d.returns_surrounded_with_parens;
            if with_parens then open_paren( f );

            begin_arguments( f );
            for d.returns
            {
                print_node( f, it );
                maybe_print_comma( f, d.returns, it_index );
            }
            end_arguments( f );

            if with_parens then close_paren( f );
        }
        else
        {
            space( f );
        }

        print_node( f, d.expression );

        if standalone_expression( d ) && !node_is( d.expression, .BLOCK )
        {
            semicolon( f );
        }

    case Directive_Char;
        print( f, "#char " );
        print_node( f, d.string_literal );

    case Directive_As;
        print( f, "#as " );
        print_node( f, d.expression );

    case Directive_Place;
        print( f, "#place " );
        print_node( f, d.expression );
        semicolon( f );
        space( f );

    case Directive_Overlay;
        print( f, "#overlay " );
        print( f, "(" );
        maybe_print_space( f, f.spaces_inside_parens );
        print_node( f, d.field );
        maybe_print_space( f, f.spaces_inside_parens );
        print( f, ") " );
        print_node( f, d.expression );
        // semicolon( f );
        // space( f );

    case Directive_Type;
        print( f, "#type" );
        if d.isa then print( f, ",isa" );
        if d.distinct then print( f, ",distinct" );
        space( f );
        print_node( f, d.expression );

    case Directive_Code;
        print( f, "#code" );
        if d.typed then print( f, ",typed" );
        if d._null then print( f, ",null" );
        space( f );

        if f.inside_arguments && !node_is( d.expression, .BLOCK )
        {
            f.inside_code_argument = true;
            f.inside_code_argument_count += 1;
        }
        print_node( f, d.expression );
        if f.inside_arguments && !node_is( d.expression, .BLOCK )
        {
            f.inside_code_argument_count -= 1;
            f.inside_code_argument = f.inside_code_argument_count != 0;
        }

    case Directive_Add_Context;
        print( f, "#add_context " );
        print_node( f, d.expression );

    case Directive_Assert;
        print( f, "#assert " );
        print_node( f, d.condition );
        if d.message
        {
            print( f, " \"%\"", d.message );
        }
        if !no_semicolon then semicolon( f );

    case Directive_Bake_Arguments;
        print( f, "#bake_arguments " );
        print_node( f, d.expression );

    case Directive_Bake_Constants;
        print( f, "#bake_constants " );
        print_node( f, d.expression );

    case Directive_Bytes;
        print( f, "#bytes " );
        print_node( f, d.expression );
        semicolon( f );

    case Directive_Library;
        print( f, "#library" );
        if d.link_always then print( f, ",link_always" );
        if d.system then print( f, ",system" );
        if d.no_static_library then print( f, ",no_static_library" );
        if d.no_dll then print( f, ",no_dll" );
        print( f, " \"%\"", d.name );

    case Directive_No_Reset;
        print( f, "#no_reset" );
        print_node( f, d.expression );

    case Directive_Insert;
        print( f, "#insert" );

        if d.scoped
        {
            print( f, ",scope" );
            open_paren( f );
            print_node( f, d.scope );
            close_paren( f );
        }

        if d.for_expansion_break || d.for_expansion_continue || d.for_expansion_remove
        {
            open_paren( f );
            add_comma: bool;
            if d.for_expansion_break
            {
                print( f, "break" );
                print_operator( f, _Operator.ASSIGN );
                print_node( f, d.for_expansion_break, true );
                add_comma = true;
            }

            if d.for_expansion_continue
            {
                if add_comma then print( f, ", " );
                print( f, "continue" );
                print_operator( f, _Operator.ASSIGN );
                print_node( f, d.for_expansion_continue, true );
                add_comma = true;
            }

            if d.for_expansion_remove
            {
                if add_comma then print( f, ", " );
                print( f, "remove" );
                print_operator( f, _Operator.ASSIGN );
                print_node( f, d.for_expansion_remove, true );
            }
            close_paren( f );
        }

        if d.type ==
        {
        case .STRING;
            print( f, " -> string" );
        case .CODE;
            print( f, " -> Code" );
        }

        maybe_print_space( f, d.type == .UNKNOWN );
        print_node( f, d.expression );
        if d.type == .UNKNOWN && standalone_expression( d ) then semicolon( f );

    case Directive_Location;
        print( f, "#location" );
        open_paren( f, d.expression != null );
        print_node( f, d.expression );
        close_paren( f, d.expression != null );

    case Directive_Module_Parameters;
        print( f, "#module_parameters" );
        if d.module_parameters
        {
            begin_arguments( f );
            open_paren( f );
            comma_separated_node_list( f, d.module_parameters );
            close_paren( f );
            end_arguments( f );
        }

        if d.program_parameters
        {
            if !d.module_parameters
            {
                open_paren( f, false );
                close_paren( f, false );
            }
            begin_arguments( f );
            open_paren( f );
            comma_separated_node_list( f, d.program_parameters );
            close_paren( f );
            end_arguments( f );
        }

        semicolon( f );

    case Directive_Placeholder;
        print( f, "#placeholder " );
        print_node( f, d.expression );
        semicolon( f );

    case Directive_Procedure_Of_Call;
        print( f, "#procedure_of_call " );
        print_node( f, d.expression );

    case Directive_Procedure_Name;
        print( f, "#procedure_name" );
        open_paren( f, d.expression != null );
        print_node( f, d.expression );
        close_paren( f, d.expression != null );

    case Directive_Program_Export;
        print( f, "#program_export" );
        if d.exported_name
        {
            print( f, " \"%\"", d.exported_name );
        }
        space( f );
        print_node( f, d.expression );

    case Directive_This;
        print( f, "#this" );
        if d.arguments
        {
            open_paren( f );
            comma_separated_node_list( f, d.arguments );
            close_paren( f );

            if !d.parent || parent_is( d, .BLOCK ) || parent_is( d, .CASE ) || parent_is( d, .DIRECTIVE_SCOPE )
            {
                semicolon( f );
            }
        }

    case Directive_Poke_Name;
        print( f, "#poke_name % ", d.module );
        if d.operator_overload
        {
            print_node( f, d.operator_overload );
        }
        else
        {
            print( f, "%", d.name );
        }
        semicolon( f );

    case Directive_Dynamic_Specialize;
        print( f, "#dynamic_specialize " );
        print_node( f, d.expression );

    case Directive_Caller_Code;
        print( f, "#caller_code" );

    case Directive_Caller_Location;
        print( f, "#caller_location" );

    case Directive_File;
        print( f, "#file" );

    case Directive_Filepath;
        print( f, "#filepath" );

    case Directive_Compile_Time;
        print( f, "#compile_time" );

    case Directive_Discard;
        print( f, "#discard " );
        print_node( f, d.expression );

    case Directive_Line;
        print( f, "#line" );

    case Directive_Through;
        print( f, "#through;" );

    case Directive_Exists;
        print( f, "#exists" );
        open_paren( f );
        print_node( f, d.expression );
        if d.wait_for
        {
            print( f, ", " );
            print_node( f, d.wait_for );
        }
        close_paren( f );
    }
}

print_comment :: ( f: *Jai_Formatter )
{
    c := f.parser.lexer.comments[ f.current_comment_index ];
    f.current_comment_index += 1;

    end_line: int;
    format: string;
    if c.multiline
    {
        format = "/*%*/";
        end_line = c.l1;
    }
    else
    {
        if !starts_with( c.string_value, " " ) && f.insert_space_in_single_line_comments
        {
            format = "// %";
        }
        else
        {
            format = "//%";
        }
        end_line = c.l0;
    }

    node: Node;
    node.kind = .COMMENT;
    node.location.l0 = c.l0;
    node.location.l1 = end_line;
    insert_new_lines( f, *node );
    after_statement := ( f.previous_print_type == .STRING || f.previous_print_type == .SEMICOLON ) && f.current_line == c.l0;
    if f.indent_mode == .SPACES && f.keep_whitespace_before_single_line_comments &&
       !c.multiline && after_statement
    {
        space_diff := c.c0 - f.current_max_source_collumn;
        // NOTE: Hack because procedure calls don't include the semicolon in their location
        if node_is( f.last_node, .PROCEDURE_CALL ) && node_is( f.last_node.( *Procedure_Call ).procedure, .IDENTIFIER )
        {
            space_diff -= 1;
        }

        for 0..space_diff - 1
        {
            space( f );
        }
    }
    else
    {
        add_space := !c.multiline && f.current_collumn > 0 && after_statement;
        maybe_print_space( f, add_space );
    }
    print( f, format, c.string_value );
}

next_comment :: ( f: *Jai_Formatter, node: *Node, at_end_of_block := false ) -> bool
{
    if f.current_comment_index < f.parser.lexer.comments.count
    {
        c := f.parser.lexer.comments[ f.current_comment_index ];
        if at_end_of_block
        {
            if ( c.l0 == node.location.l0 && c.c0 > node.location.c0 ) ||
               ( c.l0 > node.location.l0 && c.l1 < node.location.l1 ) ||
               ( c.l1 == node.location.l1 && c.c1 < node.location.c1 )
            {
                return true;
            }
        }

        if ( c.l0 == node.location.l0 && c.c0 < node.location.c0 ) || c.l0 < node.location.l0
        {
            return true;
        }
    }
    return false;
}

print_comments :: ( f: *Jai_Formatter, node: *Node, at_end_of_block := false, remove_line := false ) -> bool
{
    line_removed: bool;
    comments_printed: bool;
    while next_comment( f, node, at_end_of_block )
    {
        if remove_line && !line_removed
        {
            // NOTE: Workaround for empty blocks that have comments.
            remove_new_line( f );
            line_removed = true;
        }

        print_comment( f );
        comments_printed = true;
    }
    return comments_printed;
}

print_operator :: ( f: *Jai_Formatter, op: $T )
#modify { return T == _Operator || T == Unary_Operation.Operation; }
{
    print_space: bool;
    #if T == _Operator
    {
        print_space = f.spaces_around_operators && op != .DOT && op != .RANGE;
    }
    else
    {
        print_space = false;
    }
    maybe_print_space( f, print_space && f.previous_print_type != .NEW_LINE && f.previous_print_type != .INDENT );
    // NOTE: "%" is used here for the same reason as in here strings. % operator was treated as a format string.
    print( f, "%", get_operator_string( op ) );
    maybe_print_space( f, print_space );
}

// ============== Helper fucntions ============== 
#scope_file

standalone_expression :: ( e: *Node ) -> bool
{
    return parent_is( e, .BLOCK ) ||
           parent_is( e, .CASE ) ||
           parent_is( e, .IF ) ||
           parent_is( e, .FOR ) ||
           parent_is( e, .WHILE ) ||
           parent_is( e, .USING ) ||
           e.parent == null;
}

insert_new_lines :: ( f: *Jai_Formatter, node: *Node ) -> int
{
    lines_added := 0;
    node_line := node.location.l0;
    node_end_line := node.location.l1;
    if node_line > f.current_line
    {
        if f.current_line >= 0
        {
            line_diff := node_line - f.current_line;
            newlines_to_insert := min( line_diff, f.max_empty_lines_to_keep + 1 );

            standalone_block := node_is( node, .BLOCK ) && parent_is( node, .BLOCK );
            // NOTE: Notes and blocks handle new lines on their own
            if node.kind != .NOTE && ( node.kind != .BLOCK || standalone_block )
            {
                for 1..newlines_to_insert
                {
                    lines_added += 1;
                    maybe_print_new_line( f, true );
                    f.current_collumn = 0;
                }
            }
        }

        f.previous_line = f.current_line;
        f.current_line = ifx node.kind == .COMMENT then node_end_line else node_line;
    }

    if lines_added > 0
    {
        // NOTE: If a new scope is started it is the only place we want to ignore max_empty_lines_to_keep. The beginning of the scope shouldn't have any empty lines.
        if f.new_scope_started
        {
            for 1..lines_added - 1
            {
                remove_new_line( f );
            }
        }
        // NOTE: Only indent after the last empty line.
        indent( f );
    }

    f.new_scope_started = false;

    return lines_added;
}

get_operator_string :: ( op: $T ) -> string
#modify { return T == _Operator || T == Unary_Operation.Operation; }
{
    result: string;

    #if T == Unary_Operation.Operation
    {
        if op ==
        {
        case .INVALID;
        case .PLUS;
            result = "+";
        case .MINUS;
            result = "-";
        case .NEGATE;
            result = "!";
        case .DOT;
            result = ".";
        case .POINTER;
            result = "*";
        case .POINTER_DEREFERENCE;
            result = ".*";
        case .ELLIPSIS;
            result = "..";
        case .BITWISE_NOT;
            result = "~";
        }
    }
    else
    {
        if op ==
        {
        case .INVALID;
        case .DOT;
            result = ".";
        case .RANGE;
            result = "..";
        case .ADDITION;
            result = "+";
        case .SUBTRACTION;
            result = "-";
        case .MULTIPLICATION;
            result = "*";
        case .DIVISION;
            result = "/";
        case .MODULO;
            result = "%";
        case .LESS;
            result = "<";
        case .GREATER;
            result = ">";
        case .ASSIGN;
            result = "=";
        case .BITWISE_AND;
            result = "&";
        case .PIPE;
            result = "|";
        case .BITWISE_NOT;
            result = "~";
        case .BITWISE_XOR;
            result = "^";
        case .NEGATE;
            result = "!";
        case .BITWISE_AND_ASSIGNMENT;
            result = "&=";
        case .BITWISE_XOR_ASSIGNMENT;
            result = "^=";
        case .PIPE_EQUAL;
            result = "|=";
        case .GREATER_EQUAL;
            result = ">=";
        case .LESS_EQUAL;
            result = "<=";
        case .PLUS_EQUAL;
            result = "+=";
        case .MINUS_EQUAL;
            result = "-=";
        case .MOD_EQUAL;
            result = "%=";
        case .DIV_EQUAL;
            result = "/=";
        case .TIMES_EQUAL;
            result = "*=";
        case .LOGICAL_AND;
            result = "&&";
        case .LOGICAL_AND_ASSIGNMENT;
            result = "&&=";
        case .LOGICAL_OR;
            result = "||";
        case .LOGICAL_OR_ASSIGNMENT;
            result = "||=";
        case .IS_EQUAL;
            result = "==";
        case .IS_NOT_EQUAL;
            result = "!=";
        case .LEFT_SHIFT;
            result = "<<";
        case .RIGHT_SHIFT;
            result = ">>";
        case .LEFT_SHIFT_ASSIGNMENT;
            result = "<<=";
        case .RIGHT_SHIFT_ASSIGNMENT;
            result = ">>=";
        case .UNSIGNED_RIGHT_SHIFT;
            result = ">>>";
        case .UNSIGNED_LEFT_SHIFT;
            result = "<<<";
        case .UNSIGNED_RIGHT_SHIFT_ASSIGNMENT;
            result = ">>>=";
        case .UNSIGNED_LEFT_SHIFT_ASSIGNMENT;
            result = "<<<=";
        case .ARRAY_SUBSCRIPT;
            result = "[]";
        case .ARRAY_SUBSCRIPT_ADDRESS;
            result = "*[]";
        case .ARRAY_SUBSCRIPT_ASSIGNMENT;
            result = "[]=";
        }
    }
    return result;
}

is_operator_assignment :: ( op: _Operator ) -> bool
{
    if op ==
    {
    case .ASSIGN; return true;
    case .PIPE_EQUAL; return true;
    case .PLUS_EQUAL; return true;
    case .MINUS_EQUAL; return true;
    case .MOD_EQUAL; return true;
    case .DIV_EQUAL; return true;
    case .TIMES_EQUAL; return true;
    case .BITWISE_AND_ASSIGNMENT; return true;
    case .LOGICAL_AND_ASSIGNMENT; return true;
    case .BITWISE_XOR_ASSIGNMENT; return true;
    case .LOGICAL_OR_ASSIGNMENT; return true;
    case .LEFT_SHIFT_ASSIGNMENT; return true;
    case .RIGHT_SHIFT_ASSIGNMENT; return true;
    case .UNSIGNED_RIGHT_SHIFT_ASSIGNMENT; return true;
    case .UNSIGNED_LEFT_SHIFT_ASSIGNMENT; return true;
    }

    return false;
}

begin_arguments :: ( f: *Jai_Formatter )
{
    f.inside_arguments_count += 1;
    f.inside_arguments = true;
}

end_arguments :: ( f: *Jai_Formatter )
{
    f.inside_arguments_count -= 1;
    f.inside_arguments = f.inside_arguments_count != 0;
}

space :: ( f: *Jai_Formatter )
{
    print( f, " " );
    f.previous_print_type = .SPACE;
}

tab :: ( f: *Jai_Formatter )
{
    print( f, "\t" );
    f.previous_print_type = .TAB;
}

semicolon :: ( f: *Jai_Formatter )
{
    // NOTE: We don't want to add semicolons if we're currently printing #code that is not a block and that is passed to a function as an argument. For example test(a, #code return null);
    if !f.inside_code_argument
    {
        print( f, ";" );
        f.previous_print_type = .SEMICOLON;
    }
}

maybe_print_space :: ( f: *Jai_Formatter, should_print: bool )
{
    if should_print
    {
        space( f );
    }
}

maybe_print_new_line :: ( f: *Jai_Formatter, should_print: bool, should_indent := false )
{
    if should_print
    {
        if f.previous_print_type == .SPACE
        {
            remove_spaces( f, 1 );
        }
        #if OS == .WINDOWS
        {
            if !f.no_carriage_return_on_windows
            {
                print( f, "\r" );
            }
        }
        print( f, "\n" );
        f.current_collumn = 0;
        f.previous_print_type = .NEW_LINE;
        if should_indent
        {
            indent( f );
        }
    }
}

maybe_print_comma :: ( f: *Jai_Formatter, values: []$T, index: int )
{
    if index != values.count - 1
    {
        print( f, "," );
        space( f );
    }
}

open_paren :: ( f: *Jai_Formatter, extra_condition := true )
{
    print( f, "(" );
    maybe_print_space( f, f.spaces_inside_parens && extra_condition );
    push_alignment( f, f.parens_alignment_mode );
}

close_paren :: ( f: *Jai_Formatter, extra_condition := true )
{
    pop_alignment( f );
    maybe_print_space( f, f.spaces_inside_parens && extra_condition );
    print( f, ")" );
}

space_separated_node_list :: ( f: *Jai_Formatter, list: []*Node )
{
    for list
    {
        print_node( f, it );
        maybe_print_space( f, it_index != list.count - 1 );
    }
}

comma_separated_node_list :: ( f: *Jai_Formatter, list: []*Node )
{
    for list
    {
        print_node( f, it );
        maybe_print_comma( f, list, it_index );
    }
}

is_set :: ( p: *Procedure, flag: Procedure.Flags ) -> bool
{
    return p.flags & flag > 0;
}

is_set :: ( p: *Struct, flag: Struct.Flags ) -> bool
{
    return p.flags & flag > 0;
}

print :: ( f: *Jai_Formatter, format: string, args: ..Any )
{
    to_print := tprint( format, ..args );
    if f.buffer.count + to_print.count > f.max_buffer_size
    {
        new_size := 2 * f.max_buffer_size;
        f.buffer.data = realloc( f.buffer.data, new_size, f.max_buffer_size );
        f.max_buffer_size = new_size;
    }

    memcpy( f.buffer.data + f.buffer.count, to_print.data, to_print.count );
    f.buffer.count += to_print.count;

    f.current_collumn += to_print.count;
    f.previous_print_type = .STRING;
}

push_alignment :: ( f: *Jai_Formatter, mode: Alignment_Mode = .NOT_SET )
{
    m := mode;
    if m == .NOT_SET then m = f.alignment_mode;

    amount: int;
    if m ==
    {
    case .DISABLED;
        return;
    case .INDENT_ONLY;
        amount = f.indent_width;
    case .EXACT;
        amount = f.current_collumn - f.indent_level * f.indent_string.count - f.current_alignment;
    }

    assert( amount >= 0 );
    array_add( *f.alignments, amount );
    f.current_alignment += amount;
}

pop_alignment :: ( f: *Jai_Formatter )
{
    if f.alignments.count > 0
    {
        last_alignment := pop( *f.alignments );
        f.current_alignment -= last_alignment;
        assert( f.current_alignment >= 0 );
    }
    // NOTE: This error message isn't really usefull because after calling clear_alignment any pop_alignment call will be mismatched
    // else
    // {
    //     log_error("Mismatched pop_alignment");
    // }
}

clear_alignment :: ( f: *Jai_Formatter )
{
    array_reset_keeping_memory( *f.alignments );
    f.current_alignment = 0;
}

indent :: ( f: *Jai_Formatter )
{
    for 0..f.indent_level - 1
    {
        print( f, f.indent_string );
    }

    if f.indent_mode == .TABS
    {
        tabs_count := f.current_alignment / f.tab_width;
        space_count := f.current_alignment % f.tab_width;
        assert( tabs_count * f.tab_width + space_count == f.current_alignment );

        for 0..tabs_count - 1
        {
            tab( f );
        }

        for 0..space_count - 1
        {
            space( f );
        }
    }
    else
    {
        for 0..f.current_alignment - 1
        {
            space( f );
        }
    }

    f.previous_print_type = .INDENT;
}

remove_characters :: ( f: *Jai_Formatter, count: int )
{
    assert( f.buffer.count >= count );
    f.buffer.count -= count;
}

remove_new_line :: ( f: *Jai_Formatter )
{
    chars_to_remove := 1;
    #if OS == .WINDOWS
    {
        if !f.no_carriage_return_on_windows
        {
            // NOTE: Include the \r
            chars_to_remove = 2;
        }
    }
    remove_characters( f, chars_to_remove );
}

remove_indent :: ( f: *Jai_Formatter, count: int )
{
    to_remove := count * f.indent_width;
    // NOTE: There should always be space in the current line when we remove spaces.
    assert( to_remove <= f.current_collumn );
    remove_characters( f, to_remove );
}

remove_spaces :: ( f: *Jai_Formatter, count: int )
{
    // NOTE: There should always be space in the current line when we remove spaces.
    assert( count <= f.current_collumn );
    remove_characters( f, count );
}

parent_is :: ( node: *Node, kind: Node.Kind ) -> bool
{
    return node && node.parent && node.parent.kind == kind;
}

node_is :: ( node: *Node, kind: Node.Kind ) -> bool
{
    return node && node.kind == kind;
}

get_indent_string :: ( config: Formatter_Config ) -> string
{
    indent_builder: String_Builder;
    indent_char := ifx config.indent_mode == .SPACES then " " else "\t";
    for 0..config.indent_width - 1
    {
        print( *indent_builder, indent_char );
    }
    return builder_to_string( *indent_builder );
}

make_block_from_node :: ( node: *Node ) -> Block
{
    assert( node != null );
    result: Block;
    result.node = node.*;
    result.kind = .BLOCK;
    result.members = NewArray( 1, *Node );
    result.members[ 0 ] = node;
    return result;
}

Stack :: struct( type: Type )
{
    Stack_Node :: struct
    {
        value: type;
        next: *Stack_Node;
        prev: *Stack_Node;
    }
    top: *Stack_Node;
    count: int;
    auto_pop := false;

    nodes: [ .. ]Stack_Node;
}

top :: inline ( stack: *Stack ) -> stack.type
{
    return stack.top.value;
}

top_pointer :: inline ( stack: *Stack ) -> *stack.type
{
    return *stack.top.value;
}

push :: ( stack: *Stack, value: stack.type ) -> *stack.type
{
    new_node := array_add( *stack.nodes );
    new_node.next = null;
    new_node.prev = stack.top;
    new_node.value = value;
    stack.top = new_node;

    stack.count += 1;
    return *new_node.value;
}

pop :: ( stack: *Stack ) -> stack.type
{
    result: stack.type;
    if stack.top
    {
        top := pop( *stack.nodes );
        stack.top = top.prev;
        result = top.value;

        stack.count -= 1;
    }
    return result;
}

get_allocator :: inline ( pool: *Flat_Pool ) -> Allocator
{
    return .{ flat_pool_allocator_proc, pool };
}
