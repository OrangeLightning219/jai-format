#import "Basic";
#import "Socket";
#import "File";
#import "File_Utilities";
#import "Hash_Table";
#import "String";
#import "Process";

File_State :: struct 
{
    modtime: Apollo_Time;
    size: s64;
}

test :: asdasd( asd: string, 
                zxc: int, 
                qwe: u32, 
                sdf: float ) -> ( wer: int, xcv: bool, 
                                  dfg: s16 )
{
}

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
    
    for all_files
    {
        modtime, size, ok := file_modtime_and_size( it );
        assert( ok );
        file_state: File_State;
        file_state.modtime = modtime;
        file_state.size = size;
        current_state, found := table_find( *file_states, it );
        if found
        {
            if current_state.modtime != modtime || current_state.size != size
            {
                array_add( *files_to_parse, it );
                table_set( *file_states, it, file_state );
            }
        }
        else 
        {
            array_add( *files_to_parse, it );
            table_set( *file_states, it, file_state );
        }
    }
}
parser_path :: #run get_parser_path();

get_parser_path :: () -> string
{
    current_dir := replace( get_working_directory(), "\\", "/" );
    return tprint( "%/parser.jai", current_dir );
}

main :: ()
{
    asd := 0b0101010;
    zxc := 10e2;
    zxc := 10.5e123;
    zxc := 10.5e-123;
    asd := -123.05;
    qwe := 0xffabcd;
    
    target_file, ok = file_open( filename, for_writing = true, keep_existing_content = false );
    
    asd=, ok := asdasd();
    asd, ok= := asdasd();
    if !ok
    {
        print( "Failed to open target file: %\n", filename );
        return;
    }
    test :: []int.[ int.[ 1, 
                          2, 
                          3 ], 
                    int.[ 4, 
                          5, 
                          6 ] ];
    keywords :: string.[ "if", "else", "return", "for", "while", 
                         "break", 
                         "struct", "enum", "enum_flags", "using", "case", .{ qwe = "asd" } ];
    
    test( ASD.{ asd = 123, qwe = 456 }, ZXC.{ qwe = 123, .{ dfg = 456 } }, .{ sdf = 987 } );
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
        
        // / /=
    case #char "/";
        if check_next_operator_char( tokenizer, *result, #char "=" )
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
    }
    
    failed := socket_init();
    if !failed //asdasd
    {
        print( "socket_init failed\n" );
        return;
    }
    
    test: u32 = cast,no_check( u32 )1.0;
    
    test1 :: #string,cr END
asdasdsda
  asd   zxc
 qqq 
END
    
    info: *addrinfo; // zxczxczxczxc
    hints: addrinfo;
    // asdasdasdasdsad asdasdzxczc 
    hints.ai_family = AF_INET;
    hints.ai_socktype = .SOCK_STREAM;
    // hints.ai_protocol = .IPPROTO_TCP;
    hints.ai_flags = .AI_PASSIVE;
    /* asdasdasd
 /*asasdasd*/
 zxczxczc
    */
    args := get_command_line_arguments();
    assert( args.count >= 2 );
    
    p := args[ 1 ];
    port := cast( *u8 )alloc( +p.count + 1 );
    memcpy( port, p.data, p.count );
    port[ -p.count ] = 0 + -p;
    
    result := getaddrinfo( -null, 
                           ( ~port, asd, 
                             zxc ), 
                           *hints, *info );
    
    insert_spaces := previous_token.type == .OPEN_PAREN || previous_token.type == .COMMA || 
                     previous_token.type == .OPEN_BRACKET || ( previous_token.type == .OPERATOR || 
                                                               previous_token.type == .COLON || 
                                                               previous_token.type == .NEW_LINE ) || 
                     asdasdasd;
    
    if previous_token.type == .OPEN_PAREN || previous_token.type == .COMMA || 
       previous_token.type == .OPEN_BRACKET || previous_token.type == .OPERATOR || 
       previous_token.type == .COLON || previous_token.type == .NEW_LINE
    {
    }
    
    while previous_token.type == .OPEN_PAREN || previous_token.type == .COMMA || 
          previous_token.type == .OPEN_BRACKET || previous_token.type == .OPERATOR || 
          previous_token.type == .COLON || previous_token.type == .NEW_LINE
    {
        test = <<asd;
        for <<asd
        {
        }
    }
    
    if result != 0
    {
        print( "getaddrinfo failed %d\n", result );
        WSACleanup();
        return;
    }
    
    listen_socket := INVALID_SOCKET;
    
    listen_socket = socket( info.ai_family, 
                            info.ai_socktype, 
                            info.ai_protocol );
    
    if listen_socket == INVALID_SOCKET
    {
        print( "socket creation failed %\n", get_last_socket_error() );
        WSACleanup();
        return;
    }
    
    result = bind( listen_socket, info.ai_addr, cast( s32 )info.ai_addrlen );
    
    if result == SOCKET_ERROR
    {
        print( "bind failed %\n", get_last_socket_error() );
        closesocket( listen_socket );
        WSACleanup();
        return;
    }
    
    result = listen( listen_socket, SOMAXCONN );
    
    if result == SOCKET_ERROR
    {
        print( "listen failed %\n", result );
        closesocket( listen_socket );
        WSACleanup();
        return;
    }
    
    client_socket := INVALID_SOCKET;
    client_socket = accept( listen_socket );
    
    if client_socket == INVALID_SOCKET
    {
        print( "accept failed %\n", get_last_socket_error() );
        closesocket( listen_socket );
        WSACleanup();
        return;
    }
    
    receive_buffer: [ 512 ]u8;
    
    print( "Listening for messages...\n" );
    
    parser: MP_Parser;
    
    RESPONSE_BUFFER_SIZE :: 1024 * 1024;
    response_buffer: *u8 = alloc( RESPONSE_BUFFER_SIZE );
    encoder: MP_Encoder;
    encoder.at = response_buffer;
    encoder.allocated_size = RESPONSE_BUFFER_SIZE;
    
    file_states: Table( string, File_State );
    
    running := true;
    
    context.allocator = temp;
    while running
    {
        reset_temporary_storage();
        bytes_received := recv( client_socket, receive_buffer.data, receive_buffer.count, 0 );
        
        if bytes_received > 0
        {
            parser.at = receive_buffer.data;
            
            array_length := parse_array_length( *parser );
            assert( array_length == 4 );
            
            interaction_type := parse_uint( *parser );
            assert( interaction_type == 0 );
            
            message_id := parse_uint( *parser );
            command := parse_string( *parser );
            
            arg_count := parse_array_length( *parser );
            assert( arg_count == 0 );
            
            print( "Received command %\n", command );
            
            encoder.at = response_buffer;
            encoder.length = 0;
            
            encode_array( 4, *encoder );
            encode_uint( 1, *encoder );
            encode_uint( message_id, *encoder );
            encode_nil( *encoder );
            
            if command == "Exit"
            {
                encode_uint( 0, *encoder );
                print( "Exiting...\n" );
                running = false;
            }
            else if command == "GetDeclarations"
            {
                config, ok := read_entire_file( ".nvim-jai" );
                
                if ok
                {
                    all_files := split( config, "\n" );
                    files_to_parse: [ .. ]string;
                    for all_files
                    {
                        modtime, size, ok := file_modtime_and_size( it );
                        assert( ok );
                        file_state: File_State;
                        file_state.modtime = modtime;
                        file_state.size = size;
                        current_state, found := table_find( *file_states, it );
                        if found
                        {
                            if current_state.modtime != modtime || current_state.size != size
                            {
                                array_add( *files_to_parse, it );
                                table_set( *file_states, it, file_state );
                            }
                        }
                        else 
                        {
                            array_add( *files_to_parse, it );
                            table_set( *file_states, it, file_state );
                        }
                    }
                    
                    send_update := files_to_parse.count != 0;
                    
                    if send_update
                    {
                        print( "%\n", files_to_parse );
                        arguments := join( ..files_to_parse, " " );
                        command := break_command_into_strings( tprint( "jai % - %", parser_path, arguments ) );
                        print( "Running parser: %\n", command );
                        process_result, output, error, timeout_reached := run_command( ..command );
                        print( "Process result: %\n", process_result );
                        send_update = process_result.exit_code == 2;
                    }
                    
                    encode_array( 2, *encoder );
                    encode_bool( send_update, *encoder );
                    
                    if send_update
                    {
                        _, size, ok := file_modtime_and_size( "declarations.response" );
                        assert( encoder.length + size <= encoder.allocated_size );
                        response: File;
                        response, ok = file_open( "declarations.response", for_writing = false );
                        assert( ok );
                        success, bytes_read := file_read( response, encoder.at, size );
                        assert( success && bytes_read > 0 );
                        encoder.length += cast( u32 )bytes_read;
                        file_close( *response );
                        file_delete( "declarations.response" );
                    }
                    else 
                    {
                        encode_nil( *encoder );
                    }
                }
            }
            
            bytes_sent := send( client_socket, response_buffer, cast( s32 )encoder.length, 0 );
            
            if bytes_sent == SOCKET_ERROR
            {
                print( "send failed %d\n", get_last_socket_error() );
                closesocket( client_socket );
                WSACleanup();
                return;
            }
            else 
            {
                print( "Response sent\n" );
            }
        }
    }
    
    result = shutdown( client_socket, SD_SEND );
    
    if result == SOCKET_ERROR
    {
        print( "shutdown failed %d\n", get_last_socket_error() );
    }
    
    closesocket( client_socket );
    WSACleanup();
}

