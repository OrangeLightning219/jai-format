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
    reuse_source_codes: []string;
    reuse_iterations := 1;
}

test_formatting :: ( params: Test_Parameters ) -> bool
{
    // TODO: Maybe add some parameters that enable logging from the formatter during tests
    context.logger = silent_logger;

    config := params.config;
    // NOTE: Here strings only use \n as line endings. To use \r\n we would need to specify the ,cr modifier on #string. We don't want that to make sure that the tests can be run on any system.
    config.no_carriage_return_on_windows = true;

    if params.reuse_source_codes
    {
        return test_formatter_reuse( config, params.reuse_source_codes, params.reuse_iterations );
    }

    formatter := make_formatter( config );
    defer deinit_formatter( *formatter );

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

test_formatter_reuse :: ( config: Formatter_Config, source_codes: []string, iterations: int ) -> bool
{
    reused := make_formatter( config );
    defer deinit_formatter( *reused );

    for 1..iterations
    {
        iteration := it;
        for source_code: source_codes
        {
            reused_status, reused_output := format_from_string( *reused, source_code );

            fresh := make_formatter( config );
            fresh_status, fresh_output := format_from_string( *fresh, source_code );

            if reused_status != fresh_status
            {
                print_color( " [FAILED] - reused formatter returned '%' but a fresh formatter returned '%' at iteration %, source %.\n",
                             reused_status, fresh_status, iteration, it_index + 1, color = .HI_RED );
                deinit_formatter( *fresh );
                return false;
            }

            if reused_output != fresh_output
            {
                print_color( " [FAILED] - reused formatter output differs at iteration %, source %.\n",
                             iteration, it_index + 1, color = .HI_RED );
                print_output_diff( reused_output, fresh_output );
                deinit_formatter( *fresh );
                return false;
            }

            deinit_formatter( *fresh );
        }
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

    print( "Full output:\n" );
    for output_lines
    {
        marker := ifx it_index == diff_line then ">>" else "  ";
        print( "%%\n", marker, it );
    }
}

silent_logger :: ( message: string, data: *void, info: Log_Info ) {}
