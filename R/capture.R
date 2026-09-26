# The PCRE2 capture engine behind hs_capture() (capture-groups plan, M2).
# Internal until the R API lands in M3.

pcre2_compile_pattern <- function(pattern) {
  if (!is.character(pattern) || length(pattern) != 1L || is.na(pattern)) {
    stop_vectorscan("`pattern` must be a single string.")
  }
  .Call(vctrsn_pcre2_compile, enc2utf8(pattern))
}

# list(matched, groups, errors) for every element of `x`: see
# vctrsn_pcre2_capture_many() in src/capture.c.
capture_many <- function(pattern, x) {
  if (!is.character(x)) {
    stop_vectorscan("`x` must be a character vector.")
  }
  compiled <- pcre2_compile_pattern(pattern)
  out <- .Call(vctrsn_pcre2_capture_many, compiled$ptr, x)
  names(out$groups) <- compiled$names
  out
}
