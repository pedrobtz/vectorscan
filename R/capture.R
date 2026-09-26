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
#' @section Several formats:
#' `pattern` can also be a character vector of formats, typically named, for
#' input that mixes them (log lines from several services, say). Each element
#' is captured by the first format, in order, that matches it. The result
#' gains a first column, `pattern`, with the name of that format (or the
#' expression, for an unnamed one), and has one column per group name across
#' all formats: groups with the same name share a column, and a format that
#' lacks a group leaves it `NA`.
#'
#' Formats are routed with Vectorscan: one pass over `x` finds, for each
#' element, the formats that can match it (Vectorscan's prefilter mode, which
#' never misses a match), and PCRE2 then runs only there. The result is the
#' same as trying every format on every element in order, but with many
#' formats it is several times faster. A format Vectorscan cannot compile
#' even in prefilter mode (PCRE2's branch reset `(?|...)`, for example) is
#' simply tried on every element that is still unmatched.
#'
#' @section Untrusted input:
#' Some patterns can take exponential time on some inputs (nested
#' quantifiers such as `(a+)+$`, for example). `match_limit` bounds the work
#' PCRE2 may do per element, and `depth_limit` its backtracking memory (in the
#' interpreter; the just-in-time compiled code has its own fixed stack, and an
#' element that exhausts it is retried in the interpreter). An element that
#' hits a limit gives an `NA` row and counts towards the warning, so one
#' pathological line cannot stall or abort a scan. Both default to PCRE2's
#' own defaults (a match limit of 10,000,000).
#'
#' Elements that do not match, and `NA` elements, give a row of `NA`. A group
#' that does not take part in the match (an optional group, or a branch not
#' taken) is `NA`, where `utils::strcapture()` gives `""`. An element PCRE2
#' cannot match at all (for example invalid UTF-8) also gives an `NA` row, and
#' `hs_capture()` warns once with the number of such elements.
#'
#' @param pattern A single regular expression with capture groups, a
#'   character vector of formats (see "Several formats"), or either compiled
#'   with `hs_capture_compile()` to reuse across calls.
#' @param x A character vector.
#' @param proto Optional data frame (typically with zero rows) giving the
#'   names and types of the columns, as in [utils::strcapture()]. It must have
#'   one column per capture group; for several formats, one column per group
#'   name, matched by name.
#' @param match_limit,depth_limit Optional positive whole numbers: PCRE2's
#'   match limit and depth limit per element (see "Untrusted input"). `NULL`
#'   keeps PCRE2's defaults.
#' @param jit For `hs_capture_compile()`: use PCRE2's just-in-time compiler
#'   when available. `FALSE` runs PCRE2's interpreter, which is slower but
#'   gives the same results.
#' @return A data frame with `length(x)` rows and one column per capture
#'   group, plus a `pattern` column first for several formats.
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
#'
#' # Several formats
#' mixed <- c("GET /index.html 200", "user=ada action=login", "GET /api 500")
#' hs_capture(c(
#'   http = "^(?<method>[A-Z]+) (?<path>\\S+) (?<status>\\d{3})$",
#'   audit = "^user=(?<user>\\w+) action=(?<action>\\w+)$"
#' ), mixed)
hs_capture <- function(
  pattern,
  x,
  proto = NULL,
  match_limit = NULL,
  depth_limit = NULL
) {
  if (!inherits(pattern, c("hs_capture_pattern", "hs_capture_rules"))) {
    pattern <- hs_capture_compile(pattern)
  }
  if (!is.character(x)) {
    stop_vectorscan("`x` must be a character vector.")
  }
  limits <- capture_limits(match_limit, depth_limit)
  if (inherits(pattern, "hs_capture_rules")) {
    return(capture_rules(pattern, x, proto, limits))
  }
  ncap <- length(pattern$names)
  if (!is.null(proto)) {
    if (!is.data.frame(proto) && !is.list(proto)) {
      stop_vectorscan("`proto` must be a data frame or list.")
    }
    if (length(proto) != ncap) {
      stop_vectorscan(sprintf(
        "`pattern` has %d capture group%s but `proto` has %d column%s.",
        ncap,
        if (ncap == 1L) "" else "s",
        length(proto),
        if (length(proto) == 1L) "" else "s"
      ))
    }
  }

  out <- .Call(
    vctrsn_pcre2_capture_many,
    pattern$ptr,
    x,
    limits$match_limit,
    limits$depth_limit
  )
  warn_capture_errors(sum(out$errors != 0L), out$errors[out$errors != 0L][1])

  columns <- out$groups
  if (is.null(proto)) {
    names(columns) <- capture_column_names(pattern$names)
    return(as.data.frame(columns, optional = TRUE, stringsAsFactors = FALSE))
  }
  conform_to_proto(columns, proto)
}

#' @rdname hs_capture
#' @export
hs_capture_compile <- function(pattern, jit = TRUE) {
  if (is.character(pattern) && length(pattern) > 1L) {
    return(compile_capture_rules(pattern, jit))
  }
  compiled <- pcre2_compile_pattern(pattern, jit)
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
    n,
    if (n == 1L) "" else "s",
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

# -- rule sets (capture-groups plan, M4) ---------------------------------------

# Several formats, each line captured by the first rule, in order, that
# matches it. Vectorscan, compiled in prefilter mode, finds each line's
# candidate rules in one pass; PCRE2 then runs only on candidates. Prefilter
# mode reports a superset of PCRE2's matches, so the result is exactly that
# of trying every rule on every line in order. A rule Vectorscan cannot
# compile even in prefilter mode is tried on every remaining line.
compile_capture_rules <- function(patterns, jit = TRUE) {
  if (anyNA(patterns)) {
    stop_vectorscan("`pattern` must not contain missing values.")
  }
  labels <- names(patterns)
  if (is.null(labels)) {
    labels <- patterns
  } else {
    labels[is.na(labels) | labels == ""] <- patterns[
      is.na(labels) | labels == ""
    ]
  }
  patterns <- unname(patterns)

  compiled <- lapply(patterns, pcre2_compile_pattern, jit = jit)
  group_names <- lapply(compiled, function(cmp) capture_column_names(cmp$names))
  columns <- unique(unlist(group_names))
  if ("pattern" %in% columns) {
    stop_vectorscan("A capture group cannot be called `pattern` in a rule set.")
  }

  prefilter_flags <- Reduce(
    bitwOr,
    c(
      HS_FLAG_PREFILTER,
      HS_FLAG_SINGLEMATCH,
      HS_FLAG_UTF8,
      HS_FLAG_ALLOWEMPTY
    )
  )
  prefiltered <- vapply(
    patterns,
    function(p) {
      ok <- tryCatch(
        {
          hs_compile(hs_database(), p, flags = prefilter_flags)
          TRUE
        },
        error = function(e) FALSE
      )
      ok
    },
    logical(1),
    USE.NAMES = FALSE
  )

  prefilter <- NULL
  if (any(prefiltered) && isTRUE(hs_available())) {
    prefilter <- hs_database()
    hs_compile(
      prefilter,
      patterns[prefiltered],
      ids = which(prefiltered) - 1L,
      flags = prefilter_flags
    )
  }

  structure(
    list(
      patterns = patterns,
      labels = unname(labels),
      compiled = compiled,
      group_names = group_names,
      columns = columns,
      prefiltered = prefiltered & !is.null(prefilter),
      prefilter = prefilter
    ),
    class = "hs_capture_rules"
  )
}

capture_rules <- function(rules, x, proto, limits) {
  n <- length(x)
  if (!is.null(proto)) {
    if (
      !setequal(names(proto), rules$columns) ||
        length(proto) != length(rules$columns)
    ) {
      stop_vectorscan(sprintf(
        "`proto` must have one column per group name in the rules: %s.",
        paste(rules$columns, collapse = ", ")
      ))
    }
  }

  label <- rep(NA_character_, n)
  columns <- rep(list(rep(NA_character_, n)), length(rules$columns))
  names(columns) <- rules$columns
  unassigned <- !is.na(x)
  errored <- rep(FALSE, n)
  first_error <- NA_integer_

  # Candidate lines per rule from one Vectorscan pass. The prefilter is
  # compiled with HS_FLAG_SINGLEMATCH, so each rule reports a line at most
  # once and the candidates need no de-duplication.
  candidates <- vector("list", length(rules$patterns))
  if (!is.null(rules$prefilter)) {
    hits <- scan_many(rules$prefilter, x, first_only = FALSE)
    candidates <- split(
      hits$input,
      factor(hits$id + 1L, levels = seq_along(rules$patterns))
    )
  }

  # Each rule touches only its own candidates, so the cost follows the
  # number of candidate lines, not rules x lines.
  for (r in seq_along(rules$patterns)) {
    if (rules$prefiltered[[r]]) {
      idx <- candidates[[r]]
      if (length(idx) == 0L) {
        next
      }
      idx <- idx[unassigned[idx]]
    } else {
      idx <- which(unassigned)
    }
    if (length(idx) == 0L) {
      next
    }

    out <- .Call(
      vctrsn_pcre2_capture_many,
      rules$compiled[[r]]$ptr,
      x[idx],
      limits$match_limit,
      limits$depth_limit
    )
    bad <- out$errors != 0L
    if (any(bad)) {
      errored[idx[bad]] <- TRUE
      if (is.na(first_error)) first_error <- out$errors[bad][[1]]
    }
    hit <- which(out$matched %in% TRUE)
    if (length(hit) == 0L) {
      next
    }
    rows <- idx[hit]
    label[rows] <- rules$labels[[r]]
    for (g in seq_along(out$groups)) {
      column <- rules$group_names[[r]][[g]]
      columns[[column]][rows] <- out$groups[[g]][hit]
    }
    unassigned[rows] <- FALSE
  }

  warn_capture_errors(sum(errored & is.na(label)), first_error)

  if (!is.null(proto)) {
    columns <- as.list(conform_to_proto(columns[names(proto)], proto))
  }
  # One list, so that rules without groups and zero-length input still give
  # length(x) rows.
  as.data.frame(
    c(list(pattern = label), columns),
    optional = TRUE,
    stringsAsFactors = FALSE
  )
}

#' @export
print.hs_capture_rules <- function(x, ...) {
  cat(sprintf(
    "<hs_capture_rules: %d rules, %d columns (%s), %d prefiltered by Vectorscan>\n",
    length(x$patterns),
    length(x$columns),
    paste(x$columns, collapse = ", "),
    sum(x$prefiltered)
  ))
  invisible(x)
}

# -- engine (capture-groups plan, M2) -----------------------------------------

pcre2_compile_pattern <- function(pattern, jit = TRUE) {
  if (!is.character(pattern) || length(pattern) != 1L || is.na(pattern)) {
    stop_vectorscan("`pattern` must be a single string.")
  }
  .Call(vctrsn_pcre2_compile, enc2utf8(pattern), isTRUE(jit))
}

# NA_integer_ keeps PCRE2's default for a limit.
capture_limits <- function(match_limit, depth_limit) {
  limit <- function(value, name) {
    if (is.null(value)) {
      return(NA_integer_)
    }
    value <- check_integerish(value, name, len = 1L)
    if (value < 1L) {
      stop_vectorscan(sprintf("`%s` must be a positive whole number.", name))
    }
    value
  }
  list(
    match_limit = limit(match_limit, "match_limit"),
    depth_limit = limit(depth_limit, "depth_limit")
  )
}

# One warning for all elements PCRE2 gave up on, naming the first error.
warn_capture_errors <- function(failed, first_error) {
  if (failed == 0L) {
    return(invisible())
  }
  warning(
    sprintf(
      "%d element%s could not be matched (%s); %s NA.",
      failed,
      if (failed == 1L) "" else "s",
      .Call(vctrsn_pcre2_error_message, first_error),
      if (failed == 1L) "its row is" else "their rows are"
    ),
    call. = FALSE
  )
}

# list(matched, groups, errors) for every element of `x`: see
# vctrsn_pcre2_capture_many() in src/capture.c.
capture_many <- function(pattern, x) {
  if (!is.character(x)) {
    stop_vectorscan("`x` must be a character vector.")
  }
  compiled <- pcre2_compile_pattern(pattern)
  out <- .Call(
    vctrsn_pcre2_capture_many,
    compiled$ptr,
    x,
    NA_integer_,
    NA_integer_
  )
  names(out$groups) <- compiled$names
  out
}
