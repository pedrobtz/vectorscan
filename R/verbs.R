#' Vectorized matching over a character vector
#'
#' These functions scan every element of a character vector against a set of
#' patterns in one call, in C, reusing one scratch space. They are the
#' R-shaped layer over [hs_scan()]:
#'
#' * `hs_detect()` -- does any pattern match each element? Like [grepl()] for
#'   many patterns at once.
#' * `hs_count()` -- how many matches in each element.
#' * `hs_match()` -- every match, as a data frame with the element, the
#'   pattern, the byte offsets and the matched text.
#' * `hs_extract()` -- the matched text for each element, as a list.
#'
#' `patterns` is either a compiled block-mode [hs_database()] or the patterns
#' themselves, in any form [hs_compile()] accepts (a character vector,
#' possibly named, or a rules data frame). Given patterns, `hs_match()` and
#' `hs_extract()` compile them with [HS_FLAG_SOM_LEFTMOST] so that start
#' offsets, and hence the matched text, are known; pass `som = FALSE` to skip
#' that. Given a database, start offsets exist only for patterns compiled
#' with that flag, and `from` and `match` are `NA` for the others.
#'
#' Offsets are zero-based byte offsets into the UTF-8 encoding of each
#' element: `from` is where the match starts and `to` where it ends, so the
#' match is bytes `from + 1` to `to`. Vectorscan reports every position at
#' which a pattern matches, so `a+` matches three times in `"aaa"` (ending at
#' 1, 2 and 3); use [HS_FLAG_SINGLEMATCH] to report each pattern once per
#' element.
#'
#' `NA` elements give `NA` results.
#'
#' @param patterns A compiled block-mode `hs_database`, or patterns to compile
#'   (see Details).
#' @param x A character vector to scan.
#' @param per_pattern For `hs_detect()` and `hs_count()`: return a matrix with
#'   one column per pattern instead of one value per element.
#' @param som For `hs_match()` and `hs_extract()` when `patterns` are
#'   compiled on the fly: request start-of-match offsets.
#' @return
#' * `hs_detect()`: a logical vector the length of `x`, or with
#'   `per_pattern = TRUE` a logical matrix with a column per pattern.
#' * `hs_count()`: an integer vector, or an integer matrix.
#' * `hs_match()`: a data frame with columns `input` (index into `x`), `id`,
#'   `pattern` (the pattern's name, or the expression if it has none),
#'   `from`, `to` and `match`.
#' * `hs_extract()`: a list the length of `x` of character vectors.
#' @name hs_verbs
#' @examples
#' if (hs_available()) {
#'   x <- c("apple pie", "banana split", NA, "cherry")
#'   rules <- c(fruit = "apple|banana", dessert = "pie|split")
#'
#'   hs_detect(rules, x)
#'   hs_count(rules, x, per_pattern = TRUE)
#'   hs_match(rules, x)
#'   hs_extract(rules, x)
#'
#'   # Compile once, scan many times
#'   db <- hs_compile(rules)
#'   hs_detect(db, x)
#' }
NULL

#' @rdname hs_verbs
#' @export
hs_detect <- function(patterns, x, per_pattern = FALSE) {
  database <- verb_database(patterns, som = FALSE)
  check_verb_input(x)

  if (!isTRUE(per_pattern)) {
    matches <- scan_many(database, x, first_only = TRUE)
    out <- seq_along(x) %in% matches$input
    out[is.na(x)] <- NA
    return(out)
  }

  count_matrix(database, x) > 0L
}

#' @rdname hs_verbs
#' @export
hs_count <- function(patterns, x, per_pattern = FALSE) {
  database <- verb_database(patterns, som = FALSE)
  check_verb_input(x)

  if (!isTRUE(per_pattern)) {
    matches <- scan_many(database, x, first_only = FALSE)
    out <- tabulate(matches$input, nbins = length(x))
    out[is.na(x)] <- NA_integer_
    return(out)
  }

  count_matrix(database, x)
}

#' @rdname hs_verbs
#' @export
hs_match <- function(patterns, x, som = TRUE) {
  database <- verb_database(patterns, som = som)
  check_verb_input(x)

  matches <- scan_many(database, x, first_only = FALSE)
  from <- normalize_match_from(database, matches$id, matches$from)

  data.frame(
    input = matches$input,
    id = matches$id,
    pattern = pattern_labels(database, matches$id),
    from = from,
    to = matches$to,
    match = slice_matches(x, matches$input, from, matches$to),
    stringsAsFactors = FALSE
  )
}

#' @rdname hs_verbs
#' @export
hs_extract <- function(patterns, x, som = TRUE) {
  matches <- hs_match(patterns, x, som = som)

  out <- split(matches$match, factor(matches$input, levels = seq_along(x)))
  out <- unname(out)
  out[is.na(x)] <- list(NA_character_)
  out
}

# -- helpers -----------------------------------------------------------------

verb_database <- function(patterns, som) {
  if (is_hs_database(patterns)) {
    check_database(patterns, compiled = TRUE)
    if (!identical(bitwAnd(patterns$mode, HS_MODE_BLOCK), HS_MODE_BLOCK)) {
      stop_vectorscan(
        "`patterns` must be a block-mode database; use hs_stream_scan() or hs_scan_vector() for the other modes.",
        class = "vectorscan_error_mode"
      )
    }
    return(patterns)
  }

  if (!is.character(patterns) && !is.data.frame(patterns)) {
    stop_vectorscan(
      "`patterns` must be an `hs_database`, a character vector or a rules data frame."
    )
  }

  rules <- normalize_rules(patterns, NULL, NULL)
  flags <- if (is.data.frame(patterns) && "flags" %in% names(patterns)) {
    check_integerish(patterns$flags, "flags")
  } else {
    HS_FLAG_NONE
  }
  if (isTRUE(som)) {
    flags <- bitwOr(flags, HS_FLAG_SOM_LEFTMOST)
  }

  database <- hs_database()
  if (is.data.frame(patterns)) {
    patterns$flags <- flags
    hs_compile(database, patterns)
  } else {
    hs_compile(database, patterns, flags = flags)
  }
  database
}

check_verb_input <- function(x) {
  if (!is.character(x)) {
    stop_vectorscan("`x` must be a character vector.")
  }
  invisible(x)
}

scan_many <- function(database, x, first_only) {
  .Call(vctrsn_hs_scan_many, database$ptr, database$scratch, x, first_only)
}

count_matrix <- function(database, x) {
  matches <- scan_many(database, x, first_only = FALSE)
  ids <- database$pattern_ids
  if (length(ids) == 0L) {
    ids <- sort(unique(matches$id))
  }

  out <- matrix(0L, nrow = length(x), ncol = length(ids))
  if (length(matches$input) > 0L) {
    cell <- cbind(matches$input, match(matches$id, ids))
    counts <- table(factor(cell[, 1], levels = seq_along(x)),
                    factor(cell[, 2], levels = seq_along(ids)))
    out[] <- as.integer(counts)
  }
  out[is.na(x), ] <- NA_integer_
  colnames(out) <- pattern_labels(database, ids)
  out
}

# The pattern's name if it has one, else its expression, else its id (for a
# database whose expressions are unknown, e.g. deserialized).
pattern_labels <- function(database, ids) {
  idx <- match(ids, database$pattern_ids)
  labels <- as.character(ids)
  if (length(database$patterns) == length(database$pattern_ids)) {
    known <- !is.na(idx)
    names <- database$pattern_names[idx[known]]
    exprs <- database$patterns[idx[known]]
    labels[known] <- ifelse(is.na(names), exprs, names)
  }
  labels
}

# Slice each match out of the UTF-8 bytes of its element. NA where the start
# offset is unknown.
slice_matches <- function(x, input, from, to) {
  out <- rep(NA_character_, length(input))
  ok <- !is.na(from)
  if (!any(ok)) {
    return(out)
  }

  # Only the elements that matched are converted to bytes.
  used <- unique(input[ok])
  bytes <- lapply(enc2utf8(x[used]), charToRaw)
  slot <- match(input[ok], used)
  out[ok] <- mapply(
    function(i, start, end) {
      if (end <= start) {
        return("")
      }
      rawToChar(bytes[[i]][(start + 1):end])
    },
    slot, from[ok], to[ok],
    USE.NAMES = FALSE
  )
  Encoding(out) <- "UTF-8"
  out
}
