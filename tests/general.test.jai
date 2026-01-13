// NOTE: Use scope_file here so that we can reuse varaible names in different files
#scope_file
SOURCE :: #string DONE
test :: (a: int, b: float) -> bool{
    print("test\n");
    c := (a + b).(float) * 0.5;
    c := cast(float)(a + b) * 0.5;

    if (c > 0.1 && c < 0.5) || (c > 0.6 && c < 1.0) {
        return false;
    }
    else {
        return test(a, test(c, 0));
    }
}
DONE

SOURCE_2 :: #string DONE
test :: ()
{
    s: Struct = .{1, 2, "asd", 0.5, test()};
    s:= Struct.{1, 2, "asd", 0.5, test()};
    list: [..]int = .[1, 2, 3, 4, 5];
    list: = int.[1, 2, 3, 4, 5];

    list_2d := int.[    int.[1, 2, 3],
        int.[2, 3, 4],
        int.[3, 4, 5],
    ];

    a := list[0] + list[3];
    b := list2d[0][2];
}
DONE

ERRORS :: #string DONE
test :: ()
{
    for value, 2: things {}
}
DONE

#scope_export

empty_test :: () -> Test_Parameters
{
    using result: Test_Parameters;
    source_code = "";
    expected_output = "";
    expected_result = .ERROR;
    return result;
} @Test

stop_on_syntax_error :: () -> Test_Parameters
{
    using result: Test_Parameters;
    source_code = ERRORS;
    expected_output = "";
    expected_result = .ERROR;
    return result;
} @Test

spaces_inside_brackets_and_literals :: () -> Test_Parameters
{
    using result: Test_Parameters;
    config.spaces_inside_brackets = true;
    config.spaces_inside_literals = true;
    source_code = SOURCE_2;
    expected_output = #string DONE
test :: () {
    s: Struct = .{ 1, 2, "asd", 0.5, test() };
    s := Struct.{ 1, 2, "asd", 0.5, test() };
    list: [ .. ]int = .[ 1, 2, 3, 4, 5 ];
    list := int.[ 1, 2, 3, 4, 5 ];

    list_2d := int.[ int.[ 1, 2, 3 ],
                     int.[ 2, 3, 4 ],
                     int.[ 3, 4, 5 ] ];

    a := list[ 0 ] + list[ 3 ];
    b := list2d[ 0 ][ 2 ];
}
DONE;

    return result;
} @Test

braces_on_new_line :: () -> Test_Parameters
{
    using result: Test_Parameters;
    config.braces_on_new_line = true;
    config.else_on_new_line = true;
    source_code = SOURCE;
    expected_output = #string DONE
test :: (a: int, b: float) -> bool
{
    print("test\n");
    c := (a + b).(float) * 0.5;
    c := cast(float)(a + b) * 0.5;

    if (c > 0.1 && c < 0.5) || (c > 0.6 && c < 1.0)
    {
        return false;
    }
    else
    {
        return test(a, test(c, 0));
    }
}
DONE;

    return result;
} @Test

spaces_around_operators :: () -> Test_Parameters
{
    using result: Test_Parameters;
    config.spaces_around_operators = false;
    source_code = SOURCE;
    expected_output = #string DONE
test::(a: int, b: float) -> bool {
    print("test\n");
    c:=(a+b).(float)*0.5;
    c:=cast(float)(a+b)*0.5;

    if (c>0.1&&c<0.5)||(c>0.6&&c<1.0) {
        return false;
    } else {
        return test(a, test(c, 0));
    }
}
DONE;

    return result;
} @Test

spaces_inside_parens :: () -> Test_Parameters
{
    using result: Test_Parameters;
    config.spaces_inside_parens = true;
    source_code = SOURCE;
    expected_output = #string DONE
test :: ( a: int, b: float ) -> bool {
    print( "test\n" );
    c := ( a + b ).( float ) * 0.5;
    c := cast( float )( a + b ) * 0.5;

    if ( c > 0.1 && c < 0.5 ) || ( c > 0.6 && c < 1.0 ) {
        return false;
    } else {
        return test( a, test( c, 0 ) );
    }
}
DONE;

    return result;
} @Test

STRUCT_LITERALS :: #string DONE
test :: () {
    a := Struct.{1, 2, 3};
    a := make_struct(.{1, 2, 3});
    a := make_struct({1, 2, 3});
}
DONE

struct_literals_force_dot :: () -> Test_Parameters
{
    using result: Test_Parameters;
    config.struct_literal_dot_mode = .FORCE;
    source_code = STRUCT_LITERALS;
    expected_output = #string DONE
test :: () {
    a := Struct.{1, 2, 3};
    a := make_struct(.{1, 2, 3});
    a := make_struct(.{1, 2, 3});
}
DONE;

    return result;
} @Test

struct_literals_remove_dot :: () -> Test_Parameters
{
    using result: Test_Parameters;
    config.struct_literal_dot_mode = .REMOVE;
    source_code = STRUCT_LITERALS;
    expected_output = #string DONE
test :: () {
    a := Struct.{1, 2, 3};
    a := make_struct({1, 2, 3});
    a := make_struct({1, 2, 3});
}
DONE;

    return result;
} @Test

WEIRD_STUFF :: #string DONE
test :: () {
    a: *[3]**[2]#run get_type();

    a: **[3]*[2]*#run -> Type
    {
        return A;
    }
}
DONE

weird_stuff :: () -> Test_Parameters
{
    using result: Test_Parameters;
    source_code = WEIRD_STUFF;
    expected_output = #string DONE
test :: () {
    a: *[3]**[2]#run get_type();

    a: **[3]*[2]*#run -> Type {
        return A;
    }
}
DONE;

    return result;
} @Test
