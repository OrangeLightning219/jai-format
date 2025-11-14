WHILE :: #string DONE
test :: () {
    while true print("true");
    while a + 4 >= b - 2 print("true");
    while true {print("true");}
    while true {print("true");
    }

    while true {
        print("true");}
    while true 
    {print("true");}

    while (a + b) * 0.5 > 0 
    {
        print("true");
    }
}
DONE

while_loops :: () -> Test_Parameters
{
    using result: Test_Parameters;
    source_code = WHILE;
    expected_output = #string DONE
test :: () {
    while true print("true");
    while a + 4 >= b - 2 print("true");
    while true {print("true");}
    while true {
        print("true");
    }

    while true {
        print("true");
    }
    while true {print("true");}

    while (a + b) * 0.5 > 0 {
        print("true");
    }
}
DONE;

    return result;
} @Test

FOR :: #string DONE
test :: () {

    for things print(it);
    for things {print(it);}
    for things {print(it);
    }

    for *things print(it);
    for *<things print(it);

    for things 
    {print(it);
    }

    for value,index:things
    {
        a := value + index;
    }

    DO_POINTER :: true;
    DO_REVERSE :: true;

    for *=DO_POINTER things print(it);
    for *=DO_POINTER, <=DO_REVERSE things print(it);
    for <=DO_REVERSE,*=DO_POINTER   things print(it);
}
DONE

for_loops :: () -> Test_Parameters
{
    using result: Test_Parameters;
    source_code = FOR;
    expected_output = #string DONE
test :: () {
    for things print(it);
    for things {print(it);}
    for things {
        print(it);
    }

    for *things print(it);
    for <*things print(it);

    for things {
        print(it);
    }

    for value, index: things {
        a := value + index;
    }

    DO_POINTER :: true;
    DO_REVERSE :: true;

    for *= DO_POINTER things print(it);
    for <= DO_REVERSE, *= DO_POINTER things print(it);
    for <= DO_REVERSE, *= DO_POINTER things print(it);
}
DONE;

    return result;
} @Test

SWITCH :: #string DONE
test :: () {
    if x == {
        case .TEST1;
        print("asdasd");
        if a > b {
            if z == {
                case 1; print("asd"); return b;
                case 2; 
                    return a;
                case 3; return c;
                case 4; 



            a += b; c -= z; b *= x; return c;

            }
        }
    case .TEST2;
    if a == 
    {

    }
    case;
            print("asdasd");
        print("asdasd");
    print("asdasd");
    }
}
DONE

switch_statements :: () -> Test_Parameters
{
    using result: Test_Parameters;
    source_code = SWITCH;
    expected_output = #string DONE
test :: () {
    if x == {
    case .TEST1;
        print("asdasd");
        if a > b {
            if z == {
            case 1; print("asd"); return b;
            case 2;
                return a;
            case 3; return c;
            case 4;
                a += b; c -= z; b *= x; return c;
            }
        }
    case .TEST2;
        if a == {
        }
    case;
        print("asdasd");
        print("asdasd");
        print("asdasd");
    }
}
DONE;

    return result;
} @Test

IF :: #string DONE
test :: () {
    if a > b {
        print("true");
    } 
    else {
        print("false");
    }

    if a then b += a; else c *= a;
    if a b += a; else c *= a;
    if a 

        b; 
    else 
        c;

    if a     b; 
    else c;
}
DONE

if_statements :: () -> Test_Parameters
{
    using result: Test_Parameters;
    source_code = IF;
    expected_output = #string DONE
test :: () {
    if a > b {
        print("true");
    } else {
        print("false");
    }

    if a then b += a; else c *= a;
    if a b += a; else c *= a;
    if a
        b;
    else
        c;

    if a b;
    else c;
}
DONE;

    return result;
} @Test

IFX :: #string DONE
test :: () {
    a := ifx true then 5 else 0;
    a := ifx true 5 else 0;
    a := ifx true 5 
    else 0;

    b := ifx a else 6;
    b := ifx a 
    else 6;

    b := ifx a then {

        print("asd");
        a;
    } else {
        print("zxc");


        6;
    }

    c := ifx b > 0 else 8;
}
DONE

ifx_statements :: () -> Test_Parameters
{
    using result: Test_Parameters;
    source_code = IFX;
    expected_output = #string DONE
test :: () {
    a := ifx true then 5 else 0;
    a := ifx true 5 else 0;
    a := ifx true 5
         else 0;

    b := ifx a else 6;
    b := ifx a
         else 6;

    b := ifx a then {
        print("asd");
        a;
    } else {
        print("zxc");

        6;
    };

    c := ifx b > 0 else 8;
}
DONE;

    return result;
} @Test

BRACES :: #string DONE
test :: () {
    if a > b {
        print("true");
    } 
    else {
        print("false");
    }

    if a then b += a; else c *= a;
    if a b += a; else c *= a;
    if a 

        b; 
    else 
        c;

    if a     b; 
    else c;

    if a {
        b; 
    }
    else c;

    for things print(it);
    for things 
        print(it);

    for things {print(it);}
    for things {
        print(it);
    }

    while true print("true");
    while true 
        print("true");

    while true {print("true");}
    while true 
    {print("true");}
}
DONE

force_add_braces :: () -> Test_Parameters
{
    using result: Test_Parameters;
    config.single_statement_brace_mode = .FORCE_ADD;
    source_code = BRACES;
    expected_output = #string DONE
test :: () {
    if a > b {
        print("true");
    } else {
        print("false");
    }

    if a then b += a; else c *= a;
    if a {b += a;} else {c *= a;}
    if a {
        b;
    } else {
        c;
    }

    if a {b;}
    else {c;}

    if a {
        b;
    } else {c;}

    for things {print(it);}
    for things {
        print(it);
    }

    for things {print(it);}
    for things {
        print(it);
    }

    while true {print("true");}
    while true {
        print("true");
    }

    while true {print("true");}
    while true {print("true");}
}
DONE;

    return result;
} @Test

BRACES1 :: #string DONE
test :: () {
    if a > b {
        print("true");
    } 
    else {
        print("false");
        print("false");
    }

    if a then b += a; else c *= a;
    if a {b += a;} else {c *= a;}
    if a {

        b; 
    }
    else { c; }

    if a    {b;} 
    else {c;}

    for things {print(it);}
    for things {
        print(it);
    }

    while true {print("true");}
    while true 
    {print("true");}
}
DONE

force_remove_braces :: () -> Test_Parameters
{
    using result: Test_Parameters;
    config.single_statement_brace_mode = .FORCE_REMOVE;
    source_code = BRACES1;
    expected_output = #string DONE
test :: () {
    if a > b
        print("true");
    else {
        print("false");
        print("false");
    }

    if a then b += a; else c *= a;
    if a b += a; else c *= a;
    if a
        b;
    else c;

    if a b;
    else c;

    for things print(it);
    for things
        print(it);

    while true print("true");
    while true
        print("true");
}
DONE;

    return result;
} @Test

NEW_LINES :: #string DONE
test :: () {
    if a > b {
        print("true");
    } 
    else {
        print("false");
    }

    if a then b += a; else c *= a;
    if a b += a; else c *= a;
    if a 

        b; 
    else 
        c;

    if a     b; 
    else c;

    if a {b}; 
    else {c};

    if a {
        b; 
    }
    else c;

    for things print(it);
    for things 
        print(it);

    while true print(it);
    while true 
        print(it);
}
DONE

force_new_line :: () -> Test_Parameters
{
    using result: Test_Parameters;
    config.single_statement_line_mode = .NEW_LINE;
    source_code = NEW_LINES;
    expected_output = #string DONE
test :: () {
    if a > b {
        print("true");
    } else {
        print("false");
    }

    if a then b += a; else c *= a;
    if a
        b += a;
    else
        c *= a;
    if a
        b;
    else
        c;

    if a
        b;
    else
        c;

    if a {b;}
    else {c;}

    if a {
        b;
    } else
        c;

    for things
        print(it);
    for things
        print(it);

    while true
        print(it);
    while true
        print(it);
}
DONE;

    return result;
} @Test

NEW_LINES1 :: #string DONE
test :: () {
    if a > b {
        print("true");
    } else {
        print("false");
    }

    if a then b += a; else c *= a;
    if a
        b += a;
    else
        c *= a;
    if a
        b;
    else
        c;

    if a
        b;
    else
        c;

    if a {b;}
    else {c;}

    if a {
        b;
    } else
        c;

    for things print(it);
    for things 
        print(it);

    while true print(it);
    while true 
        print(it);
}
DONE;

remove_new_line :: () -> Test_Parameters
{
    using result: Test_Parameters;
    config.single_statement_line_mode = .SAME_LINE;
    source_code = NEW_LINES1;
    expected_output = #string DONE
test :: () {
    if a > b {
        print("true");
    } else {
        print("false");
    }

    if a then b += a; else c *= a;
    if a b += a;
    else c *= a;
    if a b;
    else c;

    if a b;
    else c;

    if a {b;}
    else {c;}

    if a {
        b;
    } else c;

    for things print(it);
    for things print(it);

    while true print(it);
    while true print(it);
}
DONE;

    return result;
} @Test

DOUBLE_SPACE:: #string DONE
test :: () {
    if a b += a;
    else c *= a;

    for things print(it);

    while true print(it);
}
DONE;

double_space :: () -> Test_Parameters
{
    using result: Test_Parameters;
    config.single_statement_double_space = true;
    source_code = DOUBLE_SPACE;
    expected_output = #string DONE
test :: () {
    if a  b += a;
    else  c *= a;

    for things  print(it);

    while true  print(it);
}
DONE;

    return result;
} @Test
