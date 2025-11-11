# jai-format
Simple code formatter for jai.

## Building
To build the formatter simply run `jai ./first.jai - release`. This will create the `jai-format.exe` in the `build` folder.

## Usage
To format a file run `jai-format path/to/your/file.jai`. You can format multiple files by passing a space separated list of paths as arguments: `jai-format file1.jai ./path/to/folder file3.jai`. If a folder is passed as an argument all `.jai` files will be formated in that folder.

There are some CLI parameters you can use to alter the default behaviour:
- `-config_file`: default = "./.jai-format"\
    Path to a config file that should be used. If not set the formatter will search the current working directory for a .jai-format file. If no config is found the default config will be used.

- `-recursive`: default = false\
    If set and there are directories in the argument list all directories will be formatted recursively.

- `-silent`: default = false\
    If set no output will be printed other than the final result if -to_stdout is also set.

- `-to_file`: default = false\
    If set the source file will be overwritten with the new formatted output.

- `-to_stdout`: default = false\
    If set the formatted output will be printed to standard out.

- `-verbose`: default = false\
    If set more output information will be printed.

- `-help`, `-HELP`, `-?`: Show the list of commands.

Example usage with some parameters: `jai-format -silent -to_stdout -to_file file.jai`.

You can also use the formatter as a module by directly using the `format_file`, and `format_from_string` functions.
For example: 
```jai
    config := load_config(config_file);
    // make_formatter allocates the result buffer and an indentation string using whatever allocator is currently set in context.allocator
    // In addition to that it also creates it's own Flat_Pool for other allocations needed during formatting
    formatter := make_formatter( config );

    status, output := format_file(*formatter, some_file);
    // do something with the output
    reset_formatter(*formatter); // After this the output is no longer valid. This only resets the Flat_Pool, it doesn't free the memory.

    status, output = format_from_string(*formatter, some_code_string);
    // do something with the output
    reset_formatter(*formatter);

    // If you care about freeing all the memory call deinit_formatter
    deinit_formatter(*formatter);
```

## Configuration
- spaces_inside_parens: default = false\
    If true a space will be inserted after `(` and before `)` if there is something between them.

```
    true:                           false:
        print( "%\n", "test" );         print("%\n", "test");
```

- spaces_inside_brackets: default = false\
    If true a space will be inserted after `[` and before `]` in array subscripts. This option doesn't insert spaces inside array literals.

```
    true:                           false:
        a := array[ 0 ];                a := array[0];
```

- spaces_inside_literals: default = false\
    If true a space will be inserted inside struct and array literals. 

```
    true:                           false:
        a := Struct.{ 1, 2, 3 };        a := Struct.{1, 2, 3};
        b := int.[ 1, 2, 3 ];           b := int.[1, 2, 3];
```

- spaces_around_operators: default = true\
    If true spaces will be inserted around binary operators.

```
    true:                           false:
        a := 1 + 2;                     a:=1+2;
```

- wrap_before_operators: default = false\
    If true a new line will be inserted before the operator in a multiline expression.
```
    true:                           false:
        if a                            if a ||
           || b                            b ||
           || c                            c
```

- alignment_mode: default = EXACT\
    Specifies how to align expressions after line breaks.\
    Things that will be aligned are:
    - Declarations and assignments (`:=`, `::`, `=`)
    - Everything surrounded with `()`, `[]` or `{}`
    - Expressions after `if`, `while` and `for`
    
    Alowed values are:
    - `DISABLED` - no alignment
    - `INDENT_ONLY` - use `indent_width` as alignment
    - `EXACT` - exactly align expressions with their start point

    For more alignment examples see `tests/alignment.test.jai`.
```
    DISABLED:                           INDENT_ONLY:                           EXACT:
        test(a, b, c,                       test(a, b, c,                          test(a, b, c, 
        d(a, b,                                 d(a, b,                                 d(a, b,
        c), e);                                     c), e);                               c), e);
```

- alignment mode overrides:\
    You can override the alignment_mode for specific things:
    - declaration_alignment_mode - alignment for declarations and assignments (`:=`, `::`, `=`)
    - expression_alignment_mode - alignment for expressions after `if`, `while` and `for` etc.
    - parens_alignment_mode - alignment for things surrounded with `()`
    - brackets_alignment_mode - alignment for things surrounded with `[]` 
    - struct_literal_alignment_mode - alignment for struct literals (`.{}`)

    If any of these options are not set then the value of `alignment_mode` will be used.

- single_statement_brace_mode: default = DONT_MODIFY\
    Specifies wheter to keep, add or remove braces to single statements in control flow expressions (`if`, `for`, `while`).
    
    Alowed values are:
    - `DONT_MODIFY` - don't modify the braces
    - `FORCE_ADD` - always add braces to single line statements
    - `FORCE_REMOVE` - always remove braces from single line statements
    
```
    DONT_MODIFY:                           FORCE_ADD:                           FORCE_REMOVE:
        if condition {                         if condition {                       if condition
            print("true");                         print("true");                       print("true");
        } else                                 } else {                             else
            print("false");                        print("false");                      print("false");
                                               }
```

- braces_on_new_line: default = false\
    If true opening braces will be put on a new line.\
    There is one exception to this option. If a opening and closing braces are on the same line the block will be kept as is.\
    For example `if true {print("true");}` will remain all on one line.

```
    true:                           false:
        if true                         if true {
        {                               }
        }
```

- quick_lambda_brace_on_new_line: default = false\
    If true the opening brace of a quick lambda will be placed on a new line.\
    This setting also applies to `#code` blocks.\
    This option ignores the braces_on_new_line option.

```
    true:                           false:
        a :: (x, y) =>                  a :: (x, y) => {
        {                               }
        }
```

- else_on_new_line: default = false\
    If true the else keyword will be placed on a new line after the closing brace.

```
    true:                           false:
        if true {                       if true {
        }                               } else {
        else {                          }
        }
```

- indent_case: default = false\
    If true case statements will be indented one level instead of staying at the same indentation level as the if keyword.

```
    true:                           false:
        if a == {                       if a == {
            case 1;                     case 1;
            case;                       case;
        }                               }
```

- surround_multiple_returns_with_parens: default = false\
    If true multiple returns will always be surrounded with parenthesis.\
    If this option is set to false the formatter will not remove the parenthesis that are already there.

```
    true:                           false:
        a :: () -> (int, bool)          a :: ()  -> int, bool
```
- insert_space_in_single_line_comments: default = true\
    If true a space will be added after the // if there isn't already one.\
    The formatter will not trim the leading whitespace in the comments.

```
    true:                           false:
        // comment                      //comment
```
- max_empty_lines_to_keep: default = 1\
    Maximum amount of empty lines that will be kept when formatting.\
    Empty lines at the beginning of a scope will be removed regardless of what this option is set to.\
    For example:
```
    if true {                           if true {
                                            print("true");
        print("true");    --------->    }
    }
```

- indent_mode : default = SPACES\
    What character to use for indentation. Either `SPACES` or `TABS`.

- indent_width: default = 4\
    Amount of spaces or tabs to use as indentation.

- tab_width: default = 4\
    Set this to the tab width you use in your editor. This option is only used for `EXACT` alignment mode to allow precise alignment by mixing tabs and spaces.\
    For example:
```
____if ( a > 1 && a < 5 ) ||
____...( a > 8 && a < 10 )
^    ^
tab  spaces
```

- no_carriage_return_on_windows: default = false\
    If true only `\n` will be used as a line ending instead of `\r\n` on windows.


To change the configuration create a `.jai-format` file in the working directory of the formatter and put your options there. 
Options should be formatted like this: `option_name option_value`. You can use `#` to comment out lines in the config. See the `.jai-format` file in this repo for an exaxmple configuration.

## Runing the tests
There are some automated tests that check the correctness of the formatted output. To run them just run `jai first.jai - test`.

## Limitations
- The biggest limitation right now is that the formatter assumes there are no syntax errors in your code. If you try formatting a file that has syntax errors it may or may not work properly. This is not a big issue if you're using the formatter directly in an editor because even if something goes wrong you can easily undo the changes. But when using the formatter as a cli tool with the `-to_file` parameter proceed with caution.
- Comments in weird places will be rearranged. For example:\
`test :/*asd*/: (param/*asd*/: int) /*zxc*/ -> /*asd*/ int`\
will be formatted as:\
`test :: /*asd*/(param: /*asd*/int) -> /*zxc*//*asd*/int`

## Neovim setup
### If using conform.nvim
Add this to your conform setup:
```lua
local conform_util = require("conform.util")
require("conform").setup({ 
    formatters_by_ft = { 
        jai   = { "jai-format" }, 
    },
    formatters = {
        ["jai-format"] = {
            command = "jai-format",
            args = { "-silent", "-to_file", "$FILENAME" },
            cwd = conform_util.root_file({ ".jai-format" }),
            stdin = false,
        },
    }
})
```
### Without a formatter plugin
You can run the `jai-format` command manually:
```lua
local function jai_format()
    local job = require("plenary.job")
    local current_file = vim.fn.expand("%:p")
    job:new({
        command = "jai-format",
        args = { "-to_file", current_file },
        cwd = vim.fn.getcwd(),
        on_exit = function(j, return_val)
            local callback = vim.schedule_wrap(function(file) 
                vim.api.nvim_command("checktime " .. file)
            end)
            callback(current_file)
        end,
    }):start()
end

vim.api.nvim_create_user_command("JaiFormat", jai_format, {nargs = 0, desc = ""})
```
After adding this to your config you can run `:JaiFormat` to format the current buffer or you can setup an autocommand to format on save:
```lua
local autocommand_group = vim.api.nvim_create_augroup('auto_commands', {})
vim.api.nvim_create_autocmd({"BufWritePost"}, {
    command = "JaiFormat",
    group = autocommand_group,
    pattern = {"*.jai"}
})
```

## What's left to do (in order of importance)
- Write more tests
- Don't format if there are syntax errors. This relies on the jai_parser module checking for syntax errors which it currently doesn't.
- Add `//jai-format:off` and `//jai-format:on` comments that allow disabling the formatter in specific places.
- Add `//jai-format:config_option=true` comments that allow overriding configuration options in specific places.
