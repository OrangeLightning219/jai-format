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
DONE;

    return result;
} @Test

COMMENTS_WHITESPACE :: #string DONE
test :: () {
    print("asd");    // comment 1
    print("asdzxc"); // comment 2
    print("asd");    // comment 3
    a := 1 + 2;      // comment 4 

    print("asd");    // comment 5
    print("asdzxc");// comment 6
    print("asd");  // comment 7
    a := 1 + 2;   // comment 8 

        print("asd");      // comment 9
print("asd");      // comment 10
    print("asd");      // comment 11
    print( "asd" );    // comment 12
}
DONE

comments_whitespace :: () -> Test_Parameters
{
    using result: Test_Parameters;
    source_code = COMMENTS_WHITESPACE;
    config.keep_whitespace_before_single_line_comments = true;
    expected_output = #string DONE
test :: () {
    print("asd");    // comment 1
    print("asdzxc"); // comment 2
    print("asd");    // comment 3
    a := 1 + 2;      // comment 4 

    print("asd");    // comment 5
    print("asdzxc");// comment 6
    print("asd");  // comment 7
    a := 1 + 2;   // comment 8 

    print("asd");      // comment 9
    print("asd");      // comment 10
    print("asd");      // comment 11
    print("asd");    // comment 12
}
DONE;

    return result;
} @Test
