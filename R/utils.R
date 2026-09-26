`%||%` <- function(x, y) {
  if (is.null(x)) {
    y
  } else {
    x
  }
}

#' Is Vectorscan or Hyperscan available?
#'
#' Reports whether this installation was compiled with native
#' Vectorscan/Hyperscan support.
#'
#' @return A single `TRUE` or `FALSE`.
#' @export
#' @examples
#' hs_available()
hs_available <- function() {
  .Call(vctrsn_hs_available)
}

check_integerish <- function(x, name, len = NULL, allow_na = FALSE) {
  if (!is.numeric(x)) {
    stop_vectorscan(sprintf("`%s` must be numeric.", name))
  }

  if (!is.null(len) && length(x) != len) {
    stop_vectorscan(sprintf("`%s` must have length %d.", name, len))
  }

  if (!allow_na && anyNA(x)) {
    stop_vectorscan(sprintf("`%s` must not contain missing values.", name))
  }

  finite <- is.finite(x)
  if (any(finite & x != floor(x))) {
    stop_vectorscan(sprintf("`%s` must contain whole numbers.", name))
  }

  as.integer(x)
}

check_nonnegative <- function(x, name) {
  if (any(x < 0, na.rm = TRUE)) {
    stop_vectorscan(sprintf("`%s` must be non-negative.", name))
  }

  x
}

recycle_or_check <- function(x, n, name) {
  if (length(x) == 1L && n != 1L) {
    rep(x, n)
  } else if (length(x) == n) {
    x
  } else {
    stop_vectorscan(sprintf("`%s` must have length 1 or %d.", name, n))
  }
}

as_hs_raw <- function(data, name = "data") {
  if (is.raw(data)) {
    return(data)
  }

  if (is.character(data) && length(data) == 1L && !is.na(data)) {
    return(charToRaw(enc2utf8(data)))
  }

  stop_vectorscan(sprintf("`%s` must be a raw vector or a string.", name))
}

as_hs_raw_list <- function(data, name = "data") {
  if (is.raw(data)) {
    return(list(data))
  }

  if (is.character(data)) {
    if (anyNA(data)) {
      stop_vectorscan(sprintf("`%s` must not contain missing strings.", name))
    }
    return(lapply(enc2utf8(data), charToRaw))
  }

  if (is.list(data)) {
    return(lapply(seq_along(data), function(i) {
      as_hs_raw(data[[i]], sprintf("%s[[%d]]", name, i))
    }))
  }

  stop_vectorscan(
    sprintf("`%s` must be a raw vector, character vector, or list.", name)
  )
}
