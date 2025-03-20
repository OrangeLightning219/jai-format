#import "Basic";
#import "File";
#import "File_Utilities";
#import "String";
#import "Command_Line";
#import "Hash_Table";
#import "Print_Color"()( USE_ANSI_CODES_ON_WINDOWS = true );

#import,file "module.jai";

CLI_Arguments :: struct
{
    verbose: bool; @"?If set more output information will be printed."
    silent: bool; @"?If set no output will be printed other than the final result if -to_stdout is also set."
    to_stdout: bool; @"?If set the formatted output will be printed to standard out."
    to_file: bool; @"?If set the source file will be overwritten with the new formatted output."
    config_file := "./.jai-format"; @"?Path to a config file that should be used. If not set the formatter will search the current working directory for a .jai-format file. If no config is found the default config will be used."
    recursive: bool; @"?If set and there are directories in the argument list all directories will be formatted recursively."
    // config_overrides: [..]string; // TODO: Add option to override specific config options. This would require manually parsing the arguments because the Command_Line module currently doesn't support dynamic arrays.
}

INTERNAL :: false;
// INTERNAL :: true;

global_config: Formatter_Config;
cli_args: CLI_Arguments;

main :: ()
{
    ok, cli_args=, is_set, free_arguments := parse_arguments( CLI_Arguments );
    #if INTERNAL
    {
        cli_args.to_stdout = true;
        cli_args.to_file = false;
        cli_args.verbose = true;
        // cli_args.config_file = "";
    }
    if !ok then return;

    context.logger = custom_logger;
    context.logger_data = *cli_args;

    global_config = load_config( cli_args.config_file );
    context.print_style.default_format_struct.use_newlines_if_long_form = true;
    log_verbose( "Config:\n%", global_config );

    #if INTERNAL
    {
        TEST_FILE :: "test_code.jai";
        test_files: [ .. ]string;
        array_add( *test_files, TEST_FILE );
        free_arguments = test_files;
    }

    results: Table( string, bool );
    failed_count: int;
    for free_arguments
    {
        format :: () #expand
        {
            result, output := format_file( global_config, it );
            defer free( output.data );
            if !result then failed_count += 1;
            table_add( *results, it, result );

            if cli_args.to_stdout
            {
                print( "%\n", output );
            }

            if cli_args.to_file
            {
                #if FORMATTER_ENABLE_PROFILING { write_start := seconds_since_init(); }
                ok := write_entire_file( it, output );
                if !ok
                {
                    log_error( "Failed to write formatted code to file: '%'.", it );
                }
                #if FORMATTER_ENABLE_PROFILING
                {
                    write_time := seconds_since_init() - write_start;
                    log_verbose( "Writing time: %\n", write_time );
                }
            }
        }

        if is_directory( it )
        {
            files := file_list( it, cli_args.recursive );
            for files
            {
                format();
            }
        }
        else
        {
            format();
        }
    }

    log( "========== Summary ==========" );
    if failed_count > 0
    {
        log_nnl( "Failed to format" );
        with_console_color( .HI_RED, log_nnl( " % ", failed_count ), .BOLD );
        log( "file%", ifx failed_count == 1 then "" else "s" );
        for result, file: results
        {
            if !result
            {
                log( "  %", file );
            }
        }
    }

    success_count := results.count - failed_count;
    log_nnl( "Succesfully formatted" );
    with_console_color( .HI_GREEN, log_nnl( " % ", success_count ), .BOLD );
    log( "file%", ifx success_count == 1 then "" else "s" );
    for result, file: results
    {
        if result
        {
            log( "  %", file );
        }
    }
}

Logger_Flags :: enum_flags
{
    NO_NEW_LINE;
}

log_verbose :: ( format_string: string, args: ..Any, loc := #caller_location, flags := Log_Flags.NONE, user_flags: u32 = 0, section: *Log_Section = null )
{
    new_flags := flags | .VERBOSE_ONLY;
    log( format_string, ..args, loc, new_flags, user_flags, section );
} @PrintLike

log_verbose_nnl :: ( format_string: string, args: ..Any, loc := #caller_location, flags := Log_Flags.NONE, user_flags: u32 = 0, section: *Log_Section = null )
{
    new_flags := flags | .VERBOSE_ONLY;
    log( format_string, ..args, loc, new_flags, user_flags | xx Logger_Flags.NO_NEW_LINE, section );
} @PrintLike

log_nnl :: ( format_string: string, args: ..Any, loc := #caller_location, flags := Log_Flags.NONE, user_flags: u32 = 0, section: *Log_Section = null )
{
    log( format_string, ..args, loc, flags, user_flags | xx Logger_Flags.NO_NEW_LINE, section );
} @PrintLike

custom_logger :: ( message: string, data: *void, info: Log_Info )
{
    prefix := "";
    if info.common_flags ==
    {
    case .ERROR;
        prefix = "[ERROR]";
    case .WARNING;
        prefix = "[WARNING]";
    }

    if !data then return;

    args := data.( *CLI_Arguments );
    if args.silent then return;
    if !args.verbose && info.common_flags == .VERBOSE_ONLY then return;

    if prefix
    {
        color: Console_Color = ifx info.common_flags == .ERROR then .HI_RED else .HI_YELLOW;
        with_console_color( color, write_string( prefix ), .BOLD );
        write_string( " " );
    }
    s := tprint( "%", message );
    write_string( s );

    user_flags := info.user_flags.( Logger_Flags );

    if !( user_flags & .NO_NEW_LINE > 0 )
    {
        ends_with_new_line := s[ s.count - 1 ] == #char "\n";
        if !ends_with_new_line then write_string( "\n" );
    }
}
