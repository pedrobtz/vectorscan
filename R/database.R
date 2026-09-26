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
  database$patterns <- character()
  database$pattern_names <- character()
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
#' Patterns can be given as a character vector, optionally named, or as a
#' data frame of rules with a `pattern` column and optional `id`, `flags` and
#' `name` columns. Names label the patterns in the output of [hs_match()][hs_verbs],
#' [hs_detect()][hs_verbs] and friends.
#'
#' `hs_compile(expressions)`, without a database, compiles into a new
#' block-mode database and returns it.
#'
#' @param database An `hs_database` object, or the expressions themselves to
#'   compile into a new block-mode database.
#' @param expressions Character vector of regular expressions, or a data frame
#'   of rules (see Details).
#' @param ids Optional integer ids. Defaults to zero-based pattern positions.
#' @param flags Optional flags, recycled from length 1: integers built from the
#'   `HS_FLAG_*` constants, or strings of flag letters or names read by
#'   [hs_flags()], such as `"i"` or `"caseless|dotall"`.
#' @param ext Optional `hs_ext()` object or list of `hs_ext()` objects.
#' @param literal If `TRUE`, the expressions are plain strings to find, not
#'   regular expressions: `"a.b"` matches only `"a.b"`. Literals compile
#'   faster and into smaller databases, and only the flags `HS_FLAG_CASELESS`,
#'   `HS_FLAG_SINGLEMATCH` and `HS_FLAG_SOM_LEFTMOST` apply; `ext` cannot be
#'   used.
#' @return `database`, invisibly.
#' @export
#' @examples
#' if (hs_available()) {
#'   db <- hs_database()
#'   hs_compile(db, "foo")
#'   hs_scan(db, "foo")
#'
#'   # One call, named patterns
#'   db <- hs_compile(c(greeting = "hel+o", number = "[0-9]+"))
#'   hs_match(db, c("hello 42", "nothing"))
#'
#'   # Flags as letters, and plain strings instead of regular expressions
#'   db <- hs_compile(c("Error", "a.b"), flags = "i", literal = TRUE)
#'   hs_detect(db, c("ERROR: x", "a.b", "axb"))
#' }
hs_compile <- function(
  database,
  expressions,
  ids = NULL,
  flags = NULL,
  ext = NULL,
  literal = FALSE
) {
  if (!is_hs_database(database) && missing(expressions) &&
    (is.character(database) || is.data.frame(database))) {
    expressions <- database
    database <- hs_database()
  }
  check_database(database)

  if (!is.logical(literal) || length(literal) != 1L || is.na(literal)) {
    stop_vectorscan("`literal` must be TRUE or FALSE.")
  }

  rules <- normalize_rules(expressions, ids, flags, ext)
  expressions <- rules$pattern
  ids <- rules$id
  flags <- rules$flags
  ext <- rules$ext

  n <- length(expressions)

  ids <- ids %||% seq.int(0L, length.out = n)
  ids <- check_integerish(ids, "ids")
  ids <- recycle_or_check(ids, n, "ids")
  check_nonnegative(ids, "ids")

  flags <- normalize_flags(flags %||% HS_FLAG_NONE)
  flags <- recycle_or_check(flags, n, "flags")

  ext <- normalize_ext_list(ext, n)
  if (literal && !is.null(ext)) {
    stop_vectorscan("`ext` cannot be used with `literal = TRUE`.")
  }

  compiled <- .Call(
    vctrsn_hs_compile,
    enc2utf8(expressions),
    ids,
    flags,
    database$mode,
    ext,
    literal
  )

  database$ptr <- compiled$database
  database$scratch <- compiled$scratch
  database$pattern_ids <- ids
  database$pattern_flags <- flags
  database$patterns <- expressions
  database$pattern_names <- rules$name

  invisible(database)
}

# Expressions as a character vector (names optional) or a rules data frame,
# returned as pattern / id / flags / name / ext with ids, flags and ext still
# to check.
normalize_rules <- function(expressions, ids, flags, ext = NULL) {
  if (is.data.frame(expressions)) {
    rules <- expressions
    if (!"pattern" %in% names(rules)) {
      stop_vectorscan("A rules data frame needs a `pattern` column.")
    }
    args <- list(id = ids, flags = flags, ext = ext)
    for (col in names(args)) {
      if (col %in% names(rules) && !is.null(args[[col]])) {
        stop_vectorscan(sprintf(
          "Give `%s` as a column of the rules or as an argument, not both.",
          if (col == "id") "ids" else col
        ))
      }
    }
    expressions <- rules$pattern
    if (is.factor(expressions)) {
      expressions <- as.character(expressions)
    }
    ids <- if ("id" %in% names(rules)) rules$id else ids
    flags <- if ("flags" %in% names(rules)) rules$flags else flags
    ext <- if ("ext" %in% names(rules)) rules$ext else ext
    labels <- if ("name" %in% names(rules)) as.character(rules$name) else NULL
  } else {
    labels <- names(expressions)
  }

  if (!is.character(expressions)) {
    stop_vectorscan("`expressions` must be a character vector.")
  }
  if (length(expressions) == 0L) {
    stop_vectorscan("`expressions` must contain at least one pattern.")
  }
  if (anyNA(expressions)) {
    stop_vectorscan("`expressions` must not contain missing values.")
  }

  labels <- labels %||% rep(NA_character_, length(expressions))
  labels[!is.na(labels) & labels == ""] <- NA_character_

  list(
    pattern = unname(expressions),
    id = ids,
    flags = flags,
    name = unname(labels),
    ext = ext
  )
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
