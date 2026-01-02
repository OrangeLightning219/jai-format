Union_Tag :: enum
{
    A;
    B;
    C;
}

Test_Union :: union tag: Union_Tag {
    a: int;
    b: float;
    c: string;
}

Test_Union :: union tag: enum {
    A;
    B;
    C;
}
{
    a: int;
    b: float;
    c: string;
}

Test_Union :: union @TestNote tag: enum @Note {
    A;
    B;
    C;
} @Note
{
    a: int;
    b: float;
    c: string;
} @Note

test :: ()
{
    a := cast(f32) 5;
}
