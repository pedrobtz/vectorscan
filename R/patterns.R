#' Read a Hyperscan pattern file
#'
#' Reads patterns in the format of Hyperscan's own tools (`hsbench`,
#' `hscollider`, `simplegrep`'s signature files): one pattern per line,
#' written `id:/regex/flags`, optionally followed by extended parameters in
#' braces. The result is a rules data frame that [hs_compile()] and the verbs
#' take as they are.
#'
#' ```
#' # Comments and blank lines are skipped
#' 1:/foo(bar)?/i
#' 2:/^GET \/index\.html/sm
#' 3:/abc/{edit_distance=1}
#' 4:/[0-9]{4}-[0-9]{2}/L{min_offset=10,max_offset=200}
#' ```
#'
#' The regex runs from the first `/` after the id to the last `/` on the
#' line, so it may contain `/` itself. The flags are the letters of
#' [hs_flags()]; `O`, which Hyperscan's tools use for ordering, is accepted
#' and ignored. The extended parameters are those of [hs_ext()].
#'
#' @param file A path or a connection, as for [readLines()]. The file is read
#'   as UTF-8.
#' @return A data frame with columns `id` (integer), `pattern` (character)
#'   and `flags` (integer), plus an `ext` list column of [hs_ext()] objects
#'   (`NULL` where a line has none) when any line has extended parameters.
#' @export
#' @examples
#' rules <- hs_read_patterns(textConnection(c(
#'   "# HTTP methods",
#'   "10:/^(GET|POST) /",
#'   "11:/error/i",
#'   "12:/timeout/{edit_distance=1}"
#' )))
#' rules
#' if (hs_available()) {
#'   hs_match(rules, c("GET /", "ERROR: timout"))
#' }
hs_read_patterns <- function(file) {
  lines <- readLines(file, warn = FALSE, encoding = "UTF-8")
  lines <- sub("\r$", "", lines)
  line_no <- seq_along(lines)
  keep <- nzchar(trimws(lines)) & !startsWith(lines, "#")
  lines <- lines[keep]
  line_no <- line_no[keep]

  n <- length(lines)
  ids <- integer(n)
  patterns <- character(n)
  flags <- integer(n)
  ext <- vector("list", n)

  for (i in seq_len(n)) {
    parsed <- parse_pattern_line(lines[[i]], line_no[[i]])
    ids[[i]] <- parsed$id
    patterns[[i]] <- parsed$pattern
    flags[[i]] <- parsed$flags
    if (!is.null(parsed$ext)) {
      ext[i] <- list(parsed$ext)
    }
  }

  rules <- data.frame(
    id = ids,
    pattern = patterns,
    flags = flags,
    stringsAsFactors = FALSE
  )
  if (!all(vapply(ext, is.null, logical(1)))) {
    rules$ext <- ext
  }
  rules
}

parse_pattern_line <- function(line, line_no) {
  fail <- function(what) {
    stop_vectorscan(
      sprintf("Line %d of the pattern file: %s\n  %s", line_no, what, line),
      class = "vectorscan_error_pattern_file"
    )
  }

  colon <- regexpr(":", line, fixed = TRUE)
  if (colon < 0L) {
    fail("expected `id:/regex/flags`.")
  }
  id <- trimws(substr(line, 1L, colon - 1L))
  if (!grepl("^[0-9]+$", id) || as.numeric(id) > .Machine$integer.max) {
    fail(sprintf("the id \"%s\" is not a non-negative integer.", id))
  }

  rest <- substr(line, colon + 1L, nchar(line))
  slashes <- gregexpr("/", rest, fixed = TRUE)[[1]]
  if (!startsWith(rest, "/") || length(slashes) < 2L) {
    fail("the regex must be written between slashes, as in `1:/foo/i`.")
  }
  last <- slashes[[length(slashes)]]
  pattern <- substr(rest, 2L, last - 1L)
  tail <- substr(rest, last + 1L, nchar(rest))

  parts <- regmatches(tail, regexec("^([A-Za-z0-9]*)(\\{(.*)\\})?$", tail))[[1]]
  if (length(parts) == 0L) {
    fail(sprintf("cannot read the flags \"%s\".", tail))
  }
  letters <- strsplit(parts[[2]], "", fixed = TRUE)[[1]]
  letters <- letters[letters != "O"]
  bad <- setdiff(letters, names(flag_letters))
  if (length(bad) > 0L) {
    fail(sprintf("unknown flag %s.", paste0("\"", bad, "\"", collapse = ", ")))
  }

  ext <- NULL
  if (nzchar(parts[[3]])) {
    ext <- parse_ext_params(parts[[4]], fail)
  }

  list(
    id = as.integer(id),
    pattern = pattern,
    flags = hs_flags(paste(letters, collapse = "")),
    ext = ext
  )
}

parse_ext_params <- function(text, fail) {
  keys <- c(
    "min_offset",
    "max_offset",
    "min_length",
    "edit_distance",
    "hamming_distance"
  )
  params <- list()
  for (item in strsplit(text, ",", fixed = TRUE)[[1]]) {
    kv <- regmatches(item, regexec("^ *([a-z_]+)=([0-9]+) *$", item))[[1]]
    if (length(kv) == 0L || !kv[[2]] %in% keys) {
      fail(sprintf("cannot read the extended parameter \"%s\".", trimws(item)))
    }
    params[[kv[[2]]]] <- as.numeric(kv[[3]])
  }
  do.call(hs_ext, params)
}
