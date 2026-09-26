skip_if(is.null(vectorscan:::pcre2_info()), "built without PCRE2")
capture_many <- vectorscan:::capture_many

# What base R reports for the same pattern and input, in capture_many()'s
# shape: an unset group (start 0 in regexec()) is NA.
regexec_groups <- function(pattern, x, ncap) {
  m <- regexec(pattern, x, perl = TRUE)
  lapply(seq_len(ncap), function(g) {
    vapply(seq_along(x), function(i) {
      if (is.na(x[[i]]) || m[[i]][[1]] == -1L || m[[i]][[g + 1L]] == 0L) {
        return(NA_character_)
      }
      substr(x[[i]], m[[i]][[g + 1L]],
             m[[i]][[g + 1L]] + attr(m[[i]], "match.length")[[g + 1L]] - 1L)
    }, character(1))
  })
}

test_that("groups, names and non-matches", {
  out <- capture_many("^(?<key>\\w+)=(?<value>\\d*)(;)?$", c("a=1", "b=", "nope", NA, "c=22;"))

  expect_identical(names(out$groups), c("key", "value", ""))
  expect_identical(out$matched, c(TRUE, TRUE, FALSE, NA, TRUE))
  expect_identical(out$groups$key, c("a", "b", NA, NA, "c"))
  expect_identical(out$groups$value, c("1", "", NA, NA, "22"))
  expect_identical(out$groups[[3]], c(NA, NA, NA, NA, ";"))
  expect_identical(out$errors, rep(0L, 5))
})

test_that("UTF-8 text is sliced by bytes and returned as UTF-8", {
  out <- capture_many("(été) (\\d+)", c("un été 2026", "café"))

  expect_identical(out$groups[[1]], c("été", NA))
  expect_identical(Encoding(out$groups[[1]][[1]]), "UTF-8")
  expect_identical(out$groups[[2]], c("2026", NA))
})

test_that("a pattern without groups still reports matches", {
  out <- capture_many("foo", c("foo", "bar"))
  expect_length(out$groups, 0L)
  expect_identical(out$matched, c(TRUE, FALSE))
})

test_that("invalid patterns are reported", {
  expect_error(capture_many("(", "a"), "Invalid pattern")
  expect_error(capture_many(c("a", "b"), "a"), class = "vectorscan_error")
  expect_error(capture_many("a", 1), class = "vectorscan_error")
})

test_that("capture_many() agrees with regexec(perl = TRUE)", {
  set.seed(20260926)
  patterns <- c(
    "(a+)(b*)", "^(\\w+)\\s+(\\d+)", "(x)|(y)", "(?<k>[a-c]{2})(?<v>.)?",
    "([^,]*),([^,]*)", "(\\d{2,3})", "^(a|ab)(c|bcd)?(d*)", "(\\s*)(\\S+)$",
    "(?:(a)|b)+c"
  )
  alphabet <- c(strsplit("abcdxy12 ,", "")[[1]], "é")
  x <- c(NA, "", vapply(1:400, function(i) {
    paste(sample(alphabet, sample(0:14, 1), TRUE), collapse = "")
  }, character(1)))

  for (p in patterns) {
    out <- capture_many(p, x)
    expected_matched <- ifelse(is.na(x), NA, grepl(p, x, perl = TRUE))
    expect_identical(out$matched, expected_matched, info = p)
    expect_identical(
      unname(out$groups),
      regexec_groups(p, x, length(out$groups)),
      info = p
    )
    # a pattern no input matches would test nothing about groups
    expect_true(any(out$matched, na.rm = TRUE), info = p)
  }
})
