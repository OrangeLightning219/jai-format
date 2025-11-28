Matrix3_Float16 :: struct {
    _11, _12, _13: Float16;
    _21, _22, _23: Float16;
    _31, _32, _33: Float16;

    #overlay (_11) floats: [9] Float16;  // 'floats' is a little misleading, but this is what the member is called in Matrix3.
}
