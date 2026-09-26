# Capture groups into a data frame

`hs_capture()` matches a regular expression with capture groups against
every element of a character vector and returns the groups as the
columns of a data frame, one row per element: what
[`utils::strcapture()`](https://rdrr.io/r/utils/strcapture.html) does,
in C, about 20 times faster on large inputs.

## Usage

``` r
hs_capture(pattern, x, proto = NULL, match_limit = NULL, depth_limit = NULL)

hs_capture_compile(pattern, jit = TRUE)
```

## Arguments

- pattern:

  A single regular expression with capture groups, a character vector of
  formats (see "Several formats"), or either compiled with
  `hs_capture_compile()` to reuse across calls.

- x:

  A character vector.

- proto:

  Optional data frame (typically with zero rows) giving the names and
  types of the columns, as in
  [`utils::strcapture()`](https://rdrr.io/r/utils/strcapture.html). It
  must have one column per capture group; for several formats, one
  column per group name, matched by name.

- match_limit, depth_limit:

  Optional positive whole numbers: PCRE2's match limit and depth limit
  per element (see "Untrusted input"). `NULL` keeps PCRE2's defaults.

- jit:

  For `hs_capture_compile()`: use PCRE2's just-in-time compiler when
  available. `FALSE` runs PCRE2's interpreter, which is slower but gives
  the same results.

## Value

A data frame with `length(x)` rows and one column per capture group,
plus a `pattern` column first for several formats.

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

## Several formats

`pattern` can also be a character vector of formats, typically named,
for input that mixes them (log lines from several services, say). Each
element is captured by the first format, in order, that matches it. The
result gains a first column, `pattern`, with the name of that format (or
the expression, for an unnamed one), and has one column per group name
across all formats: groups with the same name share a column, and a
format that lacks a group leaves it `NA`.

Formats are routed with Vectorscan: one pass over `x` finds, for each
element, the formats that can match it (Vectorscan's prefilter mode,
which never misses a match), and PCRE2 then runs only there. The result
is the same as trying every format on every element in order, but with
many formats it is several times faster. A format Vectorscan cannot
compile even in prefilter mode (PCRE2's branch reset `(?|...)`, for
example) is simply tried on every element that is still unmatched.

## Untrusted input

Some patterns can take exponential time on some inputs (nested
quantifiers such as `(a+)+$`, for example). `match_limit` bounds the
work PCRE2 may do per element, and `depth_limit` its backtracking memory
(in the interpreter; the just-in-time compiled code has its own fixed
stack, and an element that exhausts it is retried in the interpreter).
An element that hits a limit gives an `NA` row and counts towards the
warning, so one pathological line cannot stall or abort a scan. Both
default to PCRE2's own defaults (a match limit of 10,000,000).

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

# Several formats
mixed <- c("GET /index.html 200", "user=ada action=login", "GET /api 500")
hs_capture(c(
  http = "^(?<method>[A-Z]+) (?<path>\\S+) (?<status>\\d{3})$",
  audit = "^user=(?<user>\\w+) action=(?<action>\\w+)$"
), mixed)
#>   pattern method        path status user action
#> 1    http    GET /index.html    200 <NA>   <NA>
#> 2   audit   <NA>        <NA>   <NA>  ada  login
#> 3    http    GET        /api    500 <NA>   <NA>
```
