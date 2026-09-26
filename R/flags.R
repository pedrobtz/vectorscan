#' Flags from letters or names
#'
#' Turns flags written as text into the integer flags [hs_compile()] takes.
#' `hs_compile()` and the verbs call it for flags given as strings, so
#' `flags = "i"` and `flags = HS_FLAG_CASELESS` compile the same database.
#'
#' Each string is either
#'
#' - letters, as after the closing `/` of an expression in Hyperscan's
#'   pattern files (see [hs_read_patterns()]): `i` caseless, `s` dotall,
#'   `m` multiline, `H` single match, `V` allow empty, `8` UTF-8, `W` Unicode
#'   properties, `P` prefilter, `L` leftmost start of match, `C` combination,
#'   `Q` quiet; or
#' - names separated by `|`, `,` or spaces, with or without the `HS_FLAG_`
#'   prefix and in any case: `"caseless|dotall"`, `"HS_FLAG_UTF8, ucp"`.
#'
#' `""` means no flags.
#'
#' @param x A character vector, one string per pattern.
#' @return An integer vector of flags, as long as `x`.
#' @seealso [vectorscan-constants] for the flags themselves.
#' @export
#' @examples
#' hs_flags("i")
#' hs_flags(c("is", "caseless|dotall", "HS_FLAG_SOM_LEFTMOST", ""))
#' identical(hs_flags("i8"), bitwOr(HS_FLAG_CASELESS, HS_FLAG_UTF8))
hs_flags <- function(x) {
  if (!is.character(x)) {
    stop_vectorscan("`x` must be a character vector.")
  }
  if (anyNA(x)) {
    stop_vectorscan("`x` must not contain missing values.")
  }
  vapply(x, parse_flag_string, integer(1), USE.NAMES = FALSE)
}

flag_letters <- c(
  i = "CASELESS",
  s = "DOTALL",
  m = "MULTILINE",
  H = "SINGLEMATCH",
  V = "ALLOWEMPTY",
  "8" = "UTF8",
  W = "UCP",
  P = "PREFILTER",
  L = "SOM_LEFTMOST",
  C = "COMBINATION",
  Q = "QUIET"
)

flag_value <- function(name) {
  get(paste0("HS_FLAG_", name), envir = asNamespace("vectorscan"))
}

parse_flag_string <- function(s) {
  s <- trimws(s)
  if (!nzchar(s)) {
    return(HS_FLAG_NONE)
  }

  letters <- strsplit(s, "", fixed = TRUE)[[1]]
  if (all(letters %in% names(flag_letters))) {
    flag_names <- flag_letters[letters]
  } else {
    flag_names <- toupper(strsplit(s, "[|, ]+")[[1]])
    flag_names <- sub("^HS_FLAG_", "", flag_names[nzchar(flag_names)])
    unknown <- !flag_names %in% c(flag_letters, "NONE")
    if (any(unknown)) {
      stop_vectorscan(
        sprintf(
          "Unknown flag %s in \"%s\". Use letters from \"%s\" or names such as \"caseless|dotall\".",
          paste0("\"", flag_names[unknown], "\"", collapse = ", "),
          s,
          paste(names(flag_letters), collapse = "")
        ),
        class = "vectorscan_error_flags"
      )
    }
  }
  Reduce(bitwOr, lapply(unique(flag_names), flag_value), HS_FLAG_NONE)
}

# Flags given to hs_compile() or in a rules data frame: integers, or strings
# for hs_flags().
normalize_flags <- function(flags, name = "flags") {
  if (is.character(flags)) {
    return(hs_flags(flags))
  }
  flags <- check_integerish(flags, name)
  check_nonnegative(flags, name)
  flags
}
