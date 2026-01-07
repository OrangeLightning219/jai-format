#import "Basic";
#import "Compiler";
#import "File";
#import "String";

#load "tests/tests.jai";

build :: ()
{
    set_build_options_dc( .{ do_output = false } );

    w := compiler_create_workspace( "jai-format" );
    if !w
    {
        print( "Workspace creation failed.\n" );
        return;
    }

    make_directory_if_it_does_not_exist( "build" );

    options := get_build_options( w );
    options.output_executable_name = "jai-format";
    options.output_path = "build";

    #if CPU == .X64
    {
        options.backend = .X64;
    } 
    else
    {
        options.backend = .LLVM;
    }

    // options.text_output_flags = .OUTPUT_TIMING_INFO;
    options.text_output_flags = 0;

    args := options.compile_time_command_line;

    tests: bool;
    release: bool;
    for arg: args
    {
        if arg ==
        {
        case "test";
            tests = true;
        case "release";
            release = true;
        }
    }

    if tests
    {
        run_tests();
    }
    else
    {
        if release
        {
            options.backend = .LLVM;
            set_optimization( *options, .OPTIMIZED );
        }

        set_build_options( options, w );

        compiler_begin_intercept( w );
        add_build_file( "main.jai", w );
        compiler_end_intercept( w );
    }
}

#run build();
