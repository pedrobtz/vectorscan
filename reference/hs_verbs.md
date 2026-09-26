# Vectorized matching over a character vector

These functions scan every element of a character vector against a set
of patterns in one call, in C, reusing one scratch space. They are the
R-shaped layer over
[`hs_scan()`](https://pedrobtz.github.io/vectorscan/reference/hs_scan.md):

## Usage

``` r
hs_detect(patterns, x, per_pattern = FALSE)

hs_count(patterns, x, per_pattern = FALSE)

hs_match(patterns, x, som = TRUE)

hs_extract(patterns, x, som = TRUE)
```

## Arguments

- patterns:

  A compiled block-mode `hs_database`, or patterns to compile (see
  Details).

- x:

  A character vector to scan.

- per_pattern:

  For `hs_detect()` and `hs_count()`: return a matrix with one column
  per pattern instead of one value per element.

- som:

  For `hs_match()` and `hs_extract()` when `patterns` are compiled on
  the fly: request start-of-match offsets.

## Value

- `hs_detect()`: a logical vector the length of `x`, or with
  `per_pattern = TRUE` a logical matrix with a column per pattern.

- `hs_count()`: an integer vector, or an integer matrix.

- `hs_match()`: a data frame with columns `input` (index into `x`),
  `id`, `pattern` (the pattern's name, or the expression if it has
  none), `from`, `to` and `match`.

- `hs_extract()`: a list the length of `x` of character vectors.

## Details

- `hs_detect()` – does any pattern match each element? Like
  [`grepl()`](https://rdrr.io/r/base/grep.html) for many patterns at
  once.

- `hs_count()` – how many matches in each element.

- `hs_match()` – every match, as a data frame with the element, the
  pattern, the byte offsets and the matched text.

- `hs_extract()` – the matched text for each element, as a list.

`patterns` is either a compiled block-mode
[`hs_database()`](https://pedrobtz.github.io/vectorscan/reference/hs_database.md)
or the patterns themselves, in any form
[`hs_compile()`](https://pedrobtz.github.io/vectorscan/reference/hs_compile.md)
accepts (a character vector, possibly named, or a rules data frame).
Given patterns, `hs_match()` and `hs_extract()` compile them with
[HS_FLAG_SOM_LEFTMOST](https://pedrobtz.github.io/vectorscan/reference/vectorscan-constants.md)
so that start offsets, and hence the matched text, are known; pass
`som = FALSE` to skip that. Given a database, start offsets exist only
for patterns compiled with that flag, and `from` and `match` are `NA`
for the others.

Offsets are zero-based byte offsets into the UTF-8 encoding of each
element: `from` is where the match starts and `to` where it ends, so the
match is bytes `from + 1` to `to`. Vectorscan reports every position at
which a pattern matches, so `a+` matches three times in `"aaa"` (ending
at 1, 2 and 3); use
[HS_FLAG_SINGLEMATCH](https://pedrobtz.github.io/vectorscan/reference/vectorscan-constants.md)
to report each pattern once per element.

`NA` elements give `NA` results.

## Examples

``` r
if (hs_available()) {
  x <- c("apple pie", "banana split", NA, "cherry")
  rules <- c(fruit = "apple|banana", dessert = "pie|split")

  hs_detect(rules, x)
  hs_count(rules, x, per_pattern = TRUE)
  hs_match(rules, x)
  hs_extract(rules, x)

  # Compile once, scan many times
  db <- hs_compile(rules)
  hs_detect(db, x)
}
#> [1]  TRUE  TRUE    NA FALSE
```
