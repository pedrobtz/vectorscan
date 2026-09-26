# Scan vectored data

Scan vectored data

## Usage

``` r
hs_scan_vector(database, data, callback = NULL, context = NULL)
```

## Arguments

- database:

  A compiled block-mode `hs_database`.

- data:

  A raw vector, character vector, or list of raw vectors/strings.

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
  db <- hs_database(HS_MODE_VECTORED)
  hs_compile(db, "foobar")
  hs_scan_vector(db, c("foo", "bar"))
}
#>   id from to flags
#> 1  0   NA  6     0
```
