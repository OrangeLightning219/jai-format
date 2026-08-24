#scope_file

RESET_STATE_HEAVY :: #string OUTER
reset_state_heavy :: () {
    print_to_builder(
        *builder,
        #string INNER
            value %
        INNER,
        value);

    if value &&
        other_value {
        result := nested(first,
            second,
            third);
    }
}
OUTER

RESET_STATE_DIRECTIVES :: #string DONE
#scope_export

#insert #run generate_style_builder();

#module_parameters()();
DONE

RESET_STATE_SMALL :: "small :: () { call(value); }";

#scope_export

formatter_state_reset :: () -> Test_Parameters
{
    using result: Test_Parameters;

    sources: [ .. ]string;
    array_add( *sources, RESET_STATE_HEAVY );
    array_add( *sources, RESET_STATE_SMALL );
    array_add( *sources, RESET_STATE_DIRECTIVES );

    config.alignment_mode = .INDENT_ONLY;
    config.procedure_call_trailing_comma_mode = .ALWAYS;
    reuse_source_codes = sources;
    reuse_iterations = 32;
    return result;
} @Test
