# Parsing logs

A log file is a character vector with a format.
[`hs_capture()`](https://pedrobtz.github.io/vectorscan/reference/hs_capture.md)
turns it into a data frame with one regular expression: one row per
line, one column per capture group.

``` r

library(vectorscan)
```

## One format

``` r

lines <- c(
  "2026-09-26 10:15:02.117 [INFO]  api.server:42 - listening on :8080",
  "2026-09-26 10:15:07.901 [WARN]  db.pool:118 - slow query took 1.8s",
  "--- rotated ---",
  "2026-09-26 10:16:00.004 [ERROR] auth.jwt:77 - token expired for user 12"
)

fmt <- paste0(
  "^(?<time>\\S+ \\S+) \\[(?<level>\\w+)\\]\\s+",
  "(?<location>[^ :]+):(?<line>\\d+) - (?<text>.*)$"
)

hs_capture(fmt, lines)
#>                      time level   location line                      text
#> 1 2026-09-26 10:15:02.117  INFO api.server   42        listening on :8080
#> 2 2026-09-26 10:15:07.901  WARN    db.pool  118      slow query took 1.8s
#> 3                    <NA>  <NA>       <NA> <NA>                      <NA>
#> 4 2026-09-26 10:16:00.004 ERROR   auth.jwt   77 token expired for user 12
```

Named groups (`(?<level>...)`) name the columns. Lines that do not match
the format, like the rotation marker, give a row of `NA`, so they are
easy to find:

``` r

log <- hs_capture(fmt, lines)
lines[is.na(log$time)]
#> [1] "--- rotated ---"
```

## Column types

Pass a `proto`, as for
[`utils::strcapture()`](https://rdrr.io/r/utils/strcapture.html), to get
typed columns. Its names replace the group names:

``` r

proto <- data.frame(
  time = character(), level = character(), location = character(),
  line = integer(), text = character()
)
log <- hs_capture(fmt, lines, proto)
log$time <- as.POSIXct(log$time, format = "%Y-%m-%d %H:%M:%OS", tz = "UTC")
str(log)
#> 'data.frame':    4 obs. of  5 variables:
#>  $ time    : POSIXct, format: "2026-09-26 10:15:02" "2026-09-26 10:15:07" ...
#>  $ level   : chr  "INFO" "WARN" NA "ERROR"
#>  $ location: chr  "api.server" "db.pool" NA "auth.jwt"
#>  $ line    : int  42 118 NA 77
#>  $ text    : chr  "listening on :8080" "slow query took 1.8s" NA "token expired for user 12"
```

## Reading a file

For a real file, read the lines and compile the pattern once:

``` r

compiled <- hs_capture_compile(fmt)
log <- hs_capture(compiled, readLines("app.log"), proto)
```

## Only some lines

When only a few lines matter, filter first with
[`hs_detect()`](https://pedrobtz.github.io/vectorscan/reference/hs_verbs.md),
which checks every line against many patterns in one pass on Vectorscan,
then capture fields from the lines it keeps:

``` r

interesting <- c(error = "\\[ERROR\\]", slow = "slow query took")
keep <- hs_detect(interesting, lines)
hs_capture(fmt, lines[keep], proto)
#>                      time level location line                      text
#> 1 2026-09-26 10:15:07.901  WARN  db.pool  118      slow query took 1.8s
#> 2 2026-09-26 10:16:00.004 ERROR auth.jwt   77 token expired for user 12
```

## Several formats

A log that mixes formats (several services writing to one file, say)
takes a named vector of formats. Each line is captured by the first
format that matches it; a `pattern` column says which, and groups with
the same name share a column:

``` r

mixed <- c(
  "2026-09-26 10:15:02.117 [INFO]  api.server:42 - listening on :8080",
  "GET /index.html 200 12ms",
  "2026-09-26 10:16:00.004 [ERROR] auth.jwt:77 - token expired for user 12",
  "POST /login 401 3ms"
)
formats <- c(
  app = fmt,
  http = "^(?<method>[A-Z]+) (?<path>\\S+) (?<status>\\d{3}) (?<time>\\d+ms)$"
)
hs_capture(formats, mixed)
#>   pattern                    time level   location line
#> 1     app 2026-09-26 10:15:02.117  INFO api.server   42
#> 2    http                    12ms  <NA>       <NA> <NA>
#> 3     app 2026-09-26 10:16:00.004 ERROR   auth.jwt   77
#> 4    http                     3ms  <NA>       <NA> <NA>
#>                        text method        path status
#> 1        listening on :8080   <NA>        <NA>   <NA>
#> 2                      <NA>    GET /index.html    200
#> 3 token expired for user 12   <NA>        <NA>   <NA>
#> 4                      <NA>   POST      /login    401
```

Vectorscan finds, in one pass, which formats can match each line, so
PCRE2 runs only there. The result is the same as trying every format on
every line in order. With 20 formats and a million lines that all match
the last one (the worst case for trying in order), that takes 1.5 s
against 4.1 s.

## How fast

On a 1,000,000-line log (72 MB) in the format above, on an Apple
M-series laptop, each timed in a fresh R session (script in
`tools/bench-capture/` in the source repository):

|  | every line matches | 1% of lines match |
|----|----|----|
| `utils::strcapture(perl = TRUE)` | 12.8 s | 6.5 s |
| [`hs_capture()`](https://pedrobtz.github.io/vectorscan/reference/hs_capture.md) | 0.60 s | 0.24 s |

That is 21 and 27 times faster. (Timing both in one session flatters
whichever runs second: R caches strings globally, and the second run
finds most of its 5 million field values already made.)

The two return identical data frames. The difference is not the regex
engine: both use PCRE2.
[`strcapture()`](https://rdrr.io/r/utils/strcapture.html) goes through
[`regexec()`](https://rdrr.io/r/base/grep.html) and
[`regmatches()`](https://rdrr.io/r/base/regmatches.html), which build R
objects for every line.
[`hs_capture()`](https://pedrobtz.github.io/vectorscan/reference/hs_capture.md)
matches and fills the columns directly in C, with PCRE2’s just-in-time
compiler.

## Differences from `strcapture()`

- A group that does not take part in the match (an optional group, or a
  branch not taken) is `NA` in
  [`hs_capture()`](https://pedrobtz.github.io/vectorscan/reference/hs_capture.md)
  and `""` in [`strcapture()`](https://rdrr.io/r/utils/strcapture.html).
- Lines PCRE2 cannot match at all, such as invalid UTF-8, give an `NA`
  row and one warning with their count.
- The pattern is always a Perl-compatible regular expression, as
  `strcapture(perl = TRUE)`.
