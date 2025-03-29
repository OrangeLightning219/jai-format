test :: ()
{
    add_shader :: () #expand
    {
        array_add( *shaders, .{ file, ifx name else file, pixel, vertex, compute } );
        shaders: [ .. ]Shader;
    }
}
