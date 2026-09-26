#' Create a Vectorscan database handle
#'
#' Creates an empty database handle. Compile patterns into the handle with
#' `hs_compile()`.
#'
#' @param mode One compile mode, such as `HS_MODE_BLOCK`, `HS_MODE_STREAM`, or
#'   `HS_MODE_VECTORED`.
#' @param platform Reserved for future platform-specific compile options.
#' @return An `hs_database` object.
#' @export
#' @examples
#' db <- hs_database()
#' db
hs_database <- function(mode = HS_MODE_BLOCK, platform = NULL) {
  if (!is.null(platform)) {
    stop_vectorscan(
      "`platform` is reserved for a future release.",
      class = "vectorscan_error_platform"
    )
  }

  new_hs_database(check_mode(mode))
}

new_hs_database <- function(mode = NA_integer_) {
  database <- new.env(parent = emptyenv())
  database$ptr <- NULL
  database$scratch <- NULL
  database$mode <- mode
  database$pattern_ids <- integer()
  database$pattern_flags <- integer()
  class(database) <- "hs_database"
  database
}

check_mode <- function(mode) {
  mode <- check_integerish(mode, "mode", len = 1L)
  check_nonnegative(mode, "mode")

  base_modes <- c(HS_MODE_BLOCK, HS_MODE_STREAM, HS_MODE_VECTORED)
  selected <- bitwAnd(mode, Reduce(bitwOr, base_modes))
  if (!selected %in% base_modes) {
    stop_vectorscan(
      "`mode` must contain exactly one of HS_MODE_BLOCK, HS_MODE_STREAM, or HS_MODE_VECTORED.",
      class = "vectorscan_error_mode"
    )
  }

  mode
}

#' @export
print.hs_database <- function(x, ...) {
  state <- if (is_hs_database_compiled(x)) "compiled" else "empty"
  mode <- mode_label(x$mode)
  cat(sprintf("<hs_database: %s, %s>\n", state, mode))
  invisible(x)
}

mode_label <- function(mode) {
  if (length(mode) != 1L || is.na(mode)) {
    return("unknown mode")
  }

  if (bitwAnd(mode, HS_MODE_BLOCK) != 0L) {
    "block mode"
  } else if (bitwAnd(mode, HS_MODE_STREAM) != 0L) {
    "stream mode"
  } else if (bitwAnd(mode, HS_MODE_VECTORED) != 0L) {
    "vectored mode"
  } else {
    "unknown mode"
  }
}

is_hs_database <- function(database) {
  inherits(database, "hs_database")
}

is_hs_database_compiled <- function(database) {
  is_hs_database(database) && !is.null(database$ptr)
}

check_database <- function(database, compiled = FALSE) {
  if (!is_hs_database(database)) {
    stop_vectorscan("`database` must be an `hs_database` object.")
  }

  if (compiled && !is_hs_database_compiled(database)) {
    stop_vectorscan("`database` has not been compiled.")
  }

  invisible(database)
}

#' Compile expressions into a database
#'
#' @param database An `hs_database` object.
#' @param expressions Character vector of regular expressions.
#' @param ids Optional integer ids. Defaults to zero-based pattern positions.
#' @param flags Optional integer flags, recycled from length 1.
#' @param ext Optional `hs_ext()` object or list of `hs_ext()` objects.
#' @return `database`, invisibly.
#' @export
#' @examples
#' if (hs_available()) {
#'   db <- hs_database()
#'   hs_compile(db, "foo")
#'   hs_scan(db, "foo")
#' }
hs_compile <- function(
  database,
  expressions,
  ids = NULL,
  flags = NULL,
  ext = NULL
) {
  check_database(database)

  if (!is.character(expressions)) {
    stop_vectorscan("`expressions` must be a character vector.")
  }
  if (length(expressions) == 0L) {
    stop_vectorscan("`expressions` must contain at least one pattern.")
  }
  if (anyNA(expressions)) {
    stop_vectorscan("`expressions` must not contain missing values.")
  }

  n <- length(expressions)

  ids <- ids %||% seq.int(0L, length.out = n)
  ids <- check_integerish(ids, "ids")
  ids <- recycle_or_check(ids, n, "ids")
  check_nonnegative(ids, "ids")

  flags <- flags %||% HS_FLAG_NONE
  flags <- check_integerish(flags, "flags")
  flags <- recycle_or_check(flags, n, "flags")
  check_nonnegative(flags, "flags")

  ext <- normalize_ext_list(ext, n)

  compiled <- .Call(
    vctrsn_hs_compile,
    enc2utf8(expressions),
    ids,
    flags,
    database$mode,
    ext
  )

  database$ptr <- compiled$database
  database$scratch <- compiled$scratch
  database$pattern_ids <- ids
  database$pattern_flags <- flags

  invisible(database)
}

#' Get database information
#'
#' @param database A compiled `hs_database` object.
#' @return A single string reported by Vectorscan/Hyperscan.
#' @export
#' @examples
#' if (hs_available()) {
#'   db <- hs_database()
#'   hs_compile(db, "foo")
#'   hs_info(db)
#' }
hs_info <- function(database) {
  check_database(database, compiled = TRUE)
  .Call(vctrsn_hs_info, database$ptr)
}

#' Get database size
#'
#' @inheritParams hs_info
#' @return Database size in bytes.
#' @export
#' @examples
#' if (hs_available()) {
#'   db <- hs_database()
#'   hs_compile(db, "foo")
#'   hs_database_size(db)
#' }
hs_database_size <- function(database) {
  check_database(database, compiled = TRUE)
  .Call(vctrsn_hs_database_size, database$ptr)
}
