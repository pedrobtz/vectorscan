make_match_callback <- function(callback, database) {
  if (is.null(callback)) {
    return(NULL)
  }

  if (!is.function(callback)) {
    stop_vectorscan("`callback` must be a function or `NULL`.")
  }

  force(callback)
  force(database)
  function(id, from, to, flags, context) {
    from <- normalize_match_from(database, id, from)
    callback(id, from, to, flags, context)
  }
}

normalize_match_from <- function(database, ids, from) {
  if (length(ids) == 0L || length(database$pattern_ids) == 0L) {
    return(from)
  }

  idx <- match(ids, database$pattern_ids)
  known <- !is.na(idx)
  has_som <- rep(FALSE, length(ids))
  has_som[known] <- bitwAnd(
    database$pattern_flags[idx[known]],
    HS_FLAG_SOM_LEFTMOST
  ) !=
    0L

  from[!has_som] <- NA_real_
  from
}

as_match_data_frame <- function(matches, database) {
  out <- data.frame(
    id = as.integer(matches$id),
    from = as.numeric(matches$from),
    to = as.numeric(matches$to),
    flags = as.integer(matches$flags)
  )
  out$from <- normalize_match_from(database, out$id, out$from)
  out
}

#' Scan one block of data
#'
#' @param database A compiled block-mode `hs_database`.
#' @param data A raw vector or string.
#' @param callback Optional function called as
#'   `callback(id, from, to, flags, context)`. Return `TRUE` to stop scanning.
#' @param context Optional object passed to `callback`.
#' @return A data frame of matches when `callback` is `NULL`; otherwise the
#'   number of callback invocations, invisibly.
#' @export
#' @examples
#' if (hs_available()) {
#'   db <- hs_database()
#'   hs_compile(db, "foo")
#'   hs_scan(db, "foo")
#' }
hs_scan <- function(database, data, callback = NULL, context = NULL) {
  check_database(database, compiled = TRUE)

  has_callback <- !is.null(callback)
  callback <- make_match_callback(callback, database)
  matches <- .Call(
    vctrsn_hs_scan,
    database$ptr,
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

#' Scan vectored data
#'
#' @inheritParams hs_scan
#' @param data A raw vector, character vector, or list of raw vectors/strings.
#' @return A data frame of matches when `callback` is `NULL`; otherwise the
#'   number of callback invocations, invisibly.
#' @export
#' @examples
#' if (hs_available()) {
#'   db <- hs_database(HS_MODE_VECTORED)
#'   hs_compile(db, "foobar")
#'   hs_scan_vector(db, c("foo", "bar"))
#' }
hs_scan_vector <- function(database, data, callback = NULL, context = NULL) {
  check_database(database, compiled = TRUE)

  has_callback <- !is.null(callback)
  callback <- make_match_callback(callback, database)
  matches <- .Call(
    vctrsn_hs_scan_vector,
    database$ptr,
    database$scratch,
    as_hs_raw_list(data),
    callback %||% NULL,
    context
  )

  if (has_callback) {
    return(invisible(matches))
  }

  as_match_data_frame(matches, database)
}
