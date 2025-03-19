#import "Basic";
#import "File";
#import "String";
#import "Hash_Table";
#import "Reflection";
#import "Text_File_Handler";

#import "jai_parser";

Node_Visit_Data :: struct {}
node_visit :: ( node: *Node, user_data: Node_Visit_Data ) {}

Formatter_Config :: struct
{
    spaces_inside_parens := false;
    spaces_inside_brackets := false;
    spaces_inside_literals := false;
    spaces_around_operators := true;
    braces_on_new_line := false;
    quick_lambda_brace_on_new_line := false;
    else_on_new_line := false;
    indent_case := false;
    surround_multiple_returns_with_parens := false;
    insert_space_in_single_line_comments := true;
    max_empty_lines_to_keep := 1;
    indent_width := 4;
    // TODO: Add option to force braces for single line ifs, fors and whiles
    // TODO: Add alignment options: disabled, indent_only, exact (exact is the only one currently supported)
}

Jai_Formatter :: struct(Parser_Visit_Type: Type = Node_Visit_Data) 
{
    indent_level: int;
    indent_string: string;
    current_line: int = -1;
    previous_line: int;
    
    current_collumn: int;
    current_alignment: int;
    alignments: [..]int;
    previous_print_type: enum {STRING; NEW_LINE; INDENT; SPACE;};
    new_scope_started: bool;

    inside_arguments: bool;
    inside_arguments_count: int;

    current_comment_index: int;
    
    parser: *Parser( Parser_Visit_Type );
    buffer: []u8;
    max_buffer_size: int;

    using config: Formatter_Config;
} 

init_formatter :: (f: *Jai_Formatter($T), config: Formatter_Config, parser: *Parser(T) = null)
{
    f.config = config;
    f.indent_string = get_indent_string(config);

    // NOTE: Start with 1MB
    f.max_buffer_size = 1024 * 1024;
    f.buffer = NewArray(f.max_buffer_size, u8);
    f.buffer.count = 0;

    f.parser = parser;
}

format_file :: (config: Formatter_Config, file: string) -> bool, string
{
    if !ends_with(file, ".jai") then return true, "";

    log("Reading file '%'.", file, flags = .VERBOSE_ONLY);
    source_code, ok := read_entire_file( file );
    if !ok
    {
        log_error("Failed to read file: %.", file);
        return false, "";
    }
    log("Reading file '%' done.", file, flags = .VERBOSE_ONLY);

    ok=, output := format_from_string(config, source_code, file);
    return ok, output;
}

format_from_string :: (config: Formatter_Config, source_code: string, file := "") -> bool, string
{

    f: Jai_Formatter;
    init_formatter(*f, config);

    log("Lexing file '%'.", file, flags = .VERBOSE_ONLY);
    // TODO: Catch lexing/parsing errors and don't format if there are any.
    lexer := create_lexer( source_code, file);
    log("Lexing file '%' done.", file, flags = .VERBOSE_ONLY);

    if lexer.tokens.count == 0
    {
        log_error("Failed to parse file '%'. Looks like it's empty.", file);
        return false, "";
    }

    parser: Parser( Node_Visit_Data );
    parser.node_visit = node_visit;
    parser.lexer = *lexer;
    
    f.parser = *parser;
    
    log("Parsing file '%'.", file, flags = .VERBOSE_ONLY);
    nodes: [ .. ] * Node;
    while !end( parser.lexer )
    {
        node := parse( *parser, null );
        if node
        {
            array_add( *nodes, node );
        }
    }
    log("Parsing file '%' done.", file, flags = .VERBOSE_ONLY);

    if nodes.count == 0
    {
        log_error("Failed to parse file '%'. Parser returned 0 nodes.", file);
        return false, "";
    }
    

    ok, result := format_from_nodes(*f, nodes, file);
    return ok, result;
}

format_from_nodes :: (f: *Jai_Formatter, nodes: []*Node, file := "") -> bool, string
{
    log("Formatting file '%'.", file, flags = .VERBOSE_ONLY);
    for nodes
    {
        print_node( f, xx it);
    }

    for f.current_comment_index..f.parser.lexer.comments.count - 1
    {
        // NOTE: Print any leftover comments
        print_comment(f);
    }
    
    log("Formatting file '%' done.", file, flags = .VERBOSE_ONLY);
    result: string = xx f.buffer;
    return true, result;
}

load_config :: (file: string) -> Formatter_Config
{
    result: Formatter_Config;

    handler: Text_File_Handler;
    handler.do_version_number = false;

    log("Loading config file: '%'.", file, flags = .VERBOSE_ONLY);
    start_file(*handler, "config", file);
    if handler.failed
    {
        log_error("Failed to load config '%'. Using default configuration.", file);
        return result;
    }

    unique_keys: Table(string, bool);
    while true
    {
        line, found := consume_next_line(*handler);
        if !found then break;

        key, value := break_by_spaces(line);
        if !value
        {
            log_error("Missing value for option: '%'.", key);
            continue;
        }

        if table_contains(*unique_keys, key)
        {
            log_error("Ignoring duplicated option: '%' at line %.", key, handler.line_number);
            continue;
        }

        table_add(*unique_keys, key, true);

        field := get_field( type_info( Formatter_Config ), key);
        if field
        {
            any: Any;
            any.type = field.type;
            any.value_pointer = ( *result ).(*u8) + field.offset_in_bytes;
            ok := set_value_from_string( any, value );
            if !ok
            {
                log_error("Failed to set option '%'. Value was: '%'.", key, value);
            }
        }
        else 
        {
            log_error( "Invalid configuration option '%' at line %", key, handler.line_number);
        }
    }

    result.max_empty_lines_to_keep = max(0, result.max_empty_lines_to_keep);
    result.indent_width = max(0, result.indent_width);

    log("Loading config file: '%' done.", file, flags = .VERBOSE_ONLY);
    return result;
}

// ============== Printing fucntions ============== 

print_node :: ( f: *Jai_Formatter, node: *Node, no_semicolon := false )
{
    if !node then return;

    print_comments(f, node);
    
    insert_new_lines(f, node);

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
    case .DECLARATION; print_declaration( f, xx node );
    case .COMPOUND_DECLARATION; print_compound_declaration(f, xx node);
    case .COMPOUND_DECLARATION_ITEM; print_compound_declaration_item(f, xx node);
    case .COMMA_SEPARATED_EXPRESSION; print_comma_separated_expression( f, xx node );
    case .NOTE; print_note( f, xx node );

    case .PROCEDURE; print_procedure( f, xx node );
    case .PROCEDURE_CALL; print_procedure_call( f, xx node, no_semicolon );
    case .POLYMORPHIC_CONSTANT; print_polymorphic_constant(f, xx node);
    case .RETURN_VALUE; print_return_value( f, xx node );
    case .RETURN; print_return( f, xx node );

    case .OPERATOR_OVERLOAD; print_operator_overload(f, xx node);
    case .BINARY_OPERATION; print_binary_operation( f, xx node, no_semicolon );
    case .UNARY_OPERATION; print_unary_operation( f, xx node );
    case .ARRAY_TYPE; print_array_type(f, xx node);
    case .ARRAY_SUBSCRIPT; print_array_subscript( f, xx node );
    case .LITERAL; print_literal( f, xx node );

    case .IF; print_if( f, xx node );
    case .CASE; print_case( f, xx node );
    case .FOR; print_for( f, xx node );
    case .WHILE; print_while(f, xx node);
    case .BREAK; print_break(f, xx node);
    case .CONTINUE; print_continue(f, xx node);
    case .DEFER; print_defer(f, xx node);

    case .STRUCT; print_struct(f, xx node);
    case .ENUM; print_enum(f, xx node);
    case .UNION; print_union(f, xx node);

    case .CAST; print_cast( f, xx node );
    case .USING; print_using(f, xx node);
    case .QUICK_LAMBDA; print_quick_lambda(f, xx node);
    case .PUSH_CONTEXT; print_push_context(f, xx node);
    case .INLINE_ASSEMBLY; print_inline_assembly(f, xx node);
    case .INITIALIZE_ZERO;
        print(f, "---");
    case;
        #insert ->string
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
                    print( *builder, "case .%; print_directive(f, cast(*%)node);\n", it, type_name );
                }
            }

            print( *builder, "case; print( \"Unsupported node kind: \%\\n\", node.kind );\n");
            return tprint( FORMAT, builder_to_string( *builder ) );
        }
    }
}

print_block :: ( f: *Jai_Formatter, b: *Block, is_modify := false )
{
    // TODO: Make sure that clearing the alignment is ok here. 
    clear_alignment(f);
    single_line := b.location.l0 == b.location.l1;
    on_new_line: bool;
    if parent_is(b, .QUICK_LAMBDA)
    {
        on_new_line = f.quick_lambda_brace_on_new_line;
    }
    else
    {
        if b.parent && !is_modify
        {
            // NOTE: If we're below the parent in the original code that means insert_new_lines already inserted a proper amount of new lines. 
            same_line_as_parent := f.previous_print_type == .STRING;
            // same_line_as_parent := b.location.l0 == b.parent.location.l0;
            on_new_line = f.braces_on_new_line && (( !same_line_as_parent && single_line) || (!single_line && same_line_as_parent));
        }
        else if is_modify
        {
            on_new_line = f.braces_on_new_line && !single_line;
        }
    }
    
    if b.no_aoc
    {
        print( f, "#no_aoc" );
    }
    
    maybe_print_new_line( f, on_new_line );
    space_already_added := f.previous_print_type == .SPACE;
    maybe_print_space( f, !space_already_added && (!f.braces_on_new_line || (single_line && !on_new_line) ));

    if on_new_line
    {
        indent( f );
    }
    print( f, "{" );
    f.new_scope_started = true;
    
    is_empty := b.members.count == 0;
    first_member_on_same_line := !is_empty && b.members[0].location.l0 == b.location.l0;

    if !single_line
    {
        f.indent_level += 1;
    }

    maybe_print_space( f, single_line && !is_empty && f.spaces_inside_parens );
    maybe_print_new_line( f, !single_line && (is_empty || first_member_on_same_line), should_indent = first_member_on_same_line );
    
    for b.members
    {
        print_node( f, it );
        maybe_print_space(f, single_line && it_index != b.members.count - 1);
    }

    comments_printed := print_comments(f, b, true);
    
    maybe_print_space( f, single_line && !is_empty && f.spaces_inside_parens);
    maybe_print_new_line( f, !single_line && !is_empty );
    
    if !single_line
    {
        f.indent_level -= 1;
    }
    
    if !single_line
    {
        indent( f );
    }
    print( f, "}" );
}

print_identifier :: ( f: *Jai_Formatter, i: *Identifier, no_semicolon := false )
{
    if i.backticked then print( f, "`" );
    print( f, i.name );
    if standalone_expression(i) && !no_semicolon then semicolon(f);
}

print_declaration :: ( f: *Jai_Formatter, d: *Declaration, compound_type := Compound_Declaration_Item.Item_Kind.DECLARATION )
{
    if d.backticked then print( f, "`" );
    
    print( f, d.name );

    // NOTE: Name is not set in compound declarations 
    compound := d.name.count == 0;
    
    if d.type_inst
    {
        print( f, ": " );
        print_node( f, d.type_inst );
    }
    
    if d.expression
    {
        maybe_print_space(f, f.spaces_around_operators && !(d.const && d.type_inst));
        if compound 
        {
            if d.const then print(f, ifx d.type_inst then ":" else "::");
            else print(f, ifx compound_type == .DECLARATION then ":=" else "=");
        }
        else print( f, ifx d.const then "::" else ":=" );
        maybe_print_space(f, f.spaces_around_operators);

        standalone := standalone_expression(d);
        if standalone then push_alignment(f);
        print_node( f, d.expression );
        if standalone then pop_alignment(f);
    }
    
    if d.has_elsewhere
    {
        print( f, " #elsewhere" );
        if d.elsewhere
        {
            print( f, " %", d.elsewhere );
            if d.elsewhere_alias
            {
                print(f, " \"%\"", d.elsewhere_alias);
            }
        }
    }

    if d.alignment > 0
    {
        print(f, " #align %", d.alignment);
    }
    
    is_run_with_block := node_is(d.expression, .DIRECTIVE_RUN) && node_is(d.expression.(*Directive_Run).expression, .BLOCK);
    // TODO: This is ugly. Figure out something better here
    if !node_is(d.expression, .PROCEDURE) &&
       !node_is(d.expression, .STRUCT) &&
       !node_is(d.expression, .ENUM) &&
       !node_is(d.expression, .UNION) &&
       !node_is(d.expression, .DIRECTIVE_STRING) &&
       !is_run_with_block &&
       !compound &&
       !f.inside_arguments
    {
        semicolon(f);
    }

    for d.notes
    {
        print_node(f, it);
    }
}

print_compound_declaration :: (f: *Jai_Formatter, d: *Compound_Declaration)
{

    same_type: bool = true;
    for 0..d.members.count - 2
    {
        current := cast(*Compound_Declaration_Item)d.members[it];
        next := cast(*Compound_Declaration_Item)d.members[it + 1];
        same_type &= current.item_kind == next.item_kind;
    }

    for d.members
    {
        print_compound_declaration_item(f, xx it, it_index == d.members.count - 1, same_type);
        maybe_print_comma(f, d.members, it_index);
    }

    compound_type: Compound_Declaration_Item.Item_Kind;
    if same_type
    {
        compound_type = d.members[0].(*Compound_Declaration_Item).item_kind;
    }
    else
    {
        compound_type = d.members[d.members.count - 1].(*Compound_Declaration_Item).item_kind;
    }

    if d.type_inst
    {
        print_declaration(f, d.type_inst, compound_type);
    }

    semicolon(f);

}

print_compound_declaration_item :: (f: *Jai_Formatter, i: *Compound_Declaration_Item, last := false, same_type := false)
{
    print_node(f, i.expression);
    if last || same_type then return;
    if i.item_kind ==
    {
    case .DECLARATION;
        print(f, ":");
    case .ASSIGN;
        print(f, "=");
    }
}

print_comma_separated_expression :: ( f: *Jai_Formatter, e: *Comma_Separated_Expression )
{
    if e.surrounded_with_parens then open_paren(f);
    else push_alignment(f);
    comma_separated_node_list(f, e.members);
    if e.surrounded_with_parens then close_paren(f);
    else pop_alignment(f);
}

print_note :: ( f: *Jai_Formatter, n: *Note )
{
    print( f, " @%", n.value);
}

print_procedure :: ( f: *Jai_Formatter, p: *Procedure )
{
    empty_args := p.arguments.count == 0;
    open_paren(f, !empty_args);
    
    begin_arguments(f);
    for p.arguments
    {
        print_node( f, it );
        maybe_print_comma( f, p.arguments, it_index );
    }
    end_arguments(f);
    
    close_paren(f, !empty_args);
    
    if p.returns
    {
        print( f, " -> " );
        
        with_parens := f.surround_multiple_returns_with_parens || p.returns_surrounded_with_parens;
        if with_parens then open_paren(f);
        if !with_parens then push_alignment(f, 0);
        
        begin_arguments(f);
        for p.returns
        {
            print_node( f, it );
            maybe_print_comma( f, p.returns, it_index );
        }
        end_arguments(f);
        
        if with_parens then close_paren(f);
        if !with_parens then pop_alignment(f);
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
                print(f, " \"%\"", p.elsewhere_alias);
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
        maybe_print_new_line(f, true);
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
    if (is_set( p, .INTRINSIC ) || 
        is_set(p, .FOREIGN) || 
        is_set(p, .ELSEWHERE) ) && 
        !p.body 
    {
        semicolon(f);
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
    
    if p.procedure && p.procedure.kind == .IDENTIFIER
    {
        print( f, p.procedure.( *Identifier ).name );
    }
    
    empty_args := p.arguments.count == 0 && p.context_changes.count == 0;
    open_paren(f, !empty_args);
    
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
    
    close_paren(f, !empty_args);
    
    if standalone_expression(p) && !no_semicolon
    {
        semicolon(f);
    }
}

print_polymorphic_constant :: (f: *Jai_Formatter, c: *Polymorphic_Constant)
{
    print(f, "$");
    if c.maybe_constant then print(f, "$");
    print_node(f, c.expression);
    if c.restriction
    {
        maybe_print_space(f, f.spaces_around_operators);
        print(f, "/");
        maybe_print_space(f, f.spaces_around_operators);
        if c.restrictions_interface then print(f, "interface ");
        print_node(f, c.restriction);
    }
}

print_return_value :: ( f: *Jai_Formatter, r: *Return_Value )
{
    if r.must
    {
        print( f, "#must " );
    }
    
    if r.expression
    {
        print_node( f, r.expression );
    }
}

print_return :: ( f: *Jai_Formatter, r: *Return )
{
    if r.backticked then print( f, "`" );
    print( f, "return " );
    push_alignment(f);
    comma_separated_node_list(f, r.returns);
    semicolon(f);
    pop_alignment(f);
}

print_operator_overload :: (f: *Jai_Formatter, o: *Operator_Overload)
{
    print(f, "operator % :: ", get_operator_string(o.operation));
    print_node(f, o.procedure);
}

print_binary_operation :: ( f: *Jai_Formatter, op: *Binary_Operation, no_semicolon := false )
{
    if op.left
    {
        print_node( f, op.left );
    }
    
    print_operator( f, op.operation );
    
    standalone := standalone_expression(op);
    if op.right
    {
        if standalone && !no_semicolon then push_alignment(f);
        print_node( f, op.right );
        if standalone && !no_semicolon then pop_alignment(f);
    }
    
    if !no_semicolon && standalone
    {
        semicolon(f);
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

print_array_type :: (f: *Jai_Formatter, t: *Array_Type)
{
    print(f, "[");
    is_view := !t.resizable && t.dimension == null;
    maybe_print_space(f, f.spaces_inside_brackets && !is_view);
    if t.resizable
    {
        print(f, "..");
    }
    else
    {
        print_node(f, t.dimension);
    }
    maybe_print_space(f, f.spaces_inside_brackets && !is_view);
    print(f, "]");

    print_node(f, t.element_type);
}

print_array_subscript :: ( f: *Jai_Formatter, a: *Array_Subscript )
{
    print_node( f, a.expression );
    print( f, "[" );
    maybe_print_space( f, f.spaces_inside_brackets );
    push_alignment(f);
    print_node( f, a.subscript );
    pop_alignment(f);
    maybe_print_space( f, f.spaces_inside_brackets );
    print( f, "]" );
}

print_literal :: ( f: *Jai_Formatter, l: *Literal )
{
    if #complete l.value_type == 
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

        push_alignment(f);
        for array_info.elements
        {
            print_node( f, it );
            maybe_print_comma( f, array_info.elements, it_index );
        }
        pop_alignment(f);

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
        
        push_alignment(f);
        for struct_info.body
        {
            print_node( f, it );
            maybe_print_comma( f, struct_info.body, it_index );
        }
        pop_alignment(f);
        
        maybe_print_space( f, f.spaces_inside_literals && !is_empty );
        print( f, "}" );
    }

    if parent_is(l, .BLOCK) then semicolon(f);
}

print_if :: ( f: *Jai_Formatter, i: *If )
{
    if i.compile_time
    {
        print( f, "#" );
    }
    if i.if_kind == 
    {
    case .IF;  #through;
    case .SWITCH;
        print( f, "if " );
    case .IFX;
        print( f, "ifx " );
    }

    if i.if_kind then push_alignment(f);
    
    if i.condition
    {
        print_node( f, i.condition, true );
    }

    if i.if_kind then pop_alignment(f);
    
    if i.no_aoc
    {
        print( f, " #no_aoc" );
    }

    if i.then_keyword_used
    {
        print(f, " then");
    }
    
    then_is_block := node_is(i._then, .BLOCK);
    if i._then
    {
        f.new_scope_started = true;
        if !then_is_block then f.indent_level += 1;
        maybe_print_space( f, !then_is_block );
        print_node( f, i._then );
        if !then_is_block then f.indent_level -= 1;
    }
    
    if i._else
    {
        f.new_scope_started = true;
        single_line := i.location.l0 == i.location.l1;
        print_space := ( then_is_block && !f.else_on_new_line ) || i.if_kind == .IFX || single_line;
        maybe_print_space( f, print_space);
        else_already_on_new_line := i._else.location.l0 > i.location.l0;
        else_is_block := node_is(i._else, .BLOCK);
        on_new_line := (then_is_block && f.else_on_new_line) || (else_already_on_new_line && !else_is_block);
        maybe_print_new_line( f, on_new_line );
        if on_new_line
        {
            indent( f );
        }
        print( f, "else" );

        if else_already_on_new_line
        {
            f.previous_line = f.current_line;
            f.current_line = i._else.location.l0;
        }
        maybe_print_space( f, !then_is_block );
        print_node( f, i._else );
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
    print_node( f, c.expression );
    semicolon(f);

    is_empty := c.members.count == 0; 
    all_on_same_line: bool = true;
    if !is_empty
    {
        f.new_scope_started = true;
        first_location := c.members[0].location;
        for c.members
        {
            all_on_same_line &= it.location.l0 == first_location.l0;
        }

    }
    maybe_print_space( f, all_on_same_line );
    
    if !is_empty 
    {
        first_member_on_same_line := c.members[0].location.l0 == c.location.l0;
        f.indent_level += 1;
        maybe_print_new_line(f, !all_on_same_line && first_member_on_same_line, should_indent = true );
        for c.members
        {
            print_node( f, it );
            maybe_print_space(f, all_on_same_line && it_index != c.members.count - 1);
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
    print( f, "for " );
    push_alignment(f);
    if _for.is_v2
    {
        print(f, "#v2 ");
    }

    if _for.reversed_condition
    {
        print(f, "<= ");
        print_node(f, _for.reversed_condition, true);
        has_pointer := _for.by_pointer_condition || _for.by_pointer;
        if has_pointer then print(f, ",");
        maybe_print_space(f, has_pointer);
    }

    if _for.by_pointer_condition
    {
        print(f, "*= ");
        print_node(f, _for.by_pointer_condition, true);
        space(f);
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
        print( f, ", " );
        print_node( f, _for.index, true );
    }
    
    if _for.value
    {
        print( f, ": " );
    }
    
    if _for.iterator
    {
        print_node( f, _for.iterator, true );
        maybe_print_space(f, !node_is(_for.body, .BLOCK));
    }
    
    if _for.no_abc
    {
        print( f, " #no_abc" );
    }
    
    if _for.no_aoc
    {
        print( f, " #no_aoc" );
    }

    pop_alignment(f);
    
    if _for.body
    {
        f.new_scope_started = true;
        print_node( f, _for.body );
    }
}

print_while :: (f: *Jai_Formatter, w: *While)
{
    print(f, "while ");
    push_alignment(f);
    print_node(f, w.expression, true);
    maybe_print_space(f, !node_is(w.body, .BLOCK));
    pop_alignment(f);
    if w.no_abc then print(f, " #no_abc");
    f.new_scope_started = true;
    print_node(f, w.body);
}

print_break :: (f: *Jai_Formatter, b: *Break)
{
    print(f, "break");
    if b.expression
    {
        space(f);
        print_node(f, b.expression);
    }
    semicolon(f);
}

print_continue :: (f: *Jai_Formatter, c: *Continue)
{
    print(f, "continue");
    if c.expression
    {
        space(f);
        print_node(f, c.expression);
    }
    semicolon(f);
}

print_defer :: (f: *Jai_Formatter, d: *Defer)
{
    if d.backticked then print(f, "`");
    print(f, "defer");
    if d.expression
    {
        space(f);
        print_node(f, d.expression);
    }
    if d.expression.kind != .BLOCK
    {
        semicolon(f);
    }
}

print_struct :: (f: *Jai_Formatter, s: *Struct)
{
    print(f, "struct");

    begin_arguments(f);
    if s.polymorphic_arguments
    {
        open_paren(f);
        for s.polymorphic_arguments
        {
            print_node(f, it);
            maybe_print_comma(f, s.polymorphic_arguments, it_index);
        }
        close_paren(f);
    }
    end_arguments(f);

    for s.notes
    {
        if it.location.l0 == s.location.l0
        {
            print_node(f, it);
        }
    }

    if is_set(s, .TYPE_INFO_NO_SIZE_COMPLAINT) then print(f, " #type_info_no_size_complaint");
    if is_set(s, .TYPE_INFO_PROCEDURES_ARE_VOID_POINTERS) then print(f, " #type_info_procedures_are_void_pointers");
    if is_set(s, .TYPE_INFO_NONE) then print(f, " #type_info_none");

    if s.modify_block
    {
        maybe_print_new_line(f, true);
        print( f, "#modify" );
        print_block( f, s.modify_block, true );
    }

    print_node(f, s.block);

    for s.notes
    {
        if it.location.l0 != s.location.l0
        {
            print_node(f, it);
        }
    }

}

print_enum :: (f: *Jai_Formatter, e: *Enum)
{
    if e.is_enum_flags then print(f, "enum_flags");
    else print(f, "enum");

    for e.notes
    {
        if it.location.l0 == e.location.l0
        {
            print_node(f, it);
        }
    }

    if e.type
    {
        space(f);
        print_node(f, e.type);
    }

    if e.specified
    {
        print(f, " #specified");
    }

    print_node(f, e.block);

    for e.notes
    {
        if it.location.l0 != e.location.l0
        {
            print_node(f, it);
        }
    }
}

print_union :: (f: *Jai_Formatter, u: *Union)
{
    print(f, "union");

    begin_arguments(f);
    if u.polymorphic_arguments
    {
        open_paren(f);
        for u.polymorphic_arguments
        {
            print_node(f, it);
            maybe_print_comma(f, u.polymorphic_arguments, it_index);
        }
        close_paren(f);
    }
    end_arguments(f);

    for u.notes
    {
        if it.location.l0 == u.location.l0
        {
            print_node(f, it);
        }
    }

    print_node(f, u.block);

    for u.notes
    {
        if it.location.l0 != u.location.l0
        {
            print_node(f, it);
        }
    }
}

print_cast :: ( f: *Jai_Formatter, c: *Cast )
{
    print_modifiers :: ($add_space: bool) #expand 
    {
        if c.truncate then print( f, ",%trunc", ifx add_space then " " else "" );
        if c.no_check then print( f, ",%no_check", ifx add_space then " " else "" );
        if c.force then print( f, ",%force", ifx add_space then " " else "" );
    }
    
    if c.auto
    {
        print( f, "xx" );
        print_modifiers(false);
        space(f);
        print_node( f, c.expression );
    }
    
    if c.function_style
    {
        print( f, "cast" );
        open_paren(f);
        print_node(f, c.cast_expression);
        print(f, ", ");
        print_node(f, c.expression);
        print_modifiers(true);
        close_paren(f);
    }
    else if c.postfix
    {
        print_node(f, c.expression);
        print(f, ".");
        open_paren(f);
        print_node(f, c.cast_expression);
        print_modifiers(true);
        close_paren(f);
    }
    else if c.cast_expression
    {
        print( f, "cast" );
        print_modifiers(false);
        open_paren(f);
        print_node( f, c.cast_expression );
        close_paren(f);
        print_node( f, c.expression );
    }
}

print_using :: (f: *Jai_Formatter, u: *Using)
{
    print(f, "using");
    if u.filter_type ==
    {
    case .ONLY;
        print(f, ",only");
    case .EXCEPT;
        print(f, ",except");
    case .MAP;
        print(f, ",map");
    }

    if u.no_parameters
    {
        print(f, ",no_parameters");
    }

    if u.filter_expression
    {
        space(f);
        print_node(f, u.filter_expression);
    }
    else if u.filters
    {
        open_paren(f);
        for u.filters
        {
            print_node(f, it);
            maybe_print_comma(f, u.filters, it_index);
        }
        close_paren(f);
    }

    space(f);
    print_node(f, u.expression);

    if !parent_is(u, .DIRECTIVE_AS) && !parent_is(u.parent, .STRUCT)
    {
        semicolon(f);
    }
}

print_quick_lambda :: (f: *Jai_Formatter, l: *Quick_Lambda)
{
    open_paren(f);
    begin_arguments(f);
    comma_separated_node_list(f, l.arguments);
    end_arguments(f);
    close_paren(f);

    maybe_print_space(f, f.spaces_around_operators);
    print(f, "=>");
    maybe_print_space(f, f.spaces_around_operators);

    print_node(f, l._return);
}

print_push_context :: (f: *Jai_Formatter, c: *Push_Context)
{
    if c.backticked then print(f, "`");
    print(f, "push_context");
    if c.defer_pop then print(f, ",defer_pop");
    space(f);
    print_node(f, c.pushed);
    if c.defer_pop
    {
        semicolon(f);
    }

    // NOTE: Block will be set only for push_context without defer_pop
    print_node(f, c.block);
}

print_inline_assembly :: (f: *Jai_Formatter, a: *Inline_Assembly)
{
    print(f, "#asm");
    if a.expression
    {
        space(f);
        print_node(f, a.expression);
    }

    print(f, a.body);
}

print_directive :: ( f: *Jai_Formatter, d: *$T )
{
    #if T ==
    {
    case Directive_String;
        print(f, "#string");
        if d.cr then print(f, ",cr");
        if d.escape_percent then print(f, ",\\\%");
        print(f, " %", d.identifier);
        print(f, d.string_value);
        print(f, "%", d.identifier);
    case Directive_Import;
        print(f, "#import");

        if d.import_kind ==
        {
        case .FILE;
            print(f, ",file");
        case .DIR;
            print(f, ",dir");
        case .STRING;
            print(f, ",string");
        }

        print(f, " \"%\"", d.module);
        
        if d.arguments
        {
            open_paren(f);
            for d.arguments
            {
                print_node(f, it);
                maybe_print_comma(f, d.arguments, it_index);
            }
            close_paren(f);
        }
        semicolon(f);

    case Directive_Load;
        print(f, "#load \"%\";", d.file);

    case Directive_Scope;
        if d.scope_kind ==
        {
        case .EXPORT; print(f, "#scope_export");
        case .FILE; print(f, "#scope_file");
        case .MODULE; print(f, "#scope_module");
        }

        for d.members
        {
            print_node(f, it);
        }

    case Directive_Context;
        print(f, "#Context");

    case Directive_Run;
        print(f, "#run");
        if d.stallable then print(f, ",stallable");
        if d.host then print(f, ",host");

        if d.returns
        {
            print( f, " -> " );
            
            with_parens := f.surround_multiple_returns_with_parens || d.returns_surrounded_with_parens;
            if with_parens then open_paren(f);
            
            begin_arguments(f);
            for d.returns
            {
                print_node( f, it );
                maybe_print_comma( f, d.returns, it_index );
            }
            end_arguments(f);
            
            if with_parens then close_paren(f);
        }
        else
        {
            space(f);
        }
        print_node(f, d.expression);

    case Directive_Char;
        print(f, "#char ");
        print_node(f, d.string_literal);

    case Directive_As;
        print(f, "#as ");
        print_node(f, d.expression);

    case Directive_Place;
        print(f, "#place ");
        print_node(f, d.expression);

    case Directive_Type;
        print( f, "#type" );
        if d.isa then print( f, ",isa" );
        if d.distinct then print( f, ",distinct" );
        space(f);
        print_node( f, d.expression );

    case Directive_Code;
        print(f, "#code");
        if d.typed then print(f, ",typed");
        if d._null then print(f, ",null");
        space(f);
        print_node(f, d.expression);

    case Directive_Add_Context;
        print(f, "#add_context ");
        print_node(f, d.expression);

    case Directive_Assert;
        print(f, "#assert ");
        print_node(f, d.condition);
        if d.message
        {
            print(f, " \"%\"", d.message);
        }
        semicolon(f);
        
    case Directive_Bake_Arguments;
        print(f, "#bake_arguments ");
        print_node(f, d.expression);

    case Directive_Bake_Constants;
        print(f, "#bake_constants ");
        print_node(f, d.expression);

    case Directive_Bytes;
        print(f, "#bytes ");
        print_node(f, d.expression);
        semicolon(f);

    case Directive_Library;
        print(f, "#library");
        if d.link_always then print(f, ",link_always");
        if d.system then print(f, ",system");
        if d.no_static_library then print(f, ",no_static_library");
        if d.no_dll then print(f, ",no_dll");
        print(f, " \"%\"", d.name);

    case Directive_No_Reset;
        print(f, "#no_reset");
        print_node(f, d.expression);

    case Directive_Insert;
        print(f, "#insert");

        if d.scoped
        {
            print(f, ",scope");
            open_paren(f);
            print_node(f, d.scope);
            close_paren(f);
        }

        if d.type ==
        {
        case .STRING;
            print(f, " -> string");
        case .CODE;
            print(f, " -> Code");
        }

        space(f);
        print_node(f, d.expression);
        if d.type == .UNKNOWN then semicolon(f);

    case Directive_Location;
        print(f, "#location");
        open_paren(f, d.expression != null);
        print_node(f, d.expression);
        close_paren(f, d.expression != null);

    case Directive_Module_Parameters;
        print(f, "#module_parameters");
        if d.parameters
        {
            begin_arguments(f);
            open_paren(f);
            comma_separated_node_list(f, d.parameters);
            close_paren(f);
            end_arguments(f);
        }

        if d.second_parameters
        {
            begin_arguments(f);
            open_paren(f);
            comma_separated_node_list(f, d.second_parameters);
            close_paren(f);
            end_arguments(f);
        }

        semicolon(f);

    case Directive_Placeholder;
        print(f, "#placeholder ");
        print_node(f, d.expression);

    case Directive_Procedure_Of_Call;
        print(f, "#procedure_of_call ");
        print_node(f, d.expression);

    case Directive_Procedure_Name;
        print(f, "#procedure_name");
        open_paren(f, d.expression != null);
        print_node(f, d.expression);
        close_paren(f, d.expression != null);

    case Directive_Program_Export;
        print(f, "#program_export");
        if d.exported_name
        {
            print(f, " \"%\"", d.exported_name);
        }
        space(f);
        print_node(f, d.expression);

    case Directive_This;
        print(f, "#this");
        if d.arguments
        {
            open_paren(f);
            comma_separated_node_list(f, d.arguments);
            close_paren(f);

            if !d.parent || parent_is( d, .BLOCK ) || parent_is( d, .CASE ) || parent_is(d, .DIRECTIVE_SCOPE)
            {
                semicolon(f);
            }
        }

    case Directive_Poke_Name;
        print(f, "#poke_name % %;", d.module, d.name);

    case Directive_Dynamic_Specialize;
        print(f, "#dynamic_specialize ");
        print_node(f, d.expression);

    case Directive_Caller_Code;
        print(f, "#caller_code");

    case Directive_Caller_Location;
        print(f, "#caller_location");

    case Directive_File;
        print(f, "#file");

    case Directive_Filepath;
        print(f, "#filepath");

    case Directive_Compile_Time;
        print(f, "#compile_time");

    case Directive_Discard;
        print(f, "#discard ");
        print_node(f, d.expression);

    case Directive_Line;
        print(f, "#line");

    case Directive_Through;
        print(f, "#through");

    case Directive_Exists;
        print(f, "#exists");
        open_paren(f);
        print_node(f, d.expression);
        if d.wait_for
        {
            print(f, ", ");
            print_node(f, d.wait_for);
        }
        close_paren(f);
    }
}

print_comment :: ( f: *Jai_Formatter, in_empty_block := false)
{
    c := f.parser.lexer.comments[f.current_comment_index];
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
        if !starts_with(c.string_value, " ") && f.insert_space_in_single_line_comments
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
    insert_new_lines(f, *node);
    add_space := !c.multiline && f.current_line == c.l0 && f.current_collumn > 0 && f.previous_print_type == .STRING;
    maybe_print_space(f, add_space);
    print(f, format, c.string_value);
}

next_comment :: (f: *Jai_Formatter, node: *Node, at_end_of_block := false) -> bool
{
    if f.current_comment_index < f.parser.lexer.comments.count
    {
        c := f.parser.lexer.comments[f.current_comment_index];
        if at_end_of_block 
        {
            if (c.l0 == node.location.l0 && c.c0 > node.location.c0) || 
               (c.l0 > node.location.l0 && c.l1 < node.location.l1) ||
               (c.l1 == node.location.l1 && c.c1 < node.location.c1)
            {
                return true;
            }
            
        }

        if (c.l0 == node.location.l0 && c.c0 < node.location.c0) || c.l0 < node.location.l0
        {
            return true;
        }
    }
    return false;
}

print_comments :: inline (f: *Jai_Formatter, node: *Node, at_end_of_block := false) -> bool
{
    comments_printed: bool;
    while next_comment(f, node, at_end_of_block)
    {
        print_comment(f, at_end_of_block);
        comments_printed = true;
    }
    return comments_printed;
}

print_operator :: ( f: *Jai_Formatter, op: $T )
#modify  {  return T == _Operator || T == Unary_Operation.Operation; }
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
    maybe_print_space( f, print_space );
    print( f, get_operator_string( op ) );
    maybe_print_space( f, print_space );
}

// ============== Helper fucntions ============== 
#scope_file

standalone_expression :: inline (e: *Node) -> bool
{
    return parent_is(e, .BLOCK) || parent_is(e, .CASE) || parent_is(e, .IF) || parent_is(e, .FOR) || parent_is(e, .WHILE);
}

insert_new_lines :: (f: *Jai_Formatter, node: *Node)
{
    lines_added := 0;
    node_line := node.location.l0;
    node_end_line := node.location.l1;
    if node_line > f.current_line
    {
        if f.current_line >= 0
        {
            line_diff := node_line - f.current_line;
            newlines_to_insert := min(line_diff, f.max_empty_lines_to_keep + 1);

            // NOTE: Notes and blocks (when braces_on_new_line == false) handle new lines on their own
            if node.kind != .NOTE && !(node.kind == .BLOCK && !f.braces_on_new_line)
            {
                for 1..newlines_to_insert
                {
                    lines_added += 1;
                    maybe_print_new_line(f, true);
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
            for 1 .. lines_added - 1
            {
                // NOTE: This should only remove new lines.
                remove_characters(f, 1);
            }
        }
        // NOTE: Only indent after the last empty line.
        indent(f);
    }

    f.new_scope_started = false;
}

get_operator_string :: ( op: $T ) -> string
#modify  {  return T == _Operator || T == Unary_Operation.Operation; }
{
    result: string;
    
    #if T == Unary_Operation.Operation
    {
        if #complete op == 
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
        
        if #complete op == 
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
        case .ARRAY_SUBSCRIPT_ASSIGNMENT;
            result = "[]=";
        }
    }
    return result;
}

begin_arguments :: inline (f: *Jai_Formatter)
{
    f.inside_arguments_count += 1;
    f.inside_arguments = true;
}

end_arguments :: inline (f: *Jai_Formatter)
{
    f.inside_arguments_count -= 1;
    f.inside_arguments = f.inside_arguments_count != 0;
}

space :: inline(f: *Jai_Formatter)
{
    print(f, " ");
    f.previous_print_type = .SPACE;
}

semicolon :: inline(f: *Jai_Formatter)
{
    print(f, ";");
}

maybe_print_space :: inline ( f: *Jai_Formatter, should_print: bool )
{
    if should_print
    {
        space(f);
    }
}

maybe_print_new_line :: inline ( f: *Jai_Formatter, should_print: bool, should_indent := false )
{
    if should_print
    {
        if f.previous_print_type == .SPACE
        {
            remove_spaces(f, 1);
        }
        print( f, "\n" );
        f.current_collumn = 0;
        f.previous_print_type = .NEW_LINE;
        if should_indent
        {
            indent(f);
        }
    }
}

maybe_print_comma :: inline ( f: *Jai_Formatter, values: []$T, index: int )
{
    if index != values.count - 1
    {
        print( f, "," );
        space(f);
    }
}

open_paren :: inline (f: *Jai_Formatter, extra_condition := true)
{
    spaces_to_remove: int;
    if f.current_alignment > 0 && f.previous_print_type == .INDENT
    {
        spaces_to_remove = ifx f.spaces_inside_parens && extra_condition then 2 else 1;
        remove_spaces(f, spaces_to_remove);
    }

    print(f, "(");
    maybe_print_space(f, f.spaces_inside_parens && extra_condition);
    push_alignment(f, -spaces_to_remove);
}

close_paren :: inline (f: *Jai_Formatter, extra_condition := true)
{
    pop_alignment(f);
    maybe_print_space(f, f.spaces_inside_parens && extra_condition);
    print(f, ")");
}

space_separated_node_list :: inline (f: *Jai_Formatter, list: []*Node)
{
    for list
    {
        print_node(f, it);
        maybe_print_space(f, it_index != list.count - 1);
    }
}

comma_separated_node_list :: inline(f: *Jai_Formatter, list: []*Node)
{
    for list
    {
        print_node(f, it);
        maybe_print_comma(f, list, it_index);
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
    to_print := tprint(format, ..args);
    if f.buffer.count + to_print.count > f.max_buffer_size
    {
        new_size := 2 * f.max_buffer_size;
        f.buffer.data = realloc(f.buffer.data, new_size, f.max_buffer_size);
        f.max_buffer_size = new_size;
    }

    memcpy(f.buffer.data + f.buffer.count, to_print.data, to_print.count);
    f.buffer.count += to_print.count;

    f.current_collumn += to_print.count;
    f.previous_print_type = .STRING;
}

push_alignment :: inline (f: *Jai_Formatter, extra_alignment: int = 0)
{
    amount := f.current_collumn - f.indent_level * f.indent_string.count - f.current_alignment;
    amount += extra_alignment;
    assert(amount >= 0);
    array_add(*f.alignments, amount);
    f.current_alignment += amount;
}

pop_alignment :: inline (f: *Jai_Formatter)
{
    if f.alignments.count > 0 
    {
        last_alignment := pop(*f.alignments);
        f.current_alignment -= last_alignment;
        assert(f.current_alignment >= 0);
    }
    else
    {
        log_error("Mismatched pop_alignment");
    }
}

clear_alignment :: inline (f: *Jai_Formatter)
{
    array_reset_keeping_memory(*f.alignments);
    f.current_alignment = 0;
}

indent :: inline ( f: *Jai_Formatter )
{
    for 0..f.indent_level - 1
    {
        print(f, f.indent_string);
    }

    for 0..f.current_alignment - 1
    {
        space(f);
    }
    f.previous_print_type = .INDENT;
}

remove_characters :: inline (f: *Jai_Formatter, count: int)
{
    assert(f.buffer.count >= count);
    f.buffer.count -= count;
}

remove_indent :: inline ( f: *Jai_Formatter, count: int )
{
    to_remove := count * f.indent_width;
    // NOTE: There should always be space in the current line when we remove spaces.
    assert(to_remove <= f.current_collumn);
    remove_characters(f, to_remove);
}

remove_spaces :: inline ( f: *Jai_Formatter, count: int )
{
    // NOTE: There should always be space in the current line when we remove spaces.
    assert(count <= f.current_collumn);
    remove_characters(f, count);
}

parent_is :: inline ( node: *Node, kind: Node.Kind ) -> bool
{
    return node && node.parent && node.parent.kind == kind;
}

node_is :: inline ( node: *Node, kind: Node.Kind ) -> bool
{
    return node && node.kind == kind;
}

get_indent_string :: (config: Formatter_Config) -> string
{
    indent_builder: String_Builder;
    for 0..config.indent_width - 1
    {
        print( *indent_builder, " " );
    }
    return builder_to_string( *indent_builder );
}

