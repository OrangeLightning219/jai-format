#import "Basic";
#import "File";
#import "String";
#import "Reflection";

Formatter_Config :: struct 
{
    space_after_comma := true;
    spaces_inside_parens := true;
    spaces_inside_brackets := true;
    spaces_inside_struct_literals := true;
    spaces_around_operators := true;
    max_empty_lines_to_keep := 1;
    indent_width := 4;
}

config: Formatter_Config;
using config;

is_whitespace :: inline ( c: u8 ) -> bool
{
    result := c == #char " " || c == #char "\t" || c == #char "\\";
    return result;
}

eat_all_whitespace :: ( tokenizer: *string )
{
    while true
    {
        if is_whitespace( tokenizer.data[ 0 ] )
        {
            advance( tokenizer );
        }
        else 
        {
            break;
        }
    }
}

Token_Type :: enum 
{
    UNKNOWN;
    
    OPEN_PAREN;
    CLOSE_PAREN;
    OPEN_BRACKET;
    CLOSE_BRACKET;
    OPEN_BRACE;
    CLOSE_BRACE;
    
    COLON;
    SEMICOLON;
    COMMA;
    OPERATOR;
    
    IDENTIFIER;
    KEYWORD;
    DIRECTIVE;
    
    NUMBER;
    STRING;
    
    NEW_LINE;
    COMMENT;
    
    END_OF_STREAM;
}

Token :: struct 
{
    type: Token_Type;
    text: string;
}

operator == :: ( a: Token, b: Token ) -> bool
{
    return a.type == b.type && a.text == b.text;
}

operator == :: ( a: Token, b: string ) -> bool
{
    return a.text == b;
}

get_token :: ( tokenizer: *string ) -> Token
{
    eat_all_whitespace( tokenizer );
    
    result: Token;
    result.text.count = 1;
    result.text.data = tokenizer.data;
    
    c := <<tokenizer.data;
    if tokenizer.count > 0
    {
        advance( tokenizer );
    }
    else 
    {
        result.type = .END_OF_STREAM;
        return result;
    }
    
    check_next_operator_char :: ( tokenizer: *string, token: *Token, chars: ..u8 ) -> bool
    {
        for chars
        {
            if it == tokenizer.data[ 0 ]
            {
                token.text.count = 2;
                advance( tokenizer );
                return true;
            }
        }
        
        return false;
    }
    
    if c == 
    {
    case #char "("; result.type = .OPEN_PAREN;
    case #char ")"; result.type = .CLOSE_PAREN;
    case #char "["; result.type = .OPEN_BRACKET;
    case #char "]"; result.type = .CLOSE_BRACKET;
    case #char "{"; result.type = .OPEN_BRACE;
    case #char "}"; result.type = .CLOSE_BRACE;
    case #char ";"; result.type = .SEMICOLON;
    case #char ","; result.type = .COMMA;
    case #char "\n"; result.type = .NEW_LINE;
    case #char "~"; result.type = .OPERATOR;
        
        // / /= // /*
    case #char "/";
        if check_next_operator_char( tokenizer, *result,  #char "=" )
        {
            result.type = .OPERATOR;
        }
        else if tokenizer.data[ 0 ] == #char "/"
        {
            result.type = .COMMENT;
            advance( tokenizer, 2 );
            while tokenizer.data[ 0 ] && tokenizer.data[ 0 ] != #char "\n"
            {
                advance( tokenizer );
            }
            result.text.count = tokenizer.data - result.text.data;
        }
        else if tokenizer.data[ 0 ] == #char "*"
        {
            result.type = .COMMENT;
            advance( tokenizer, 2 );
            open_comments := 1;
            while tokenizer.data[ 0 ] && open_comments > 0
            {
                if tokenizer.data[ 0 ] == #char "*" && tokenizer.data[ 1 ] == #char "/"
                {
                    open_comments -= 1;
                }
                else if tokenizer.data[ 0 ] == #char "/" && tokenizer.data[ 1 ] == #char "*"
                {
                    open_comments += 1;
                }
                advance( tokenizer );
            }
            advance( tokenizer );
            
            result.text.count = tokenizer.data - result.text.data;
        }
        else 
        {
            result.type = .OPERATOR;
        }
        
        // ^ ^=
    case #char "^";  #through;
        // % %=
    case #char "%";  #through;
        // > >= 
    case #char ">";  #through;
        // + +=
    case #char "+";  #through;
        // * *=
    case #char "*";  #through;
        // = == 
    case #char "=";
        result.type = .OPERATOR;
        check_next_operator_char( tokenizer, *result,  #char "=" );
        
        // < <= <<
    case #char "<";
        result.type = .OPERATOR;
        check_next_operator_char( tokenizer, *result,  #char "=",  #char "<" );
        
        // | || |=
    case #char "|";
        result.type = .OPERATOR;
        check_next_operator_char( tokenizer, *result,  #char "=",  #char "|" );
        
        // & && &=
    case #char "&";
        result.type = .OPERATOR;
        check_next_operator_char( tokenizer, *result,  #char "=",  #char "&" );
        
        // ! != 
    case #char "!";
        if check_next_operator_char( tokenizer, *result,  #char "=" ) { result.type = .OPERATOR; }
        else { result.type = .UNKNOWN; }
        
        // : :: :=
    case #char ":";
        if check_next_operator_char( tokenizer, *result,  #char "=",  #char ":" ) { result.type = .OPERATOR; }
        else { result.type = .COLON; }
        
        // - -= ->
    case #char "-";
        result.type = .OPERATOR;
        check_next_operator_char( tokenizer, *result,  #char "=",  #char ">" );
        
    case #char "\r";
        assert( tokenizer.data[ 0 ] == #char "\n" );
        result.type = .NEW_LINE;
        result.text.count = 2;
        advance( tokenizer );
        
    case #char "#";
        result.type = .DIRECTIVE;
        while tokenizer.data[ 0 ] && ( is_alpha( tokenizer.data[ 0 ] ) || tokenizer.data[ 0 ] == #char "," )
        {
            if tokenizer.data[ 0 ] == #char ","
            {
                advance( tokenizer );
                eat_all_whitespace( tokenizer );
            }
            else 
            {
                advance( tokenizer );
            }
        }
        result.text.count = tokenizer.data - result.text.data;
        
    case #char "\"";
        result.type = .STRING;
        while tokenizer.data[ 0 ] && tokenizer.data[ 0 ] != #char "\""
        {
            if tokenizer.data[ 0 ] == #char "\\" && tokenizer.data[ 1 ]
            {
                advance( tokenizer );
            }
            advance( tokenizer );
        }
        
        if tokenizer.data[ 0 ] == #char "\""
        {
            advance( tokenizer );
        }
        result.text.count = tokenizer.data - result.text.data;
        
    case;
        if is_alnum( c )
        {
            result.type = .IDENTIFIER;
            while tokenizer.data[ 0 ] && is_alnum( tokenizer.data[ 0 ] )
            {
                advance( tokenizer );
            }
            result.text.count = tokenizer.data - result.text.data;
            
            keywords :: string.[ "if", "ifx", "else", "return", "for", "while", "break", "continue", "inline", 
                                 "struct", "enum", "enum_flags", "using", "case", "then", "xx" ];
            for keywords
            {
                if result == it
                {
                    result.type = .KEYWORD;
                    break;
                }
            }
        }
        else if is_digit( c )
        {
            result.type = .NUMBER;
            while is_digit( tokenizer.data[ 0 ] )
            {
                advance( tokenizer );
            }
            
            if tokenizer.data[ 0 ] == #char "." || tokenizer.data[ 0 ] == #char "b"
            {
                while is_digit( tokenizer.data[ 0 ] )
                {
                    advance( tokenizer );
                }
            }
            else if tokenizer.data[ 0 ] == #char "x"
            {
                while is_digit( tokenizer.data[ 0 ] ) || is_alpha( tokenizer.data[ 0 ] )
                {
                    advance( tokenizer );
                }
            }
            result.text.count = tokenizer.data - result.text.data;
        }
        else 
        {
            result.type = .UNKNOWN;
        }
    }
    
    return result;
}

push_alignment :: () #expand 
{
    alignment := ( `buffer.count - `last_new_line_position ) - `indent_level * `indent_string.count;
    if `alignment_indents.count > 0
    {
        current_alignment := 0;
        for `alignment_indents
        {
            current_alignment += it;
        }
        
        alignment = alignment - current_alignment;
    }
    array_add( *`alignment_indents, alignment );
}

pop_alignment :: () #expand 
{
    if `alignment_indents.count > 0
    {
        pop( *`alignment_indents );
    }
}

peek_token :: inline ( tokenizer: string ) -> Token
{
    return get_token( *tokenizer );
}

write :: ( text: string ) #expand 
{
    if `buffer.count + text.count > `max_buffer_size
    {
        new_size := 2 * `max_buffer_size;
        `buffer.data = realloc( `buffer.data, new_size, `max_buffer_size );
        `max_buffer_size = new_size;
    }
    
    memcpy( `buffer.data + `buffer.count, text.data, text.count );
    `buffer.count += text.count;
}

delete_chars :: ( offset: int ) #expand 
{
    if offset <= `buffer.count
    {
        `buffer.count -= offset;
    }
    else 
    {
        `buffer.count = 0;
    }
}

main :: ()
{
    config_file, success := read_entire_file( ".jai-format", log_errors = false );
    
    if success
    {
        config_file = replace( config_file, "\r", "" );
        lines := split( config_file, "\n" );
        for lines
        {
            if it.count > 0
            {
                temp := split( it, "=" );
                if temp.count == 2
                {
                    field_name := trim( temp[ 0 ] );
                    value_string := trim( temp[ 1 ] );
                    if !begins_with( field_name, "//" )
                    {
                        field := get_field( type_info( Formatter_Config ), field_name );
                        if field
                        {
                            print( "Setting % to %\n", field_name, value_string );
                            any: Any;
                            any.type = field.type;
                            any.value_pointer = ( cast( *u8 )( *config ) ) + field.offset_in_bytes;
                            set_value_from_string( any, value_string );
                        }
                        else 
                        {
                            print( "Invalid configuration option '%' at line %", field_name, it_index );
                        }
                    }
                }
                else 
                {
                    print( "Invalid config option at line %, expected format is: field_name = value\n", it_index );
                }
            }
        }
    }
    else 
    {
        print( "No config file found. Using default configuration\n" );
    }
    
    print( "Config: %\n", config );
    
    builder: String_Builder;
    init_string_builder( *builder, indent_width );
    
    for 1..indent_width
    {
        append( *builder, " " );
    }
    
    indent_string := builder_to_string( *builder );
    
    args := get_command_line_arguments();
    
    for 1..args.count - 1
    {
        print( "Formatting %\n", args[ it ] );
        filename := args[ it ];
        
        file_to_format, ok := read_entire_file( filename );
        
        max_buffer_size := file_to_format.count;
        buffer: string;
        buffer.data = alloc( max_buffer_size );
        
        tokenizer := file_to_format;
        parsing := true;
        
        indent_level := 0;
        alignment_indents: [ .. ]int;
        
        previous_token: Token;
        new_lines_in_row := 0;
        last_new_line_position := 0;
        
        while parsing
        {
            token := get_token( *tokenizer );
            using token;
            
            if type != .NEW_LINE
            {
                new_lines_in_row = 0;
            }
            
            if type == 
            {
            case .NEW_LINE;
                new_lines_in_row += 1;
                
                next_token := peek_token( tokenizer );
                if next_token.type == .CLOSE_BRACE && new_lines_in_row > 1
                {
                    // skip new line between last statement in block and closing brace
                    offset := ( indent_level * indent_string.count + text.count );
                    if new_lines_in_row <= max_empty_lines_to_keep + 1
                    {
                        offset *= ( new_lines_in_row - 1 );
                    }
                    else 
                    {
                        offset *= ( max_empty_lines_to_keep );
                    }
                    delete_chars( offset );
                }
                
                if new_lines_in_row <= max_empty_lines_to_keep + 1
                {
                    write( text );
                    last_new_line_position = buffer.count;
                    for 1..indent_level
                    {
                        write( indent_string );
                    }
                    
                    total_alignment := 0;
                    for alignment_indents
                    {
                        total_alignment += it;
                    }
                    
                    for 1..total_alignment
                    {
                        write( " " );
                    }
                }
                
            case .OPEN_BRACE;
                indent_level += 1;
                if alignment_indents.count > 0 && previous_token.type == .NEW_LINE
                {
                    offset := alignment_indents[ alignment_indents.count - 1 ];
                    delete_chars( offset );
                }
                else if previous_token.type != .NEW_LINE && previous_token.type != .KEYWORD && previous_token != "."
                {
                    write( " " );
                }
                
                write( text );
                
                if ( spaces_inside_struct_literals && previous_token == "." ) || previous_token.type != .NEW_LINE
                {
                    write( " " );
                }
                
                pop_alignment();
                if previous_token == "."
                {
                    push_alignment();
                }
                
            case .CLOSE_BRACE;
                indent_level -= 1;
                if previous_token.type == .NEW_LINE
                {
                    delete_chars( indent_string.count );
                }
                
                next_token := peek_token( tokenizer );
                if spaces_inside_struct_literals && ( next_token.type == .SEMICOLON || 
                                                      next_token.type == .COMMA || 
                                                      next_token.type == .OPERATOR || 
                                                      next_token.type == .CLOSE_PAREN || 
                                                      next_token.type == .CLOSE_BRACKET || 
                                                      next_token.type == .CLOSE_BRACE )
                {
                    write( " " );
                }
                
                write( text );
                pop_alignment();
                
            case .OPEN_PAREN;
                next_token := peek_token( tokenizer );
                write( text );
                if spaces_inside_parens && next_token.type != .CLOSE_PAREN
                {
                    write( " " );
                }
                push_alignment();
                
            case .CLOSE_PAREN;
                pop_alignment();
                if spaces_inside_parens && previous_token.type != .OPEN_PAREN
                {
                    write( " " );
                }
                write( text );
                
            case .OPEN_BRACKET;
                next_token := peek_token( tokenizer );
                write( text );
                if spaces_inside_brackets && next_token.type != .CLOSE_BRACKET
                {
                    write( " " );
                }
                push_alignment();
                
            case .CLOSE_BRACKET;
                if spaces_inside_brackets && previous_token.type != .OPEN_BRACKET
                {
                    write( " " );
                }
                write( text );
                pop_alignment();
                
            case .COLON;
                write( text );
                write( " " );
                
            case .COMMA;
                write( text );
                if space_after_comma && previous_token != "cast" && previous_token != "xx"
                {
                    write( " " );
                }
                
            case .DIRECTIVE;  #through;
            case .KEYWORD;
                if previous_token.type != .NEW_LINE && 
                   previous_token.type != .KEYWORD && 
                   previous_token.type != .DIRECTIVE && 
                   previous_token.type != .OPERATOR && 
                   previous_token.type != .OPEN_PAREN &&
                   previous_token.type != .COMMA &&
                   previous_token.type != .UNKNOWN
                {
                    write( " " );
                }
                
                if type == .DIRECTIVE
                {
                    text = replace( text, " ", "" );
                }
                else if text == "case"
                {
                    delete_chars( indent_string.count );
                }
                
                write( text );
                
                next_token := peek_token( tokenizer );
                if next_token.type != .SEMICOLON
                {
                    write( " " );
                }
                
                if type == .DIRECTIVE && begins_with( text, "#string" )
                {
                    string_delimiter := get_token( *tokenizer );
                    while token != string_delimiter
                    {
                        token = get_token( *tokenizer );
                    }
                    here_string: string;
                    here_string.data = string_delimiter.text.data;
                    here_string.count = ( token.text.data - string_delimiter.text.data ) + string_delimiter.text.count;
                    write( here_string );
                }
                else if type == .KEYWORD && ( text == "if" || text == "while" || text == "for" )
                {
                    push_alignment();
                }
                
            case .OPERATOR;
                insert_spaces := !( previous_token.type == .OPEN_PAREN || previous_token.type == .COMMA || 
                                    previous_token.type == .OPEN_BRACKET || previous_token.type == .OPERATOR || 
                                    previous_token.type == .COLON || previous_token.type == .NEW_LINE || 
                                    previous_token.type == .KEYWORD );
                
                if spaces_around_operators && insert_spaces
                {
                    write( " " );
                }
                
                write( text );
                
                if spaces_around_operators && ( insert_spaces || text == "::" )
                {
                    write( " " );
                }
                
                if alignment_indents.count == 0 && ( text == ":=" || text == "=" )
                {
                    push_alignment();
                }
                
            case .SEMICOLON;
                write( text );
                next_token := peek_token( tokenizer );
                if next_token.type != .NEW_LINE
                {
                    write( " " );
                }
                pop_alignment();
                
            case .END_OF_STREAM;
                parsing = false;
                print( "End of parsing\n" );
                
            case .COMMENT;
                if previous_token.type != .SEMICOLON && previous_token.type != .NEW_LINE
                {
                    write( " " );
                }
                write( text );
                
            case;
                write( text );
            }
            previous_token = token;
        }
        
        ok = write_entire_file( filename, buffer );
        if !ok
        {
            print( "Failed to write target file: %\n", filename );
            return;
        }
    }
}

