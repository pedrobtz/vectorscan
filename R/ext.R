#' Create extended expression parameters
#'
#' `hs_ext()` creates extended compile parameters for one expression.
#'
#' @param min_offset,max_offset,min_length Optional non-negative offsets.
#' @param edit_distance,hamming_distance Optional non-negative distances.
#' @return An object that can be passed to `hs_compile()` through `ext`.
#' @export
#' @examples
#' hs_ext(min_length = 3)
hs_ext <- function(
  min_offset = NULL,
  max_offset = NULL,
  min_length = NULL,
  edit_distance = NULL,
  hamming_distance = NULL
) {
  flags <- 0L

  min_offset <- normalize_ext_value(min_offset, "min_offset")
  max_offset <- normalize_ext_value(max_offset, "max_offset")
  min_length <- normalize_ext_value(min_length, "min_length")
  edit_distance <- normalize_ext_value(edit_distance, "edit_distance")
  hamming_distance <- normalize_ext_value(hamming_distance, "hamming_distance")

  if (!is.null(min_offset)) {
    flags <- bitwOr(flags, HS_EXT_FLAG_MIN_OFFSET)
  }
  if (!is.null(max_offset)) {
    flags <- bitwOr(flags, HS_EXT_FLAG_MAX_OFFSET)
  }
  if (!is.null(min_length)) {
    flags <- bitwOr(flags, HS_EXT_FLAG_MIN_LENGTH)
  }
  if (!is.null(edit_distance)) {
    flags <- bitwOr(flags, HS_EXT_FLAG_EDIT_DISTANCE)
  }
  if (!is.null(hamming_distance)) {
    flags <- bitwOr(flags, HS_EXT_FLAG_HAMMING_DISTANCE)
  }

  structure(
    list(
      flags = flags,
      min_offset = min_offset %||% 0,
      max_offset = max_offset %||% 0,
      min_length = min_length %||% 0,
      edit_distance = edit_distance %||% 0,
      hamming_distance = hamming_distance %||% 0
    ),
    class = "hs_ext"
  )
}

normalize_ext_value <- function(x, name) {
  if (is.null(x)) {
    return(NULL)
  }

  # Offsets are 64-bit in Vectorscan, so values past .Machine$integer.max
  # are kept as doubles rather than turned into NA by as.integer().
  if (!is.numeric(x)) {
    stop_vectorscan(sprintf("`%s` must be numeric.", name))
  }
  if (length(x) != 1L) {
    stop_vectorscan(sprintf("`%s` must have length 1.", name))
  }
  if (is.na(x)) {
    stop_vectorscan(sprintf("`%s` must not contain missing values.", name))
  }
  if (x != floor(x)) {
    stop_vectorscan(sprintf("`%s` must contain whole numbers.", name))
  }
  check_nonnegative(x, name)
  if (x > 2^53) {
    stop_vectorscan(sprintf("`%s` must be at most 2^53.", name))
  }
  x
}

normalize_ext_list <- function(ext, n) {
  if (is.null(ext)) {
    return(NULL)
  }

  if (inherits(ext, "hs_ext")) {
    return(rep(list(ext), n))
  }

  if (!is.list(ext)) {
    stop_vectorscan("`ext` must be an `hs_ext()` object or list of them.")
  }

  ext <- recycle_or_check(ext, n, "ext")
  ext[vapply(ext, is.null, logical(1))] <- list(hs_ext())
  bad <- !vapply(ext, inherits, logical(1), "hs_ext")
  if (any(bad)) {
    stop_vectorscan("Every element of `ext` must be an `hs_ext()` object.")
  }

  ext
}
