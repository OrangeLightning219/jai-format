State :: struct
{
    update: ( float ) = ( dt: float ) {};
    draw: () = () {};

    test: struct {
        a: int;
    } = .{1};

     a := struct {
         b: int;
     };

     a : struct {
         b: int;
     };
}

test :: ()
{
    a := make_struct(.{1, 2, 3});

    a: *#run get_type();
    a: [4]#insert "int;";
}
