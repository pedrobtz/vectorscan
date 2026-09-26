test_that("hs_detect() agrees with grepl() on random data", {
  skip_if_not(hs_available())

  set.seed(1)
  x <- vapply(
    1:500,
    function(i) {
      paste(sample(c(letters[1:6], " "), sample(0:40, 1), TRUE), collapse = "")
    },
    character(1)
  )
  patterns <- c("abc", "f+e", "^a", "d$", "b.d", "[ef]{3}")

  expected <- Reduce(`|`, lapply(patterns, grepl, x = x))
  expect_identical(hs_detect(patterns, x), expected)

  per <- hs_detect(patterns, x, per_pattern = TRUE)
  expect_identical(dim(per), c(length(x), length(patterns)))
  for (j in seq_along(patterns)) {
    expect_identical(
      unname(per[, j]),
      grepl(patterns[[j]], x),
      info = patterns[[j]]
    )
  }
})

test_that("hs_detect() and hs_count() keep NA and length", {
  skip_if_not(hs_available())

  x <- c("foo", NA, "", "bar foo foo")

  expect_identical(hs_detect("foo", x), c(TRUE, NA, FALSE, TRUE))
  expect_identical(hs_count("foo", x), c(1L, NA, 0L, 2L))
  expect_identical(hs_detect("foo", character()), logical())
  expect_identical(hs_count("foo", character()), integer())
})

test_that("per-pattern results are labelled by pattern name or expression", {
  skip_if_not(hs_available())

  x <- c("cat and dog", "dog dog", "bird")
  counts <- hs_count(c(feline = "cat", "dog"), x, per_pattern = TRUE)

  expect_identical(colnames(counts), c("feline", "dog"))
  expect_identical(unname(counts[, "feline"]), c(1L, 0L, 0L))
  expect_identical(unname(counts[, "dog"]), c(1L, 2L, 0L))
})

test_that("hs_match() returns every match with text and names", {
  skip_if_not(hs_available())

  x <- c("hello 42", NA, "nothing", "7 hellos")
  m <- hs_match(c(greeting = "hel+o", number = "[0-9]+"), x)

  expect_named(m, c("input", "id", "pattern", "from", "to", "match"))
  expect_identical(m$input, c(1L, 1L, 1L, 4L, 4L))
  expect_identical(
    m$pattern,
    c("greeting", "number", "number", "number", "greeting")
  )
  expect_identical(m$match, c("hello", "4", "42", "7", "hello"))
  expect_identical(m$from, c(0, 6, 6, 0, 2))
})

test_that("hs_match() slices UTF-8 by bytes and returns UTF-8 text", {
  skip_if_not(hs_available())

  m <- hs_match("été", "un été chaud")

  expect_identical(m$from, 3)
  expect_identical(m$to, 8)
  expect_identical(m$match, "été")
  expect_identical(Encoding(m$match), "UTF-8")
})

test_that("hs_extract() gives one character vector per element", {
  skip_if_not(hs_available())

  out <- hs_extract("[0-9]+", c("a1b22", "none", NA), som = TRUE)

  expect_length(out, 3L)
  expect_identical(out[[1]], c("1", "2", "22"))
  expect_identical(out[[2]], character())
  expect_identical(out[[3]], NA_character_)
})

test_that("a compiled database can be reused, with or without SOM", {
  skip_if_not(hs_available())

  db <- hs_compile(c(a = "foo", b = "bar"))
  expect_s3_class(db, "hs_database")
  expect_identical(hs_detect(db, c("foo", "baz")), c(TRUE, FALSE))

  m <- hs_match(db, "foobar")
  expect_identical(m$pattern, c("a", "b"))
  expect_identical(m$from, c(NA_real_, NA_real_))
  expect_identical(m$match, c(NA_character_, NA_character_))

  som <- hs_compile(c(a = "foo"), flags = HS_FLAG_SOM_LEFTMOST)
  expect_identical(hs_match(som, "xfoo")$match, "foo")
})

test_that("som = FALSE skips start offsets", {
  skip_if_not(hs_available())

  m <- hs_match("foo", "foo", som = FALSE)
  expect_identical(m$from, NA_real_)
  expect_identical(m$match, NA_character_)
})

test_that("rules data frames carry ids, flags and names", {
  skip_if_not(hs_available())

  rules <- data.frame(
    pattern = c("FOO", "bar"),
    id = c(10L, 20L),
    flags = c(HS_FLAG_CASELESS, HS_FLAG_NONE),
    name = c("foo-any-case", NA)
  )
  m <- hs_match(rules, "foo bar")

  expect_identical(m$id, c(10L, 20L))
  expect_identical(m$pattern, c("foo-any-case", "bar"))
  expect_identical(m$match, c("foo", "bar"))

  db <- hs_compile(rules)
  expect_identical(db$pattern_ids, c(10L, 20L))
  expect_error(
    hs_compile(hs_database(), rules, ids = 1:2),
    class = "vectorscan_error"
  )
  expect_error(
    hs_compile(data.frame(x = "a")),
    "pattern",
    class = "vectorscan_error"
  )
})

test_that("deserialized databases label patterns by id", {
  skip_if_not(hs_available())

  db <- hs_compile(c(a = "foo"))
  restored <- hs_deserialize(hs_serialize(db))

  expect_identical(hs_match(restored, "foo")$pattern, "0")
})

test_that("verbs validate their inputs", {
  skip_if_not(hs_available())

  sdb <- hs_database(HS_MODE_STREAM)
  hs_compile(sdb, "foo")

  expect_error(hs_detect(sdb, "foo"), class = "vectorscan_error_mode")
  expect_error(hs_detect("foo", 1), class = "vectorscan_error")
  expect_error(hs_detect("foo", factor("foo")), class = "vectorscan_error")
  expect_error(hs_detect(1, "foo"), class = "vectorscan_error")
  expect_error(hs_detect(hs_database(), "foo"), class = "vectorscan_error")
})

test_that("verbs scan long vectors", {
  skip_if_not(hs_available())

  x <- rep(c("needle in hay", "hay"), 5000)
  expect_identical(sum(hs_detect("needle", x)), 5000L)
  expect_identical(nrow(hs_match("needle", x)), 5000L)
})
