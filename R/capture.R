#' Capture groups into a data frame
#'
#' `hs_capture()` matches a regular expression with capture groups against
#' every element of a character vector and returns the groups as the columns
#' of a data frame, one row per element: what [utils::strcapture()] does, in
#' C, about 20 times faster on large inputs.
#'
#' The pattern is a PCRE2 regular expression, compiled as base R's
#' `regexec(perl = TRUE)` compiles it, so the two agree on what matches.
#' Unlike the other `hs_*` functions it does not run on Vectorscan, whose
#' engine cannot report groups.
#'
#' Columns are named after `proto`, else after named groups
#' (`(?<level>...)`), else `V1`, `V2`, ... With `proto`, each column is
#' converted to the type of the matching `proto` column as
#' `utils::strcapture()` converts it (`as.integer()` for an integer column,
#' and so on); without it every column is character.
#'
#' Elements that do not match, and `NA` elements, give a row of `NA`. A group
#' that does not take part in the match (an optional group, or a branch not
#' taken) is `NA`, where `utils::strcapture()` gives `""`. An element PCRE2
#' cannot match at all (for example invalid UTF-8) also gives an `NA` row, and
#' `hs_capture()` warns once with the number of such elements.
#'
#' @param pattern A single regular expression with capture groups, or a
#'   pattern compiled with `hs_capture_compile()` to reuse across calls.
#' @param x A character vector.
#' @param proto Optional data frame (typically with zero rows) giving the
#'   names and types of the columns, as in [utils::strcapture()]. It must have
#'   one column per capture group.
#' @return A data frame with `length(x)` rows and one column per capture
#'   group.
#' @seealso [hs_detect()][hs_verbs] and friends for matching many patterns at once.
#' @export
#' @examples
#' lines <- c(
#'   "2026-09-26 10:15:02 [INFO] api.server:42 - listening",
#'   "not a log line",
#'   "2026-09-26 10:16:00 [ERROR] auth.jwt:77 - token expired"
#' )
#' fmt <- "^(?<time>\\S+ \\S+) \\[(?<level>\\w+)\\] (?<location>[^:]+):(?<line>\\d+) - (?<text>.*)$"
#' hs_capture(fmt, lines)
#'
#' # With types, as utils::strcapture()
#' proto <- data.frame(time = character(), level = character(),
#'                     location = character(), line = integer(), text = character())
#' str(hs_capture(fmt, lines, proto))
#'
#' # Compile once, reuse
#' compiled <- hs_capture_compile(fmt)
#' compiled
#' hs_capture(compiled, lines)
hs_capture <- function(pattern, x, proto = NULL) {
  if (!inherits(pattern, "hs_capture_pattern")) {
    pattern <- hs_capture_compile(pattern)
  }
  if (!is.character(x)) {
    stop_vectorscan("`x` must be a character vector.")
  }
  ncap <- length(pattern$names)
  if (!is.null(proto)) {
    if (!is.data.frame(proto) && !is.list(proto)) {
      stop_vectorscan("`proto` must be a data frame or list.")
    }
    if (length(proto) != ncap) {
      stop_vectorscan(sprintf(
        "`pattern` has %d capture group%s but `proto` has %d column%s.",
        ncap, if (ncap == 1L) "" else "s",
        length(proto), if (length(proto) == 1L) "" else "s"
      ))
    }
  }

  out <- .Call(vctrsn_pcre2_capture_many, pattern$ptr, x)

  failed <- sum(out$errors != 0L)
  if (failed > 0L) {
    warning(sprintf(
      "%d element%s could not be matched (PCRE2 error %d); %s NA.",
      failed, if (failed == 1L) "" else "s",
      out$errors[out$errors != 0L][[1]],
      if (failed == 1L) "its row is" else "their rows are"
    ), call. = FALSE)
  }

  columns <- out$groups
  if (is.null(proto)) {
    names(columns) <- capture_column_names(pattern$names)
    return(as.data.frame(columns, optional = TRUE, stringsAsFactors = FALSE))
  }
  conform_to_proto(columns, proto)
}

#' @rdname hs_capture
#' @export
hs_capture_compile <- function(pattern) {
  compiled <- pcre2_compile_pattern(pattern)
  structure(
    list(
      pattern = pattern,
      ptr = compiled$ptr,
      names = compiled$names,
      jit = compiled$jit
    ),
    class = "hs_capture_pattern"
  )
}

#' @export
print.hs_capture_pattern <- function(x, ...) {
  n <- length(x$names)
  cat(sprintf(
    "<hs_capture_pattern: %d group%s%s, %s>\n",
    n, if (n == 1L) "" else "s",
    if (any(nzchar(x$names))) {
      paste0(" (", paste(capture_column_names(x$names), collapse = ", "), ")")
    } else {
      ""
    },
    if (isTRUE(x$jit)) "JIT" else "interpreted"
  ))
  cat(sprintf("  %s\n", x$pattern))
  invisible(x)
}

# Group names, with V<k> for unnamed groups.
capture_column_names <- function(names) {
  unnamed <- !nzchar(names)
  names[unnamed] <- paste0("V", seq_along(names))[unnamed]
  names
}

# Column types and names from `proto`, as utils::strcapture() does (its
# conformToProto() is not exported).
conform_to_proto <- function(columns, proto) {
  out <- lapply(seq_along(proto), function(i) {
    if (isS4(proto[[i]])) {
      methods::as(columns[[i]], class(proto[[i]]))
    } else {
      convert <- match.fun(paste0("as.", class(proto[[i]])[[1]]))
      convert(columns[[i]])
    }
  })
  names(out) <- names(proto)
  as.data.frame(out, optional = TRUE, stringsAsFactors = FALSE)
}

# -- engine (capture-groups plan, M2) -----------------------------------------

pcre2_compile_pattern <- function(pattern) {
  if (!is.character(pattern) || length(pattern) != 1L || is.na(pattern)) {
    stop_vectorscan("`pattern` must be a single string.")
  }
  .Call(vctrsn_pcre2_compile, enc2utf8(pattern))
}

# list(matched, groups, errors) for every element of `x`: see
# vctrsn_pcre2_capture_many() in src/capture.c.
capture_many <- function(pattern, x) {
  if (!is.character(x)) {
    stop_vectorscan("`x` must be a character vector.")
  }
  compiled <- pcre2_compile_pattern(pattern)
  out <- .Call(vctrsn_pcre2_capture_many, compiled$ptr, x)
  names(out$groups) <- compiled$names
  out
}
