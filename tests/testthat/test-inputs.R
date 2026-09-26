test_that("empty input gives an empty match data frame", {
  skip_if_not(hs_available())

  db <- hs_database()
  hs_compile(db, "foo")
  matches <- hs_scan(db, "")

  expect_s3_class(matches, "data.frame")
  expect_equal(nrow(matches), 0L)
  expect_named(matches, c("id", "from", "to", "flags"))
})

test_that("raw vectors can carry embedded NUL bytes", {
  skip_if_not(hs_available())

  db <- hs_database()
  hs_compile(db, "a\\x00b", flags = HS_FLAG_SOM_LEFTMOST)
  matches <- hs_scan(db, as.raw(c(0x78, 0x61, 0x00, 0x62)))

  expect_equal(matches$from, 1)
  expect_equal(matches$to, 4)
})

test_that("offsets are byte offsets into UTF-8", {
  skip_if_not(hs_available())

  db <- hs_database()
  hs_compile(db, "été", flags = HS_FLAG_SOM_LEFTMOST)
  # "l'été": the match starts after 2 one-byte characters and spans
  # 5 bytes (two 2-byte characters and one 1-byte character).
  matches <- hs_scan(db, "l'été")

  expect_equal(matches$from, 2)
  expect_equal(matches$to, 7)
})

test_that("UTF-8 and Unicode property flags work", {
  skip_if_not(hs_available())

  db <- hs_database()
  hs_compile(db, "^\\w+$", flags = bitwOr(HS_FLAG_UTF8, HS_FLAG_UCP))

  expect_equal(nrow(hs_scan(db, "été")), 1L)
})

test_that("large inputs are scanned in one call", {
  skip_if_not(hs_available())

  db <- hs_database()
  hs_compile(db, "needle")
  text <- paste(rep(c(strrep("x", 9994), "needle"), 100), collapse = "")

  matches <- hs_scan(db, text)

  expect_equal(nrow(matches), 100L)
  expect_equal(matches$to[1:2], c(10000, 20000))
})

test_that("strings are converted to UTF-8 before scanning", {
  skip_if_not(hs_available())

  db <- hs_database()
  hs_compile(db, "é")
  latin1 <- iconv("café", "UTF-8", "latin1")

  expect_equal(nrow(hs_scan(db, latin1)), 1L)
})

test_that("vectored input accepts raw vectors and lists", {
  skip_if_not(hs_available())

  db <- hs_database(HS_MODE_VECTORED)
  hs_compile(db, "foobar")

  expect_equal(nrow(hs_scan_vector(db, charToRaw("foobar"))), 1L)
  expect_equal(nrow(hs_scan_vector(db, list("foo", charToRaw("bar")))), 1L)
})

test_that("extended parameters change what matches", {
  skip_if_not(hs_available())

  scan_with <- function(pattern, ext, text) {
    db <- hs_database()
    hs_compile(db, pattern, ext = ext)
    hs_scan(db, text)$to
  }

  # min_offset / max_offset bound the end offset of a match.
  expect_equal(scan_with("foo", hs_ext(min_offset = 5), "foo foo"), 7)
  expect_equal(scan_with("foo", hs_ext(max_offset = 3), "foo foo"), 3)
  # min_length drops matches shorter than it.
  expect_equal(scan_with("a+", hs_ext(min_length = 3), "a aa aaa"), 8)
  # edit and Hamming distance allow approximate matches.
  expect_equal(scan_with("abcd", hs_ext(edit_distance = 1), "xx abd xx"), 6)
  expect_length(scan_with("abcd", NULL, "xx abd xx"), 0L)
  expect_equal(scan_with("abcd", hs_ext(hamming_distance = 1), "xx abxd xx"), 7)
  expect_length(scan_with("abcd", NULL, "xx abxd xx"), 0L)
})
