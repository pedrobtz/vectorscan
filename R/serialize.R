#' Serialize a database
#'
#' The bytes are exactly what Vectorscan's `hs_serialize_database()`
#' produces, so they can be deserialized by any compatible Vectorscan or
#' Hyperscan build. The pattern ids and flags, which Vectorscan does not
#' store, are attached as the attributes `hs_pattern_ids` and
#' `hs_pattern_flags`; [hs_deserialize()] uses them to report `from = NA` for
#' patterns compiled without [HS_FLAG_SOM_LEFTMOST], as the original database
#' does.
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
  bytes <- .Call(vctrsn_hs_serialize, database$ptr)
  attr(bytes, "hs_pattern_ids") <- database$pattern_ids
  attr(bytes, "hs_pattern_flags") <- database$pattern_flags
  bytes
}

#' Deserialize a database
#'
#' The mode is read from the database itself. Pattern ids and flags come from
#' the attributes [hs_serialize()] attaches; without them (bytes from another
#' tool, or with the attributes dropped) `from` is reported as Vectorscan
#' gives it, which is `0` for patterns compiled without
#' [HS_FLAG_SOM_LEFTMOST].
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
  database$mode <- mode_from_info(.Call(vctrsn_hs_info, database$ptr))

  ids <- attr(bytes, "hs_pattern_ids", exact = TRUE)
  flags <- attr(bytes, "hs_pattern_flags", exact = TRUE)
  if (is.integer(ids) && is.integer(flags) && length(ids) == length(flags)) {
    database$pattern_ids <- ids
    database$pattern_flags <- flags
  }

  database
}

# hs_database_info() reports e.g. "Version: 5.4.13 Features: AVX2 Mode: STREAM".
mode_from_info <- function(info) {
  mode <- regmatches(info, regexpr("Mode: [A-Z]+", info))
  switch(
    sub("Mode: ", "", mode),
    BLOCK = HS_MODE_BLOCK,
    STREAM = HS_MODE_STREAM,
    VECTORED = HS_MODE_VECTORED,
    NA_integer_
  )
}

#' Save a serialized database
#'
#' Writes the database together with its pattern ids and flags, so that
#' [hs_load()] restores it exactly. The file starts with the 8-byte tag
#' `VSCANRDB`, a format version and the pattern metadata, followed by the
#' bytes [hs_serialize()] returns.
#'
#' @inheritParams hs_serialize
#' @param path File path to write.
#' @return `path`, invisibly.
#' @export
hs_save <- function(database, path) {
  bytes <- hs_serialize(database)
  ids <- attr(bytes, "hs_pattern_ids", exact = TRUE)
  flags <- attr(bytes, "hs_pattern_flags", exact = TRUE)

  con <- file(path, "wb")
  on.exit(close(con), add = TRUE)
  writeBin(save_magic, con)
  writeBin(c(save_version, length(ids)), con, size = 4L, endian = "little")
  writeBin(c(ids, flags), con, size = 4L, endian = "little")
  writeBin(as.vector(bytes), con)
  invisible(path)
}

#' Load a serialized database
#'
#' Reads files written by [hs_save()], and also plain Vectorscan or Hyperscan
#' serialized databases (for which `from` behaves as described in
#' [hs_deserialize()]).
#'
#' @param path File path to read.
#' @return A compiled `hs_database` object.
#' @export
hs_load <- function(path) {
  bytes <- readBin(path, what = "raw", n = file.info(path)$size)
  if (length(bytes) < 8L || !identical(bytes[1:8], save_magic)) {
    return(hs_deserialize(bytes))
  }

  con <- rawConnection(bytes[-(1:8)])
  on.exit(close(con), add = TRUE)
  header <- readBin(con, "integer", n = 2L, size = 4L, endian = "little")
  if (length(header) != 2L || header[[1]] != save_version) {
    stop_vectorscan(sprintf(
      "`path` is a vectorscan database file of an unsupported version (%s).",
      if (length(header)) header[[1]] else "truncated"
    ))
  }
  # Check the pattern count against the file size before reading, so a
  # corrupt count cannot ask for a huge allocation.
  n <- header[[2]]
  header_size <- 8 + 4 * (2 + 2 * as.numeric(n))
  if (is.na(n) || n < 0L || header_size > length(bytes)) {
    stop_vectorscan("`path` is a truncated vectorscan database file.")
  }
  meta <- readBin(con, "integer", n = 2L * n, size = 4L, endian = "little")
  payload <- bytes[-seq_len(header_size)]

  attr(payload, "hs_pattern_ids") <- meta[seq_len(n)]
  attr(payload, "hs_pattern_flags") <- meta[n + seq_len(n)]
  hs_deserialize(payload)
}

save_magic <- charToRaw("VSCANRDB")
save_version <- 1L
