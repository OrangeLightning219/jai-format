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
            set_optimization_level( *options, 2, 0 );
        }
    }
    
    files := string.[ "main.jai" ];
    
    nvim_jai, ok := file_open( ".nvim-jai", for_writing = true, keep_existing_content = false );
    assert( ok );
    
    current_dir := get_working_directory();
    file_content: string;
    for file: files
    {
        file_content = tprint( "%1%2/%3\n", file_content, replace( current_dir, "\\", "/" ), file );
    }
    file_content.count -= 1;
    
    file_write( *nvim_jai, file_content );
    file_close( *nvim_jai );
    
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
