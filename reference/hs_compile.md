# Compile expressions into a database

Patterns can be given as a character vector, optionally named, or as a
data frame of rules with a `pattern` column and optional `id`, `flags`
and `name` columns. Names label the patterns in the output of
[hs_match()](https://pedrobtz.github.io/vectorscan/reference/hs_verbs.md),
[hs_detect()](https://pedrobtz.github.io/vectorscan/reference/hs_verbs.md)
and friends.

## Usage

``` r
hs_compile(
  database,
  expressions,
  ids = NULL,
  flags = NULL,
  ext = NULL,
  literal = FALSE
)
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

  Optional flags, recycled from length 1: integers built from the
  `HS_FLAG_*` constants, or strings of flag letters or names read by
  [`hs_flags()`](https://pedrobtz.github.io/vectorscan/reference/hs_flags.md),
  such as `"i"` or `"caseless|dotall"`.

- ext:

  Optional
  [`hs_ext()`](https://pedrobtz.github.io/vectorscan/reference/hs_ext.md)
  object or list of
  [`hs_ext()`](https://pedrobtz.github.io/vectorscan/reference/hs_ext.md)
  objects.

- literal:

  If `TRUE`, the expressions are plain strings to find, not regular
  expressions: `"a.b"` matches only `"a.b"`. Literals compile faster and
  into smaller databases, and only the flags `HS_FLAG_CASELESS`,
  `HS_FLAG_SINGLEMATCH` and `HS_FLAG_SOM_LEFTMOST` apply; `ext` cannot
  be used.

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

  # Flags as letters, and plain strings instead of regular expressions
  db <- hs_compile(c("Error", "a.b"), flags = "i", literal = TRUE)
  hs_detect(db, c("ERROR: x", "a.b", "axb"))
}
#> [1]  TRUE  TRUE FALSE
```
