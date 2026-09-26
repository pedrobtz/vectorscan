# Size of a stream's state

The number of bytes of state each open stream of a stream-mode database
needs, a measure of the memory cost of keeping many streams open.

## Usage

``` r
hs_stream_size(database)
```

## Arguments

- database:

  A compiled stream-mode `hs_database`.

## Value

A single number of bytes.

## Examples

``` r
if (hs_available()) {
  db <- hs_database(HS_MODE_STREAM)
  hs_compile(db, c("foo.*bar", "baz"))
  hs_stream_size(db)
}
#> [1] 39
```
