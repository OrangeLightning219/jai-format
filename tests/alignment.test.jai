ALIGN :: #string DONE
test :: () {
    a := 1 + 2 + 
    (3 + 4 + 
    5 + 6) * 0.5 + 
    5;

    if a + 
        b * (a - b / 
        c) > 0 {

    }

    while a + b * (a - 
        b / c) > 0 {
    }

    for value, index:
        things {

        }

    a := Struct.{1, 2, 
    3, test(a, 
    b, c), 4, 
    5};

    a := int.[1, 2, 
    3, 4, 5, 
    6, 7];
}
DONE

alignment_disabled :: () -> Test_Parameters
{
    using result: Test_Parameters;
    config.alignment_mode = .DISABLED;
    source_code = ALIGN;
    expected_output = #string DONE
test :: () {
    a := 1 + 2 +
    (3 + 4 +
    5 + 6) * 0.5 +
    5;

    if a +
    b * (a - b /
    c) > 0 {
    }

    while a + b * (a -
    b / c) > 0 {
    }

    for value, index:
    things {
    }

    a := Struct.{1, 2,
    3, test(a,
    b, c), 4,
    5};

    a := int.[1, 2,
    3, 4, 5,
    6, 7];
}
DONE;

    return result;
} @Test

alignment_indent :: () -> Test_Parameters
{
    using result: Test_Parameters;
    config.alignment_mode = .INDENT_ONLY;
    source_code = ALIGN;
    expected_output = #string DONE
test :: () {
    a := 1 + 2 +
        (3 + 4 +
            5 + 6) * 0.5 +
        5;

    if a +
        b * (a - b /
            c) > 0 {
    }

    while a + b * (a -
            b / c) > 0 {
    }

    for value, index:
        things {
    }

    a := Struct.{1, 2,
            3, test(a,
                b, c), 4,
            5};

    a := int.[1, 2,
            3, 4, 5,
            6, 7];
}
DONE;

    return result;
} @Test

alignment_exact :: () -> Test_Parameters
{
    using result: Test_Parameters;
    config.alignment_mode = .EXACT;
    source_code = ALIGN;
    expected_output = #string DONE
test :: () {
    a := 1 + 2 +
         (3 + 4 +
          5 + 6) * 0.5 +
         5;

    if a +
       b * (a - b /
            c) > 0 {
    }

    while a + b * (a -
                   b / c) > 0 {
    }

    for value, index:
        things {
    }

    a := Struct.{1, 2,
                 3, test(a,
                         b, c), 4,
                 5};

    a := int.[1, 2,
              3, 4, 5,
              6, 7];
}
DONE;

    return result;
} @Test
