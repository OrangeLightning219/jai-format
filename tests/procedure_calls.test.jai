#scope_file

MULTILINE_CALLS :: #string OUTER
format_calls :: () {
    print_to_builder(
        *builder,
        "value %",
        value,
    );

    print_to_builder(
        *builder,
        #string INNER
            value %
        INNER,
        value,
    );
}
OUTER

NEVER_TRAILING_COMMA_SOURCE :: #string SOURCE
format_calls :: () {
    empty();
    one(value,);
    many(
        first,
        second,
    );
}
SOURCE

NEVER_TRAILING_COMMA_EXPECTED :: #string EXPECTED
format_calls :: () {
    empty();
    one(value);
    many(
        first,
        second
    );
}
EXPECTED

ALWAYS_TRAILING_COMMA_SOURCE :: #string SOURCE
format_calls :: () {
    empty();
    one(value);
}
SOURCE

ALWAYS_TRAILING_COMMA_EXPECTED :: #string EXPECTED
format_calls :: () {
    empty();
    one(value,);
}
EXPECTED

MULTILINE_TRAILING_COMMA_SOURCE :: #string SOURCE
format_calls :: () {
    one(value,);
    many(
        first,
        second);
}
SOURCE

MULTILINE_TRAILING_COMMA_EXPECTED :: #string EXPECTED
format_calls :: () {
    one(value);
    many(
        first,
        second,
    );
}
EXPECTED

#scope_export

multiline_call_delimiters :: () -> Test_Parameters
{
    using result: Test_Parameters;
    config.alignment_mode = .INDENT_ONLY;
    source_code = MULTILINE_CALLS;
    expected_output = MULTILINE_CALLS;
    return result;
} @Test

never_trailing_comma :: () -> Test_Parameters
{
    using result: Test_Parameters;
    config.alignment_mode = .INDENT_ONLY;
    config.procedure_call_trailing_comma_mode = .NEVER;
    source_code = NEVER_TRAILING_COMMA_SOURCE;
    expected_output = NEVER_TRAILING_COMMA_EXPECTED;
    return result;
} @Test

always_trailing_comma :: () -> Test_Parameters
{
    using result: Test_Parameters;
    config.alignment_mode = .INDENT_ONLY;
    config.procedure_call_trailing_comma_mode = .ALWAYS;
    source_code = ALWAYS_TRAILING_COMMA_SOURCE;
    expected_output = ALWAYS_TRAILING_COMMA_EXPECTED;
    return result;
} @Test

multiline_trailing_comma :: () -> Test_Parameters
{
    using result: Test_Parameters;
    config.alignment_mode = .INDENT_ONLY;
    config.procedure_call_trailing_comma_mode = .MULTILINE;
    source_code = MULTILINE_TRAILING_COMMA_SOURCE;
    expected_output = MULTILINE_TRAILING_COMMA_EXPECTED;
    return result;
} @Test
