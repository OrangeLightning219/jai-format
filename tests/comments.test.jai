COMMENTS :: #string DONE
test :/*asd*/: (param/*asd*/: int) /*zxc*/ -> /*asd*/ int
{
    /*`max_buffer_size = new_size;*/
    a: /*zxc*/ int;

    a, /*int*/b= := 1, /*int*/2;

    // a := b; // test
    a := b; //test
}
// test

/*
 some long explanation 
 some long explanation 
 some long explanation 
 some long explanation 
 some long explanation 
 some long explanation 
 some long explanation 
 some long explanation 
 some long explanation 
 some long explanation 
 some long explanation 
 some long explanation 
*/
asd :: #run,/*asdasd*/host -> string {
    return "asd";
}
// comments at end of file



/*
another explanation
another explanation
another explanation
another explanation
another explanation
*/
DONE

comments :: () -> Test_Parameters
{
    using result: Test_Parameters;
    source_code = COMMENTS;
    expected_output = #string DONE
test :: /*asd*/(param: /*asd*/int) -> /*zxc*//*asd*/int {
    /*`max_buffer_size = new_size;*/
    a: /*zxc*/int;

    a:, /*int*/b = 1, /*int*/2;

    // a := b; // test
    a := b; // test
}
// test

/*
 some long explanation 
 some long explanation 
 some long explanation 
 some long explanation 
 some long explanation 
 some long explanation 
 some long explanation 
 some long explanation 
 some long explanation 
 some long explanation 
 some long explanation 
 some long explanation 
*/
asd :: #run,host -> /*asdasd*/string {
    return "asd";
}
// comments at end of file

/*
another explanation
another explanation
another explanation
another explanation
another explanation
*/
DONE
    return result;

} @Test

