# Close a stream

Close a stream

## Usage

``` r
hs_stream_close(stream, callback = NULL, context = NULL)
```

## Arguments

- stream:

  An open `hs_stream`.

- callback:

  Optional function called as `callback(id, from, to, flags, context)`.
  Return `TRUE` to stop scanning.

- context:

  Optional object passed to `callback`.

## Value

A data frame of matches found while closing when `callback` is `NULL`;
otherwise the number of callback invocations, invisibly.
