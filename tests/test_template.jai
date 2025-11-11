#import "Basic";
#import "String";
#import "Print_Color";

#import,file "../module.jai";

Test_Parameters :: struct
{
    config: Formatter_Config;
    source_code: string;
    expected_output: string;
    expected_result := Formatter_Status.OK;
}

test_formatting :: ( params: Test_Parameters ) -> bool
{
    // TODO: Maybe add some parameters that enable logging from the formatter during tests
    context.logger = silent_logger;

    config := params.config;
    // NOTE: Here strings only use \n as line endings. To use \r\n we would need to specify the ,cr modifier on #string. We don't want that to make sure that the tests can be run on any system.
    config.no_carriage_return_on_windows = true;
    formatter := make_formatter(config);
    defer deinit_formatter(*formatter);
    status, output := format_from_string( *formatter, params.source_code );

    if status != params.expected_result
    {
        print_color( " [FAILED] - expected result was '%' but got '%'.\n", params.expected_result, status, color = .HI_RED );
        return false;
    }

    expected_output := params.expected_output;
    if output != expected_output
    {
        print_color( " [FAILED] - output doesn't match expected output.\n", color = .HI_RED );
        print_output_diff( output, expected_output );
        return false;
    }

    print_color( " [PASSED]\n", color = .HI_GREEN );
    return true;
}

print_output_diff :: ( output: string, expected_output: string )
{
    output_lines := split( output, "\n" );
    expected_lines := split( expected_output, "\n" );

    diff_line := -1;
    diff_column := -1;
    for expected_line: expected_lines
    {
        if it_index < output_lines.count
        {
            output_line := output_lines[ it_index ];
            if expected_line != output_line
            {
                diff_line = it_index;
                for char, char_index: expected_line
                {
                    if char_index < output_line.count
                    {
                        if char != output_line[ char_index ]
                        {
                            diff_column = char_index;
                            break;
                        }
                    }
                }

                if diff_column == -1
                {
                    diff_column = output_line.count;
                }
                break;
            }
        }
    }

    got_eof: bool;
    if diff_line == -1
    {
        diff_line = expected_lines.count - 1;
        got_eof = true;
    }

    print( "Difference at line %:\n", diff_line + 1 );
    print( "Expected: '%'\n", expected_lines[ diff_line ] );
    print( "Got:      '%'\n", ifx got_eof then "EOF" else output_lines[ diff_line ] );
    if diff_column >= 0
    {
        print( "           " );
        for 0..diff_column - 1
        {
            print( " " );
        }
        print( "^\n" );
    }
}

print_config_diff :: ( config: Formatter_Config )
{
    default_config: Formatter_Config;
    diff_found: int;
    print( "{" );
    #insert -> string
    {
        builder: String_Builder;
        ti := type_info( Formatter_Config );
        for ti.members
        {
            print( *builder, #string,\% DONE
            if config.%1 != default_config.%1 
            { 
                print("\% = \%;", "%1", config.%1); 
                diff_found += 1;
            }
            DONE,

                   it.name );
            print( *builder, "if diff_found > 1 print(\"\\n\");" );
        }
        return builder_to_string( *builder );
    }
    print( "}" );
}

silent_logger :: ( message: string, data: *void, info: Log_Info ) {}
