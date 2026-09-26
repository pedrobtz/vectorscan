test_that("hs_flags() reads letters and names", {
  expect_identical(hs_flags("i"), HS_FLAG_CASELESS)
  expect_identical(
    hs_flags(c("is", "caseless|dotall", "HS_FLAG_CASELESS, dotall", "")),
    rep(c(bitwOr(HS_FLAG_CASELESS, HS_FLAG_DOTALL), 0L), c(3, 1))
  )
  expect_identical(
    hs_flags("smHV8WPLCQi"),
    Reduce(
      bitwOr,
      c(
        HS_FLAG_CASELESS,
        HS_FLAG_DOTALL,
        HS_FLAG_MULTILINE,
        HS_FLAG_SINGLEMATCH,
        HS_FLAG_ALLOWEMPTY,
        HS_FLAG_UTF8,
        HS_FLAG_UCP,
        HS_FLAG_PREFILTER,
        HS_FLAG_SOM_LEFTMOST,
        HS_FLAG_COMBINATION,
        HS_FLAG_QUIET
      )
    )
  )
  expect_identical(hs_flags(c("ucp", "none", "ii")), c(64L, 0L, 1L))
  expect_error(hs_flags("x"), class = "vectorscan_error_flags")
  expect_error(hs_flags("caseles"), "Unknown flag \"CASELES\"")
  expect_error(hs_flags(NA_character_), "missing")
  expect_error(hs_flags(1L), "character")
})

test_that("hs_compile() takes flags as strings", {
  skip_if_not(hs_available())

  db <- hs_compile(c("abc", "x.y"), flags = c("i", "s"))
  expect_identical(db$pattern_flags, c(HS_FLAG_CASELESS, HS_FLAG_DOTALL))
  expect_identical(
    hs_detect(db, c("ABC", "x\ny", "none")),
    c(TRUE, TRUE, FALSE)
  )

  rules <- data.frame(pattern = c("abc", "def"), flags = c("i", ""))
  expect_identical(hs_detect(rules, c("ABC", "DEF")), c(TRUE, FALSE))
})

test_that("literal = TRUE matches the strings as written", {
  skip_if_not(hs_available())

  db <- hs_compile(c(dot = "a.b", paren = "(x"), literal = TRUE)
  expect_identical(
    hs_detect(db, c("a.b", "axb", "f(x)", "")),
    c(TRUE, FALSE, TRUE, FALSE)
  )
  som <- hs_compile(c(dot = "a.b", paren = "(x"), flags = "L", literal = TRUE)
  m <- hs_match(som, "a.b (x a.b")
  expect_identical(m$pattern, c("dot", "paren", "dot"))
  expect_equal(m$from, c(0, 4, 7))
  expect_identical(m$match, c("a.b", "(x", "a.b"))

  caseless <- hs_compile("Error", flags = "i", literal = TRUE)
  expect_true(hs_detect(caseless, "ERROR"))

  # Multibyte UTF-8 literals are compiled by bytes
  expect_true(hs_detect(
    hs_compile("caf\u00e9", literal = TRUE),
    "un caf\u00e9"
  ))

  # Streams too
  sdb <- hs_database(HS_MODE_STREAM)
  hs_compile(sdb, "a.b", literal = TRUE)
  s <- hs_stream_open(sdb)
  hs_stream_scan(s, "xa.")
  out <- hs_stream_scan(s, "b")
  hs_stream_close(s)
  expect_identical(out$to, 4)

  expect_error(
    hs_compile("a", ext = hs_ext(min_length = 1), literal = TRUE),
    "literal"
  )
  expect_error(hs_compile("a", literal = NA), "TRUE or FALSE")
  expect_error(
    hs_compile("a", flags = HS_FLAG_UCP, literal = TRUE),
    class = "vectorscan_error_compile"
  )
})

test_that("hs_read_patterns() reads Hyperscan pattern files", {
  lines <- c(
    "# comment",
    "",
    "1:/foo(bar)?/i",
    "2:/^GET \\/index\\.html/sm\r",
    "3:/abc/{edit_distance=1}",
    "40:/a/b/c/LO{min_offset=10, max_offset=5000000000}",
    "5://"
  )
  rules <- hs_read_patterns(textConnection(lines))

  expect_identical(names(rules), c("id", "pattern", "flags", "ext"))
  expect_identical(rules$id, c(1L, 2L, 3L, 40L, 5L))
  expect_identical(
    rules$pattern,
    c("foo(bar)?", "^GET \\/index\\.html", "abc", "a/b/c", "")
  )
  expect_identical(
    rules$flags,
    c(
      HS_FLAG_CASELESS,
      bitwOr(HS_FLAG_DOTALL, HS_FLAG_MULTILINE),
      0L,
      HS_FLAG_SOM_LEFTMOST,
      0L
    )
  )
  expect_null(rules$ext[[1]])
  expect_identical(rules$ext[[3]], hs_ext(edit_distance = 1))
  expect_identical(
    rules$ext[[4]],
    hs_ext(min_offset = 10, max_offset = 5000000000)
  )

  plain <- hs_read_patterns(textConnection(c("7:/x/", "8:/y/H")))
  expect_identical(names(plain), c("id", "pattern", "flags"))

  path <- tempfile(fileext = ".txt")
  on.exit(unlink(path))
  writeLines(c("1:/a/", "2:/b/"), path)
  expect_identical(hs_read_patterns(path)$pattern, c("a", "b"))

  bad <- function(line) {
    expect_error(
      hs_read_patterns(textConnection(c("1:/ok/", line))),
      class = "vectorscan_error_pattern_file"
    )
  }
  bad("no colon")
  bad("x:/a/")
  bad("1:a")
  bad("1:/a")
  bad("1:/a/z")
  bad("1:/a/{min_offset=}")
  bad("1:/a/{distance=1}")
  expect_error(
    hs_read_patterns(textConnection(c("1:/ok/", "1:/a/z"))),
    "Line 2"
  )
})

test_that("pattern files compile and scan", {
  skip_if_not(hs_available())

  rules <- hs_read_patterns(textConnection(c(
    "10:/^(GET|POST) /",
    "11:/error/i",
    "12:/timeout/{edit_distance=1}"
  )))
  m <- hs_match(rules, c("GET / x", "ERROR: timout"))
  expect_identical(m$input, c(1L, 2L, 2L))
  expect_identical(m$id, c(10L, 11L, 12L))
  expect_identical(m$match, c("GET ", "ERROR", "timout"))

  db <- hs_compile(rules)
  expect_identical(
    hs_detect(db, c("POST /a", "time-out", "tiem-out", "nothing")),
    c(TRUE, TRUE, FALSE, FALSE)
  )
  expect_error(hs_compile(rules, ext = hs_ext()), "not both")
})

test_that("hs_ext() keeps offsets beyond the integer range", {
  expect_identical(hs_ext(max_offset = 3e9)$max_offset, 3e9)
  expect_error(hs_ext(max_offset = 2^54), "2\\^53")
})
