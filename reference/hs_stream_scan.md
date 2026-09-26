# Scan a stream chunk

Scan a stream chunk

## Usage

``` r
hs_stream_scan(stream, data, callback = NULL, context = NULL)
```

## Arguments

- stream:

  An open `hs_stream`.

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
