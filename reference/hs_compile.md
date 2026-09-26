# Compile expressions into a database

Patterns can be given as a character vector, optionally named, or as a
data frame of rules with a `pattern` column and optional `id`, `flags`
and `name` columns. Names label the patterns in the output of
[hs_match()](https://pedrobtz.github.io/vectorscan/reference/hs_verbs.md),
[hs_detect()](https://pedrobtz.github.io/vectorscan/reference/hs_verbs.md)
and friends.

## Usage

``` r
hs_compile(database, expressions, ids = NULL, flags = NULL, ext = NULL)
```

## Arguments

- database:

  An `hs_database` object, or the expressions themselves to compile into
  a new block-mode database.

- expressions:

  Character vector of regular expressions, or a data frame of rules (see
  Details).

- ids:

  Optional integer ids. Defaults to zero-based pattern positions.

- flags:

  Optional integer flags, recycled from length 1.

- ext:

  Optional
  [`hs_ext()`](https://pedrobtz.github.io/vectorscan/reference/hs_ext.md)
  object or list of
  [`hs_ext()`](https://pedrobtz.github.io/vectorscan/reference/hs_ext.md)
  objects.

## Value

`database`, invisibly.

## Details

`hs_compile(expressions)`, without a database, compiles into a new
block-mode database and returns it.

## Examples

``` r
if (hs_available()) {
  db <- hs_database()
  hs_compile(db, "foo")
  hs_scan(db, "foo")

  # One call, named patterns
  db <- hs_compile(c(greeting = "hel+o", number = "[0-9]+"))
  hs_match(db, c("hello 42", "nothing"))
}
#>   input id  pattern from to match
#> 1     1  0 greeting   NA  5  <NA>
#> 2     1  1   number   NA  7  <NA>
#> 3     1  1   number   NA  8  <NA>
```
