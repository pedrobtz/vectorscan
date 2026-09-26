# Scan one block of data

Scan one block of data

## Usage

``` r
hs_scan(database, data, callback = NULL, context = NULL)
```

## Arguments

- database:

  A compiled block-mode `hs_database`.

- data:

  A raw vector or string.

- callback:

  Optional function called as `callback(id, from, to, flags, context)`.
  Return `TRUE` to stop scanning.

- context:

  Optional object passed to `callback`.

## Value

A data frame of matches when `callback` is `NULL`; otherwise the number
of callback invocations, invisibly.

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
