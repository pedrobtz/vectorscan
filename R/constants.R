#' Vectorscan and Hyperscan constants
#'
#' Integer constants used when compiling Vectorscan/Hyperscan databases.
#'
#' Combine flags with [bitwOr()], not `|` (which is a logical "or" in R).
#'
#' In stream mode, patterns compiled with `HS_FLAG_SOM_LEFTMOST` need a
#' start-of-match horizon, which bounds how far back a start offset is kept:
#' `HS_MODE_SOM_HORIZON_LARGE` (the whole stream), `_MEDIUM` (32 bits of
#' offset) or `_SMALL` (16 bits), as in
#' `hs_database(bitwOr(HS_MODE_STREAM, HS_MODE_SOM_HORIZON_LARGE))`. A start
#' beyond the horizon is reported as `NA`.
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

#' @rdname vectorscan-constants
#' @export
HS_MODE_SOM_HORIZON_LARGE <- 16777216L

#' @rdname vectorscan-constants
#' @export
HS_MODE_SOM_HORIZON_MEDIUM <- 33554432L

#' @rdname vectorscan-constants
#' @export
HS_MODE_SOM_HORIZON_SMALL <- 67108864L

HS_EXT_FLAG_MIN_OFFSET <- 1L
HS_EXT_FLAG_MAX_OFFSET <- 2L
HS_EXT_FLAG_MIN_LENGTH <- 4L
HS_EXT_FLAG_EDIT_DISTANCE <- 8L
HS_EXT_FLAG_HAMMING_DISTANCE <- 16L
