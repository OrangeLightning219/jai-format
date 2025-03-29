test :: ()
{
    add_shader :: () #expand
    {
        array_add( *shaders, .{ file, ifx name else file, pixel, vertex, compute } );
        shaders: [ .. ]Shader;
    }

    #if #exists( TEST )
    {
    }

    test :: struct
    {
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
