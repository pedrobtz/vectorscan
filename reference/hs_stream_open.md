# Open a stream

Open a stream

## Usage

``` r
hs_stream_open(database)
```

## Arguments

- database:

  A compiled stream-mode `hs_database`.

## Value

An `hs_stream` object.

## Examples

``` r
if (hs_available()) {
  db <- hs_database(HS_MODE_STREAM)
  hs_compile(db, "foo")
  stream <- hs_stream_open(db)
  hs_stream_scan(stream, "foo")
  hs_stream_close(stream)
}
#> [1] id    from  to    flags
#> <0 rows> (or 0-length row.names)
```
