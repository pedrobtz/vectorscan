#' Vectorscan and Hyperscan constants
#'
#' Integer constants used when compiling Vectorscan/Hyperscan databases.
#'
#' @name vectorscan-constants
#' @examples
#' HS_FLAG_CASELESS
#' HS_MODE_BLOCK
NULL

#' @rdname vectorscan-constants
#' @export
HS_FLAG_NONE <- 0L

#' @rdname vectorscan-constants
#' @export
HS_FLAG_CASELESS <- 1L

#' @rdname vectorscan-constants
#' @export
HS_FLAG_DOTALL <- 2L

#' @rdname vectorscan-constants
#' @export
HS_FLAG_MULTILINE <- 4L

#' @rdname vectorscan-constants
#' @export
HS_FLAG_SINGLEMATCH <- 8L

#' @rdname vectorscan-constants
#' @export
HS_FLAG_ALLOWEMPTY <- 16L

#' @rdname vectorscan-constants
#' @export
HS_FLAG_UTF8 <- 32L

#' @rdname vectorscan-constants
#' @export
HS_FLAG_UCP <- 64L

#' @rdname vectorscan-constants
#' @export
HS_FLAG_PREFILTER <- 128L

#' @rdname vectorscan-constants
#' @export
HS_FLAG_SOM_LEFTMOST <- 256L

#' @rdname vectorscan-constants
#' @export
HS_FLAG_COMBINATION <- 512L

#' @rdname vectorscan-constants
#' @export
HS_FLAG_QUIET <- 1024L

#' @rdname vectorscan-constants
#' @export
HS_MODE_BLOCK <- 1L

#' @rdname vectorscan-constants
#' @export
HS_MODE_STREAM <- 2L

#' @rdname vectorscan-constants
#' @export
HS_MODE_VECTORED <- 4L

HS_EXT_FLAG_MIN_OFFSET <- 1L
HS_EXT_FLAG_MAX_OFFSET <- 2L
HS_EXT_FLAG_MIN_LENGTH <- 4L
HS_EXT_FLAG_EDIT_DISTANCE <- 8L
HS_EXT_FLAG_HAMMING_DISTANCE <- 16L
