#' Serialize a database
#'
#' @param database A compiled `hs_database`.
#' @return A raw vector containing the serialized database.
#' @export
#' @examples
#' if (hs_available()) {
#'   db <- hs_database()
#'   hs_compile(db, "foo")
#'   bytes <- hs_serialize(db)
#'   restored <- hs_deserialize(bytes)
#'   hs_scan(restored, "foo")
#' }
hs_serialize <- function(database) {
  check_database(database, compiled = TRUE)
  .Call(vctrsn_hs_serialize, database$ptr)
}

#' Deserialize a database
#'
#' @param bytes A raw vector produced by `hs_serialize()`.
#' @return A compiled `hs_database` object.
#' @export
hs_deserialize <- function(bytes) {
  if (!is.raw(bytes)) {
    stop_vectorscan("`bytes` must be a raw vector.")
  }

  compiled <- .Call(
    vctrsn_hs_deserialize,
    bytes
  )

  database <- new_hs_database()
  database$ptr <- compiled$database
  database$scratch <- compiled$scratch
  database
}

#' Save a serialized database
#'
#' @inheritParams hs_serialize
#' @param path File path to write.
#' @return `path`, invisibly.
#' @export
hs_save <- function(database, path) {
  bytes <- hs_serialize(database)
  writeBin(bytes, path)
  invisible(path)
}

#' Load a serialized database
#'
#' @param path File path to read.
#' @return A compiled `hs_database` object.
#' @export
hs_load <- function(path) {
  hs_deserialize(readBin(path, what = "raw", n = file.info(path)$size))
}
