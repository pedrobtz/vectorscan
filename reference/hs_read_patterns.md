# Read a Hyperscan pattern file

Reads patterns in the format of Hyperscan's own tools (`hsbench`,
`hscollider`, `simplegrep`'s signature files): one pattern per line,
written `id:/regex/flags`, optionally followed by extended parameters in
braces. The result is a rules data frame that
[`hs_compile()`](https://pedrobtz.github.io/vectorscan/reference/hs_compile.md)
and the verbs take as they are.

## Usage

``` r
hs_read_patterns(file)
```

## Arguments

- file:

  A path or a connection, as for
  [`readLines()`](https://rdrr.io/r/base/readLines.html). The file is
  read as UTF-8.

## Value

A data frame with columns `id` (integer), `pattern` (character) and
`flags` (integer), plus an `ext` list column of
[`hs_ext()`](https://pedrobtz.github.io/vectorscan/reference/hs_ext.md)
objects (`NULL` where a line has none) when any line has extended
parameters.

## Details

    # Comments and blank lines are skipped
    1:/foo(bar)?/i
    2:/^GET \/index\.html/sm
    3:/abc/{edit_distance=1}
    4:/[0-9]{4}-[0-9]{2}/L{min_offset=10,max_offset=200}

The regex runs from the first `/` after the id to the last `/` on the
line, so it may contain `/` itself. The flags are the letters of
[`hs_flags()`](https://pedrobtz.github.io/vectorscan/reference/hs_flags.md);
`O`, which Hyperscan's tools use for ordering, is accepted and ignored.
The extended parameters are those of
[`hs_ext()`](https://pedrobtz.github.io/vectorscan/reference/hs_ext.md).

## Examples

``` r
rules <- hs_read_patterns(textConnection(c(
  "# HTTP methods",
  "10:/^(GET|POST) /",
  "11:/error/i",
  "12:/timeout/{edit_distance=1}"
)))
rules
#>   id      pattern flags              ext
#> 1 10 ^(GET|POST)      0             NULL
#> 2 11        error     1             NULL
#> 3 12      timeout     0 8, 0, 0, 0, 1, 0
if (hs_available()) {
  hs_match(rules, c("GET /", "ERROR: timout"))
}
#>   input id      pattern from to  match
#> 1     1 10 ^(GET|POST)     0  4   GET 
#> 2     2 11        error    0  5  ERROR
#> 3     2 12      timeout    7 13 timout
```
