#import "Basic";
#import "Compiler";
#import "File";
#import "String";

build :: ()
{
    w := compiler_create_workspace( "jai-format" );
    if !w
    {
        print( "Workspace creation failed.\n" );
        return;
    }
    
    options := get_build_options( w );
    options.output_executable_name = "jai-format";
    options.output_path = "build";
    
    args := options.compile_time_command_line;
    
    for arg: args
    {
        if arg == "release"
        {
            set_optimization( *options, .OPTIMIZED );
        }
    }
    
    files := string.[ "main.jai" ];
    
    set_build_options( options, w );
    
    compiler_begin_intercept( w );
    
    for file: files
    {
        add_build_file( file, w );
    }
    
    compiler_end_intercept( w );
    
    set_build_options_dc( .{ do_output = false } );
}

#run build();
