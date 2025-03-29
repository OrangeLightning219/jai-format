DECLARATIONS :: #string DONE
test :: () {
    a: int;
    a: []int;
    a: Struct.Kind;
    a: Struct.Kind.Kind2;
    a: #run -> Type {return int;};
    a: #insert -> string {return "int;";}

    a: int = 5;
    a: []int = 5;
    a: Struct.Kind = 5;
    a: Struct.Kind.Kind2 = 5;
    a: #run -> Type {return int;} = 5;
    a: #insert -> string {return "int;";} = 5;

    a: int : 5;
    a: []int : 5;
    a: Struct.Kind : 5;
    a: Struct.Kind.Kind2 : 5;
    a: #run -> Type {return int;} : 5;
    a: #insert -> string {return "int;";} : 5;

    a := 5;
    a :: 5;

    a: []int = .[1, 2, 3, 4, 5];
    a: [..]int = .[1, 2, 3, 4, 5];
    a: [5]int = .[1, 2, 3, 4, 5];
    a: [Struct.SIZE]int = .[1, 2, 3, 4, 5];
    a := int.[1, 2, 3, 4, 5];

    a: []int : .[1, 2, 3, 4, 5];
    a: [..]int : .[1, 2, 3, 4, 5];
    a: [5]int : .[1, 2, 3, 4, 5];
    a: [Struct.SIZE]int : .[1, 2, 3, 4, 5];
    a :: int.[1, 2, 3, 4, 5];

    a: #run get_type();
    a: #insert "int;";

    a: *int;
    a: *[]int;
    a: *[]*int;
    a: *Struct.Kind;
    a: *Struct.Kind.Kind2;
    a: *#run -> Type {return int;};
    a: *#insert -> string {return "int;";}

    a: #insert -> string {
        result: string = get_type();
        return result;
    }

    a: #run -> Type {
        result: Type = get_type();
        return result;
    }

    test :: struct {
        a: struct {
            b: int;
            c: float;
        }

        a: union {
            b: int;
            c: float;
        }

        a: enum {
            A :: 2;
            B;
        }
    }
}
DONE

declarations :: () -> Test_Parameters
{
    using result: Test_Parameters;
    source_code = DECLARATIONS;
    expected_output = #string DONE
test :: () {
    a: int;
    a: []int;
    a: Struct.Kind;
    a: Struct.Kind.Kind2;
    a: #run -> Type {return int;}
    a: #insert -> string {return "int;";}

    a: int = 5;
    a: []int = 5;
    a: Struct.Kind = 5;
    a: Struct.Kind.Kind2 = 5;
    a: #run -> Type {return int;} = 5;
    a: #insert -> string {return "int;";} = 5;

    a: int: 5;
    a: []int: 5;
    a: Struct.Kind: 5;
    a: Struct.Kind.Kind2: 5;
    a: #run -> Type {return int;}: 5;
    a: #insert -> string {return "int;";}: 5;

    a := 5;
    a :: 5;

    a: []int = .[1, 2, 3, 4, 5];
    a: [..]int = .[1, 2, 3, 4, 5];
    a: [5]int = .[1, 2, 3, 4, 5];
    a: [Struct.SIZE]int = .[1, 2, 3, 4, 5];
    a := int.[1, 2, 3, 4, 5];

    a: []int: .[1, 2, 3, 4, 5];
    a: [..]int: .[1, 2, 3, 4, 5];
    a: [5]int: .[1, 2, 3, 4, 5];
    a: [Struct.SIZE]int: .[1, 2, 3, 4, 5];
    a :: int.[1, 2, 3, 4, 5];

    a: #run get_type();
    a: #insert "int;";

    a: *int;
    a: *[]int;
    a: *[]*int;
    a: *Struct.Kind;
    a: *Struct.Kind.Kind2;
    a: *#run -> Type {return int;}
    a: *#insert -> string {return "int;";}

    a: #insert -> string {
        result: string = get_type();
        return result;
    }

    a: #run -> Type {
        result: Type = get_type();
        return result;
    }

    test :: struct {
        a: struct {
            b: int;
            c: float;
        }

        a: union {
            b: int;
            c: float;
        }

        a: enum {
            A :: 2;
            B;
        }
    }
}
DONE;

    return result;
} @Test

COMPOUND :: #string DONE
test :: () {
    ok, group_name, rest := split_from_left(it.file, #char ".");

    a, b, c = 1, 2, 3;
    a, b, c := 1, 2, 3;
    a=, b, c= := 1, 2, 3;
    a:, b:, c = 1, 2, 3;

    a, b, c = test(1, 2, x.y);
    a, b, c := test(1, 2, x.y);
    a=, b, c= := test(1, 2, x.y);
    a:, b:, c = test(1, 2, x.y);

    a, b, c: int = 1, 2, 3;
    a, b, c: int = test(1, 2, 3);
}
DONE

compound_declarations :: () -> Test_Parameters
{
    using result: Test_Parameters;
    source_code = COMPOUND;
    expected_output = #string DONE
test :: () {
    ok, group_name, rest := split_from_left(it.file, #char ".");

    a, b, c = 1, 2, 3;
    a, b, c := 1, 2, 3;
    a, b:, c = 1, 2, 3;
    a:, b:, c = 1, 2, 3;

    a, b, c = test(1, 2, x.y);
    a, b, c := test(1, 2, x.y);
    a, b:, c = test(1, 2, x.y);
    a:, b:, c = test(1, 2, x.y);

    a, b, c: int = 1, 2, 3;
    a, b, c: int = test(1, 2, 3);
}
DONE;

    return result;
} @Test
