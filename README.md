# jai-format
Simple code formatter for jai.

## Building
To build the formatter simply run `jai ./first.jai`. This will create the `jai-format.exe` in the `build` folder.

## Usage
To format a file run `jai-format path/to/your/file.jai`. You can format multiple files by passing a space separated list of paths as arguments: `jai-format file1.jai path/to/second/file.jai file3.jai`.

## Configuration
There are only 7 configuration options:

* `space_after_comma` - `bool` - if true a space will be inserted after each comma. There are two exceptions for this rule: 
  `cast` and directives. For example a space won't be inserted in `cast,no_check` or `#string,cr`.
* `spaces_inside_parens` - `bool` - if true a space will be inserted after `(` and before `)` if there is something between them.
* `spaces_inside_brackets` - `bool` - if true a space will be inserted after `[` and before `]` if there is something between them.
* `spaces_inside_struct_literals` - `bool` - if true a space will be inserted after '{' and before `}` but only in struct literals.
* `spaces_around_operators` - `bool` - if true spaces will be inserted around binary operators.
* `max_empty_lines_to_keep` - `int` - maximum amount of empty lines that will be kept when formatting.
* `indent_width` - `int` - amount of spaces to use as indentation.

To change the configuration create a `.jai-format` file in the working directory of the formatter and put your options there. 
Options should be formatted like this: `option_name = option_value`. Each option should be in a separate line.

Another way of changing the configuration is changing the default values in the `Formatter_Config` struct in `main.jai`. 
This allows having a custom global configuration without the need for the `.jai-format` file.

## Limitations
* `if`, `for`, `while` without braces are not supported for now. For example this: `if condition do_something();` will not work and 
  will become `if conditiondo_something();` This should probably be fixed but for now you can work around this by adding braces: `if condition { do_something(); }`.
* The formatter won't change the braces placement - this allows having things like this: `if condition { foo(); bar(); }` without adding unnecessary complexity to the code.
* Parameters, arguments, conditions, assignments will always be aligned. For example this:
```
if condition1 && (condition2 || condition3
    condition4 ||
    condition5) &&
    condition6
   {       
   }
```
will become this:
```
if condition1 && (condition2 || condition3
                  condition4 ||
                  condition5) &&
   condition6
   {       
   }
```
Note: The alignement only happens if there are new lines in the statements. The formatter will not insert new lines on its own.
* Variable alignment is not supported. This:
```
a                       := 5;
some_long_variable_name := 6;
test                    := "asd";
```
will become this:

```
a := 5;
some_long_variable_name := 6;
test := "asd";
```
* `case` statements are indented to the same level as `if`:
```
if a ==
{
case 1;
    foo();
case 2;
    bar();
}
```
This will probably be changed in the future because I don't like this style of `if case` formatting.
