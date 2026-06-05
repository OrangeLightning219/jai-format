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

    test(a, Struct.{1, 2, 
    3, 4}, b, c,
    d, e);
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

    test(a, Struct.{1, 2,
    3, 4}, b, c,
    d, e);
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

    test(a, Struct.{1, 2,
        3, 4}, b, c,
        d, e);
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

    test(a, Struct.{1, 2,
                    3, 4}, b, c,
         d, e);
}
DONE;

    return result;
} @Test

ALIGN1 :: #string DONE
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

    a := Struct.{1, 2, 3, test(a, b, c), 4, 5};

    a := int.[1, 2, 
    3, 4, 5, 
    6, 7];
}
DONE

mixed_alignment :: () -> Test_Parameters
{
    using result: Test_Parameters;
    config.alignment_mode = .DISABLED;
    config.declaration_alignment_mode = .INDENT_ONLY;
    config.expression_alignment_mode = .EXACT;
    config.parens_alignment_mode = .EXACT;
    config.brackets_alignment_mode = .INDENT_ONLY;
    source_code = ALIGN1;
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

    a := Struct.{1, 2, 3, test(a, b, c), 4, 5};

    a := int.[1, 2,
        3, 4, 5,
        6, 7];
}
DONE;

    return result;
} @Test

ALIGN2 :: #string DONE
test :: () {
    a := 1 + 2 + 
        (3 + 4 + 
        5 + 6) * 0.5 + 
        5;

    if a + 
        b * (a - b / 
        c) > 0 {

    }
}
DONE

wrap_before_operator :: () -> Test_Parameters
{
    using result: Test_Parameters;
    config.alignment_mode = .EXACT;
    config.wrap_before_operators = true;
    source_code = ALIGN2;
    expected_output = #string DONE
test :: () {
    a := 1 + 2
         + (3 + 4
            + 5 + 6) * 0.5
         + 5;

    if a
       + b * (a - b
              / c) > 0 {
    }
}
DONE;

    return result;
} @Test

ALIGN3 :: #string DONE
test :: () {
    a := Struct.{1, 2, 3, 
    4, 5, 
    6, 7};

    a := int.[1, 2, 3, 
    4, 5, 
    6, 7];
}
DONE

literal_end_on_new_line_exact :: () -> Test_Parameters
{
    using result: Test_Parameters;
    config.alignment_mode = .EXACT;
    config.multiline_struct_literal_end_on_new_line = true;
    config.multiline_array_literal_end_on_new_line = true;
    source_code = ALIGN3;
    expected_output = #string DONE
test :: () {
    a := Struct.{1, 2, 3,
                 4, 5,
                 6, 7
                };

    a := int.[1, 2, 3,
              4, 5,
              6, 7
             ];
}
DONE;

    return result;
} @Test

literal_end_on_new_line_indent :: () -> Test_Parameters
{
    using result: Test_Parameters;
    config.alignment_mode = .INDENT_ONLY;
    config.multiline_struct_literal_end_on_new_line = true;
    config.multiline_array_literal_end_on_new_line = true;
    source_code = ALIGN3;
    expected_output = #string DONE
test :: () {
    a := Struct.{1, 2, 3,
        4, 5,
        6, 7
    };

    a := int.[1, 2, 3,
        4, 5,
        6, 7
    ];
}
DONE;

    return result;
} @Test

literal_end_not_on_new_line:: () -> Test_Parameters
{
    using result: Test_Parameters;
    config.alignment_mode = .INDENT_ONLY;
    config.multiline_struct_literal_end_on_new_line = false;
    config.multiline_array_literal_end_on_new_line = false;
    source_code = ALIGN3;
    expected_output = #string DONE
test :: () {
    a := Struct.{1, 2, 3,
        4, 5,
        6, 7};

    a := int.[1, 2, 3,
        4, 5,
        6, 7];
}
DONE;

    return result;
} @Test
