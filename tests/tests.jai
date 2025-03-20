#import "IntroSort";
#import "File_Utilities";

run_tests :: ()
{
    w := compiler_create_workspace();
    options := get_build_options( w );
    options.output_type = .NO_OUTPUT;

    dir := path_strip_filename( get_absolute_path( "tests" ) );
    #if OS == .WINDOWS
    {
        dir = replace( dir, "\\", "/" );
    }

    import_path := options.import_path;
    imports: [ .. ]string;
    array_add( *imports, ..import_path );
    array_add( *imports, sprint( "%/modules", dir ) );
    options.import_path = imports;

    set_build_options( options, w );

    Load_Info :: struct
    {
        dir: string;
        files: [ .. ]string;
        builder: String_Builder;
    }
    load_info: Load_Info;
    load_info.dir = dir;

    visit :: ( info: *File_Visit_Info, load_info: *Load_Info )
    {
        if ends_with( info.short_name, ".test.jai" )
        {
            array_add( *load_info.files, copy_string( info.short_name ) );
            print( *load_info.builder, "#load \"%\";\n", info.full_name );
        }
    }
    visit_files( dir, true, *load_info, visit, visit_symlinks = false );

    print( *load_info.builder, "#load \"test_template.jai\";" );

    if load_info.files.count == 0
    {
        print( "No test files found in: %tests\n", dir );
        return;
    }

    compiler_begin_intercept( w );
    add_build_string( builder_to_string( *load_info.builder ), w );

    Test_Info :: struct
    {
        file: string;
        name: string;
        line_number: int;
    }
    tests: [ .. ]Test_Info;
    tests_generated: bool;

    while true
    {
        message := compiler_wait_for_message();
        if !message then continue;
        if message.workspace != w then continue;

        if message.kind ==
        {
        case .COMPLETE;
            break;
        case .TYPECHECKED;
            tc := message.( *Message_Typechecked );
            for tc.procedure_headers
            {
                header := it.expression;
                if !is_test( header ) then continue;

                test: Test_Info;
                test.file = copy_string( path_filename( get_filename( header ) ) );
                test.line_number = header.l0;
                test.name = copy_string( header.name );
                array_add( *tests, test );
            }
        case .PHASE;
            phase := message.( *Message_Phase );
            if phase.phase == .TYPECHECKED_ALL_WE_CAN && !tests_generated
            {
                if tests.count == 0 then continue;

                tests_generated = true;

                sort_by_file_and_line :: ( a: Test_Info, b: Test_Info ) -> int
                {
                    result := compare( a.file, b.file );
                    if result == 0
                    {
                        return ifx a.line_number < b.line_number then -1 else 1;
                    }
                    return result;
                }

                intro_sort( tests, sort_by_file_and_line );

                test_builder: String_Builder;
                print( *test_builder, "#run {\n" );

                BEFORE_TESTS :: #string DONE
                failed_count: int;
                total_count: int;
                ok: bool;
                DONE

                print( *test_builder, BEFORE_TESTS );

                current_group: string;
                for tests
                {
                    ok, group_name, rest := split_from_left( it.file, #char "." );
                    assert( ok );

                    if group_name != current_group
                    {
                        current_group = group_name;
                        print( *test_builder, "print(\"Running tests: [%]\\n\");", group_name );
                    }

                    FORMAT :: #string DONE
                    print("[Test]: '%1' ");
                    ok = test_formatting(%1());
                    if !ok then failed_count += 1;
                    total_count += 1;
                    DONE

                    print( *test_builder, FORMAT, it.name );
                }

                AFTER_TESTS :: #string,\% DONE
                if failed_count == 0
                {
                    print_color("\nAll tests passed.\n", color = .HI_GREEN);
                }
                else
                {
                    print_color("\nTests failed: \%.\n", failed_count, color = .HI_RED);
                    print_color("Tests passed: \%.\n", total_count - failed_count, color = .HI_GREEN);
                }
                DONE

                print( *test_builder, AFTER_TESTS );

                print( *test_builder, "}" );

                test_code := builder_to_string( *test_builder );
                add_build_string( test_code, w );
            }
        }
    }

    compiler_end_intercept( w );
}

is_test :: ( header: *Code_Procedure_Header ) -> bool
{
    if !header.name || !is_alpha( header.name[ 0 ] ) then return false;

    if !header.notes then return false;

    for note: header.notes
    {
        if note.text == "Test"
        {
            return true;
        }
    }
    return false;
}