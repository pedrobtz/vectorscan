# Compile expressions into a database

Compile expressions into a database

## Usage

``` r
hs_compile(database, expressions, ids = NULL, flags = NULL, ext = NULL)
```

## Arguments

- database:

  An `hs_database` object.

- expressions:

  Character vector of regular expressions.

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

## Examples

``` r
if (hs_available()) {
  db <- hs_database()
  hs_compile(db, "foo")
  hs_scan(db, "foo")
}
#>   id from to flags
#> 1  0   NA  3     0
```
