skip_if(is.null(vectorscan:::pcre2_info()), "built without PCRE2")

rules <- c(
  http = "^(?<method>[A-Z]+) (?<path>\\S+) (?<status>\\d{3})$",
  audit = "^user=(?<user>\\w+) action=(?<action>\\w+)$",
  kv = "^(?<key>\\w+)=(?<value>\\S*)$"
)

# Every rule on every element, in order, without Vectorscan.
naive <- function(rules, x) {
  columns <- unique(unlist(lapply(rules, function(p) {
    vectorscan:::capture_column_names(vectorscan:::pcre2_compile_pattern(p)$names)
  })))
  out <- data.frame(pattern = rep(NA_character_, length(x)))
  for (col in columns) out[[col]] <- NA_character_
  labels <- if (is.null(names(rules))) rules else names(rules)
  labels[labels == ""] <- rules[labels == ""]
  for (r in seq_along(rules)) {
    left <- which(is.na(out$pattern) & !is.na(x))
    if (!length(left)) next
    got <- vectorscan:::capture_many(rules[[r]], x[left])
    hit <- which(got$matched %in% TRUE)
    names <- vectorscan:::capture_column_names(names(got$groups))
    out$pattern[left[hit]] <- labels[[r]]
    for (g in seq_along(got$groups)) out[[names[[g]]]][left[hit]] <- got$groups[[g]][hit]
  }
  out
}

test_that("each element is captured by the first matching format", {
  x <- c("GET /index.html 200", "user=ada action=login", "colour=blue",
         "user=bob", NA, "POST /api 500")
  out <- hs_capture(rules, x)

  expect_named(out, c("pattern", "method", "path", "status", "user", "action", "key", "value"))
  expect_identical(out$pattern, c("http", "audit", "kv", "kv", NA, "http"))
  expect_identical(out$status, c("200", NA, NA, NA, NA, "500"))
  expect_identical(out$user, c(NA, "ada", NA, NA, NA, NA))
  expect_identical(out$key, c(NA, NA, "colour", "user", NA, NA))
})

test_that("rule sets agree with trying every rule in order", {
  set.seed(7)
  make <- function() switch(sample(4, 1),
    sprintf("%s /%s %d", sample(c("GET", "PUT"), 1), paste(sample(letters, 3), collapse = ""), sample(100:599, 1)),
    sprintf("user=%s action=%s", sample(c("ada", "bob"), 1), sample(c("login", "logout"), 1)),
    sprintf("%s=%s", sample(letters, 1), sample(c("", "1", "x y"), 1)),
    paste(sample(c(letters, " ", "="), 12, TRUE), collapse = "")
  )
  x <- c(NA, replicate(2000, make()))
  # Also a rule Vectorscan cannot prefilter (branch reset), and unnamed groups.
  rules2 <- c(rules, reset = "^(?|(\\d+)|([a-z]+))$", "^(\\w) (\\w)")

  expect_identical(hs_capture(rules2, x), naive(rules2, x))
  compiled <- hs_capture_compile(rules2)
  expect_identical(compiled$prefiltered, c(TRUE, TRUE, TRUE, FALSE, TRUE))
  expect_output(print(compiled), "5 rules")
})

test_that("shared group names share a column; proto types by name", {
  x <- c("a=1", "b:2")
  two <- c(eq = "^(?<k>\\w)=(?<v>\\d)$", colon = "^(?<k>\\w):(?<v>\\d)$")
  out <- hs_capture(two, x, proto = data.frame(v = integer(), k = character()))

  expect_named(out, c("pattern", "v", "k"))
  expect_identical(out$v, c(1L, 2L))
  expect_identical(out$k, c("a", "b"))
  expect_error(hs_capture(two, x, proto = data.frame(k = character())), class = "vectorscan_error")
})

test_that("rules without groups, and zero-length input", {
  out <- hs_capture(c(a = "foo", b = "bar"), c("xbar", "foo", "none"))
  expect_named(out, "pattern")
  expect_identical(out$pattern, c("b", "a", NA))

  empty <- hs_capture(rules, character())
  expect_identical(nrow(empty), 0L)
  expect_identical(names(empty)[[1]], "pattern")
})

test_that("rule sets are validated", {
  expect_error(hs_capture(c("(?<pattern>a)", "b"), "a"), "cannot be called `pattern`")
  expect_error(hs_capture(c("a", NA), "a"), class = "vectorscan_error")
})
