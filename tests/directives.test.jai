#scope_file

MODULE_PARAMETERS_WITH_BODY :: #string DONE
#module_parameters (render_api := Render_API.OPENGL)() {
    Render_API :: enum u32 {
        OPENGL;
        METAL;
    }
}
DONE

EMPTY_MODULE_PARAMETER_LISTS :: #string DONE
#module_parameters()();
DONE

INSERT_RUN_AFTER_SCOPE_EXPORT :: #string DONE
#scope_export

#insert #run generate_style_builder();
DONE

#scope_export

module_parameters_with_body :: () -> Test_Parameters
{
    using result: Test_Parameters;
    source_code = MODULE_PARAMETERS_WITH_BODY;
    expected_output = #string DONE
#module_parameters(render_api := Render_API.OPENGL)() {
    Render_API :: enum u32 {
        OPENGL;
        METAL;
    }
}
DONE;
    return result;
} @Test

empty_module_parameter_lists :: () -> Test_Parameters
{
    using result: Test_Parameters;
    source_code = EMPTY_MODULE_PARAMETER_LISTS;
    expected_output = EMPTY_MODULE_PARAMETER_LISTS;
    return result;
} @Test

insert_run_after_scope_export :: () -> Test_Parameters
{
    using result: Test_Parameters;
    source_code = INSERT_RUN_AFTER_SCOPE_EXPORT;
    expected_output = INSERT_RUN_AFTER_SCOPE_EXPORT;
    return result;
} @Test
