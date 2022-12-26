#import "Basic";
#import "File";
#import "String";

is_whitespace :: inline ( c: u8 ) -> bool
{
    result := c == #char " " || c == #char "\t" || c == #char "\\";
    return result;
}

eat_all_whitespace :: ( tokenizer: *string)
{
    while true
    {
        if is_whitespace( tokenizer.data[ 0 ] )
        {
            advance(tokenizer);
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

operator == :: (a: Token, b: Token) -> bool
{
    return a.type == b.type && a.text == b.text;
}

operator == :: (a: Token, b: string) -> bool
{
    return a.text == b;
}

get_token :: ( tokenizer: *string) -> Token
{
    // @TODO: Treat comments as tokens, not whitespace
    eat_all_whitespace( tokenizer );

    result: Token;
    result.text.count = 1;
    result.text.data = tokenizer.data;

    c := <<tokenizer.data;
    if tokenizer.count > 0
    {
        advance(tokenizer);
    }
    else
    {
        result.type = .END_OF_STREAM;
        return result;
    }

    check_next_operator_char :: (tokenizer: *string, token: *Token, chars: ..u8) -> bool
    {
        for chars
        {
            if it == tokenizer.data[ 0 ]
            {
                token.text.count = 2;
                advance(tokenizer);
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
            if check_next_operator_char(tokenizer, *result, #char "=")
            {
                result.type = .OPERATOR;
            }
            else if tokenizer.data[ 0 ] == #char "/"
            {
                result.type = .COMMENT;
                advance(tokenizer, 2);
                while tokenizer.data[ 0 ] && tokenizer.data[ 0 ] != #char "\n"
                {
                    advance(tokenizer);
                }
                result.text.count = tokenizer.data - result.text.data;
            }
            else if tokenizer.data[ 0 ] == #char "*"
            {
                result.type = .COMMENT;
                advance(tokenizer, 2);
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
                    advance(tokenizer);
                }
                advance(tokenizer);
                
                result.text.count = tokenizer.data - result.text.data;
            }
            else 
            {
                result.type = .OPERATOR;
            }
        
        // ^ ^=
        case #char "^"; #through;
        // % %=
        case #char "%"; #through;
        // > >= 
        case #char ">"; #through;
        // + +=
        case #char "+"; #through;
        // * *=
        case #char "*"; #through; 
        // = == 
        case #char "=";
            result.type = .OPERATOR;
            check_next_operator_char(tokenizer, *result, #char "=");
        
        // < <= <<
        case #char "<";
            result.type = .OPERATOR;
            check_next_operator_char(tokenizer, *result, #char "=", #char "<");
            
        // | || |=
        case #char "|";
            result.type = .OPERATOR;
            check_next_operator_char(tokenizer, *result, #char "=", #char "|");
            
        // & && &=
        case #char "&";
            result.type = .OPERATOR;
            check_next_operator_char(tokenizer, *result, #char "=", #char "&");
            
        // ! != 
        case #char "!";
            if check_next_operator_char(tokenizer, *result, #char "=") { result.type = .OPERATOR; }
            else { result.type = .UNKNOWN; }

        // : :: :=
        case #char ":"; 
            if check_next_operator_char(tokenizer, *result, #char "=", #char ":") { result.type = .OPERATOR; }
            else { result.type = .COLON; }

        // - -= ->
        case #char "-";
            result.type = .OPERATOR;
            check_next_operator_char(tokenizer, *result, #char "=", #char ">");
        
        case #char "\r";
            assert(tokenizer.data[ 0 ] == #char "\n");
            result.type = .NEW_LINE;
            result.text.count = 2;
            advance(tokenizer);

        case #char "#";
            result.type = .DIRECTIVE;
            while tokenizer.data[ 0 ] && (is_alpha( tokenizer.data[ 0 ]) || tokenizer.data[ 0 ] == #char ",")
            {
                if tokenizer.data[ 0 ] == #char ","
                {
                    advance(tokenizer);
                    eat_all_whitespace(tokenizer);
                }
                else
                {
                    advance(tokenizer);
                }
            }
            result.text.count = tokenizer.data - result.text.data;

        case #char "\"";
            result.type = .STRING;
            while tokenizer.data[ 0 ] && tokenizer.data[ 0 ] != #char "\""
            {
                if tokenizer.data[ 0 ] == #char "\\" && tokenizer.data[ 1 ]
                {
                    advance(tokenizer);
                }
                advance(tokenizer);
            }

            if tokenizer.data[ 0 ] == #char "\""
            {
                advance(tokenizer);
            }
            result.text.count = tokenizer.data - result.text.data;

        case;
            if is_alnum( c )
            {
                result.type = .IDENTIFIER;
                while tokenizer.data[ 0 ] && is_alnum( tokenizer.data[ 0 ] )
                {
                    advance(tokenizer);
                }
                result.text.count = tokenizer.data - result.text.data;

                keywords :: string.["if", "else", "return", "for", "while", "break", "struct", "enum", "enum_flags", "using", "case"];
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
                    advance(tokenizer);
                }

                if tokenizer.data[ 0 ] == #char "." || tokenizer.data[ 0 ] == #char "b"
                {
                    while is_digit( tokenizer.data[ 0 ] )
                    {
                        advance(tokenizer);
                    }
                }
                else if tokenizer.data[ 0 ] == #char "x"
                {
                    while is_digit( tokenizer.data[ 0 ] ) || is_alpha( tokenizer.data[ 0 ] )
                    {
                        advance(tokenizer);
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

main :: ()
{
    args := get_command_line_arguments();

    for 1 .. args.count - 1
    {
        print("Formatting %\n", args[it]);
        filename := args[it];
        
        file_to_format, ok := read_entire_file(filename);

        target_file: File;
        target_file, ok = file_open(filename, for_writing = true, keep_existing_content = false);

        if !ok
        {
            print("Failed to open target file: %\n", filename);
            return;
        }

        tokenizer := file_to_format;
        parsing := true;

        indent_level := 0;
        indent_string := "    ";
        alignment_indents: [..]int;

        previous_token: Token;
        new_lines_in_row := 0;
        last_new_line_position := 0;

        add_alignment :: (target_file: File, alignment_indents: *[..]int, last_new_line_position: int, 
                          indent_level: int, indent_string: string)
        {
            ok, current_position := file_tell(target_file);
            alignment := (current_position - last_new_line_position) - indent_level * indent_string.count;
            if alignment_indents.count > 0
            {
                current_alignment := 0;
                for <<alignment_indents
                {
                    current_alignment += it;
                }

                alignment = alignment - current_alignment;
            }
            array_add(alignment_indents, alignment);
        }

        pop_alignment :: (alignment_indents: *[..]int)
        {
            if alignment_indents.count > 0
            {
                pop(alignment_indents);
            }
        }

        while parsing
        {
            token := get_token(*tokenizer);
            using token;
            
            if type != .NEW_LINE
            {
                new_lines_in_row = 0;
            }

            if type ==
            {
                case .NEW_LINE;
                    new_lines_in_row += 1;
                    
                    temp_tokenizer := tokenizer;
                    next_token := get_token(*temp_tokenizer);
                    if next_token.type == .CLOSE_BRACE && new_lines_in_row > 1
                    {
                        // skip new line between last statement in block and closing brace
                        offset := indent_level * indent_string.count + text.count;
                        file_seek(target_file, -offset, .CURRENT);
                    }

                    if new_lines_in_row <= 2
                    {
                        file_write(*target_file, text);
                        ok: bool;
                        ok, last_new_line_position = file_tell(target_file);
                        for 1 .. indent_level
                        {
                            file_write(*target_file, indent_string);
                        }
                        
                        total_alignment := 0;
                        for alignment_indents
                        {
                            total_alignment += it;
                        }

                        for 1 .. total_alignment
                        {
                            file_write(*target_file, " ");
                        }
                    }

                case .OPEN_BRACE;
                    indent_level += 1;        
                    if alignment_indents.count > 0
                    {
                        offset := -alignment_indents[alignment_indents.count - 1];
                        file_seek(target_file, offset, .CURRENT);
                    }
                    file_write(*target_file, text);
                    pop_alignment(*alignment_indents);

                case .CLOSE_BRACE;
                    indent_level -= 1;
                    if previous_token.type == .NEW_LINE
                    {
                        file_seek(target_file, -indent_string.count, .CURRENT);
                    }
                    file_write(*target_file, text);

                case .OPEN_PAREN;
                    temp_tokenizer := tokenizer;
                    next_token := get_token(*temp_tokenizer);
                    file_write(*target_file, text);
                    if next_token.type != .CLOSE_PAREN
                    {
                        file_write(*target_file, " ");
                    }

                    add_alignment(target_file, *alignment_indents, last_new_line_position, indent_level, indent_string);

                case .CLOSE_PAREN;
                    pop_alignment(*alignment_indents);

                    if previous_token.type != .OPEN_PAREN
                    {
                        file_write(*target_file, " ");        
                    }
                    file_write(*target_file, text);

                case .OPEN_BRACKET;
                    temp_tokenizer := tokenizer;
                    next_token := get_token(*temp_tokenizer);
                    file_write(*target_file, text);
                    if next_token.type != .CLOSE_BRACKET
                    {
                        file_write(*target_file, " ");
                    }

                case .CLOSE_BRACKET;
                    if previous_token.type != .OPEN_BRACKET
                    {
                        file_write(*target_file, " ");        
                    }
                    file_write(*target_file, text);

                
                case .COLON; #through;
                case .COMMA;
                    file_write(*target_file, text);

                    if previous_token != "cast" && previous_token != "xx"
                    {
                        file_write(*target_file, " ");
                    }
                
                case .DIRECTIVE; #through;
                case .KEYWORD;
                    if previous_token.type != .NEW_LINE && 
                       previous_token.type != .KEYWORD && 
                       previous_token.type != .DIRECTIVE &&
                       previous_token.type != .OPERATOR &&
                       previous_token.type != .UNKNOWN
                    {
                        file_write(*target_file, " ");
                    }
                    
                    if type == .DIRECTIVE
                    {
                        text = replace(text, " ", "");
                    }
                    else if text == "case"
                    {
                        file_seek(target_file, -(indent_string.count / 1), .CURRENT);
                    }

                    file_write(*target_file, text);

                    temp_tokenizer := tokenizer;
                    next_token := get_token(*temp_tokenizer);
                    if next_token.type != .SEMICOLON
                    {
                        file_write(*target_file, " ");
                    }

                    if type == .DIRECTIVE && begins_with(text, "#string")
                    {
                        string_delimiter := get_token(*tokenizer);
                        while token != string_delimiter
                        {
                            token = get_token(*tokenizer);
                        }
                        here_string: string;
                        here_string.data = string_delimiter.text.data;
                        here_string.count = (token.text.data - string_delimiter.text.data) + string_delimiter.text.count;
                        file_write(*target_file, here_string);
                    } 
                    else if type == .KEYWORD && (text == "if" || text == "while")
                    {
                        add_alignment(target_file, *alignment_indents, last_new_line_position, indent_level, indent_string);
                    }

                case .OPERATOR;
                    insert_spaces := !(previous_token.type == .OPEN_PAREN || previous_token.type == .COMMA || 
                                       previous_token.type == .OPEN_BRACKET || previous_token.type == .OPERATOR ||
                                       previous_token.type == .COLON || previous_token.type == .NEW_LINE ||
                                       previous_token.type == .KEYWORD);
                    if insert_spaces
                    {
                        file_write(*target_file, " ");
                    }
                    file_write(*target_file, text);
                    if insert_spaces
                    {
                        file_write(*target_file, " ");
                    }
                    if text == ":=" || text == "="
                    {
                        add_alignment(target_file, *alignment_indents, last_new_line_position, indent_level, indent_string);
                    }

                case .SEMICOLON;
                    file_write(*target_file, text);
                    file_write(*target_file, " ");
                    pop_alignment(*alignment_indents);

                case .END_OF_STREAM;
                    parsing = false;
                    print("End of parsing\n");

                case;
                    file_write(*target_file, text);
            }
            previous_token = token;
        }
        file_close(*target_file);
    }
}

