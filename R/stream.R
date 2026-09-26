#' Open a stream
#'
#' @param database A compiled stream-mode `hs_database`.
#' @return An `hs_stream` object.
#' @export
#' @examples
#' if (hs_available()) {
#'   db <- hs_database(HS_MODE_STREAM)
#'   hs_compile(db, "foo")
#'   stream <- hs_stream_open(db)
#'   hs_stream_scan(stream, "foo")
#'   hs_stream_close(stream)
#' }
hs_stream_open <- function(database) {
  check_database(database, compiled = TRUE)

  stream <- new.env(parent = emptyenv())
  stream$ptr <- .Call(
    vctrsn_hs_stream_open,
    database$ptr,
    database
  )
  stream$database <- database
  stream$closed <- FALSE
  class(stream) <- "hs_stream"
  stream
}

#' @export
print.hs_stream <- function(x, ...) {
  state <- if (isTRUE(x$closed)) "closed" else "open"
  cat(sprintf("<hs_stream: %s>\n", state))
  invisible(x)
}

check_stream <- function(stream) {
  if (!inherits(stream, "hs_stream")) {
    stop_vectorscan("`stream` must be an `hs_stream` object.")
  }
  if (isTRUE(stream$closed)) {
    stop_vectorscan("`stream` is already closed.")
  }

  invisible(stream)
}

#' Scan a stream chunk
#'
#' @param stream An open `hs_stream`.
#' @param data A raw vector or string.
#' @param callback Optional function called as
#'   `callback(id, from, to, flags, context)`. Return `TRUE` to stop scanning.
#' @param context Optional object passed to `callback`.
#' @return A data frame of matches when `callback` is `NULL`; otherwise the
#'   number of callback invocations, invisibly.
#' @export
hs_stream_scan <- function(stream, data, callback = NULL, context = NULL) {
  check_stream(stream)

  database <- stream$database
  has_callback <- !is.null(callback)
  callback <- make_match_callback(callback, database)
  matches <- .Call(
    vctrsn_hs_stream_scan,
    stream$ptr,
    database$scratch,
    as_hs_raw(data),
    callback %||% NULL,
    context
  )

  if (has_callback) {
    return(invisible(matches))
  }

  as_match_data_frame(matches, database)
}

#' Close a stream
#'
#' @inheritParams hs_stream_scan
#' @return A data frame of matches found while closing when `callback` is
#'   `NULL`; otherwise the number of callback invocations, invisibly.
#' @export
hs_stream_close <- function(stream, callback = NULL, context = NULL) {
  check_stream(stream)

  database <- stream$database
  has_callback <- !is.null(callback)
  callback <- make_match_callback(callback, database)
  matches <- .Call(
    vctrsn_hs_stream_close,
    stream$ptr,
    database$scratch,
    callback %||% NULL,
    context
  )
  stream$closed <- TRUE

  if (has_callback) {
    return(invisible(matches))
  }

  as_match_data_frame(matches, database)
}
