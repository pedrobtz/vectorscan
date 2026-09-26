# Capture groups into a data frame

`hs_capture()` matches a regular expression with capture groups against
every element of a character vector and returns the groups as the
columns of a data frame, one row per element: what
[`utils::strcapture()`](https://rdrr.io/r/utils/strcapture.html) does,
in C, about 20 times faster on large inputs.

## Usage

``` r
hs_capture(pattern, x, proto = NULL)

hs_capture_compile(pattern)
```

## Arguments

- pattern:

  A single regular expression with capture groups, or a pattern compiled
  with `hs_capture_compile()` to reuse across calls.

- x:

  A character vector.

- proto:

  Optional data frame (typically with zero rows) giving the names and
  types of the columns, as in
  [`utils::strcapture()`](https://rdrr.io/r/utils/strcapture.html). It
  must have one column per capture group.

## Value

A data frame with `length(x)` rows and one column per capture group.

## Details

The pattern is a PCRE2 regular expression, compiled as base R's
`regexec(perl = TRUE)` compiles it, so the two agree on what matches.
Unlike the other `hs_*` functions it does not run on Vectorscan, whose
engine cannot report groups.

Columns are named after `proto`, else after named groups
(`(?<level>...)`), else `V1`, `V2`, ... With `proto`, each column is
converted to the type of the matching `proto` column as
[`utils::strcapture()`](https://rdrr.io/r/utils/strcapture.html)
converts it ([`as.integer()`](https://rdrr.io/r/base/integer.html) for
an integer column, and so on); without it every column is character.

Elements that do not match, and `NA` elements, give a row of `NA`. A
group that does not take part in the match (an optional group, or a
branch not taken) is `NA`, where
[`utils::strcapture()`](https://rdrr.io/r/utils/strcapture.html) gives
`""`. An element PCRE2 cannot match at all (for example invalid UTF-8)
also gives an `NA` row, and `hs_capture()` warns once with the number of
such elements.

## See also

[hs_detect()](https://pedrobtz.github.io/vectorscan/reference/hs_verbs.md)
and friends for matching many patterns at once.

## Examples

``` r
lines <- c(
  "2026-09-26 10:15:02 [INFO] api.server:42 - listening",
  "not a log line",
  "2026-09-26 10:16:00 [ERROR] auth.jwt:77 - token expired"
)
fmt <- "^(?<time>\\S+ \\S+) \\[(?<level>\\w+)\\] (?<location>[^:]+):(?<line>\\d+) - (?<text>.*)$"
hs_capture(fmt, lines)
#>                  time level   location line          text
#> 1 2026-09-26 10:15:02  INFO api.server   42     listening
#> 2                <NA>  <NA>       <NA> <NA>          <NA>
#> 3 2026-09-26 10:16:00 ERROR   auth.jwt   77 token expired

# With types, as utils::strcapture()
proto <- data.frame(time = character(), level = character(),
                    location = character(), line = integer(), text = character())
str(hs_capture(fmt, lines, proto))
#> 'data.frame':    3 obs. of  5 variables:
#>  $ time    : chr  "2026-09-26 10:15:02" NA "2026-09-26 10:16:00"
#>  $ level   : chr  "INFO" NA "ERROR"
#>  $ location: chr  "api.server" NA "auth.jwt"
#>  $ line    : int  42 NA 77
#>  $ text    : chr  "listening" NA "token expired"

# Compile once, reuse
compiled <- hs_capture_compile(fmt)
compiled
#> <hs_capture_pattern: 5 groups (time, level, location, line, text), JIT>
#>   ^(?<time>\S+ \S+) \[(?<level>\w+)\] (?<location>[^:]+):(?<line>\d+) - (?<text>.*)$
hs_capture(compiled, lines)
#>                  time level   location line          text
#> 1 2026-09-26 10:15:02  INFO api.server   42     listening
#> 2                <NA>  <NA>       <NA> <NA>          <NA>
#> 3 2026-09-26 10:16:00 ERROR   auth.jwt   77 token expired
```
