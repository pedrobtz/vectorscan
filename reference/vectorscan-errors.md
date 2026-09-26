# Errors raised by vectorscan

Every error the package raises is a condition of class
`vectorscan_error`, so `tryCatch(..., vectorscan_error = ...)` catches
them all. More specific classes sit in front of it:

## Details

- `vectorscan_error_compile`: a pattern did not compile. The condition
  has fields `expression` (the zero-based index of the offending
  pattern) and `reason` (Vectorscan's message).

- `vectorscan_error_native`: any other error returned by the Vectorscan
  library, with fields `code` and `operation`, and one class per error
  code: `vectorscan_error_invalid`, `_nomem`, `_scan_terminated`,
  `_db_version`, `_db_platform`, `_db_mode` (for example, a stream
  opened on a block-mode database), `_bad_align`, `_bad_alloc`,
  `_scratch_in_use`, `_arch`, `_insufficient_space` and `_unknown`.

- `vectorscan_error_mode`, `vectorscan_error_platform` and
  `vectorscan_error_unavailable`: invalid arguments and builds without
  Vectorscan.

An error raised inside a match callback is not wrapped: the scan stops
and the callback's own condition is re-raised, with its class and
message.

## Examples

``` r
if (hs_available()) {
  err <- tryCatch(hs_compile("a(b"), vectorscan_error_compile = function(e) e)
  err$expression
  err$reason
}
#> [1] "Missing close parenthesis for group started at index 1."
```
