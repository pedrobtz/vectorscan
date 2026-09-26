test_that("matches can span any chunk boundary", {
  skip_if_not(hs_available())

  db <- hs_database(HS_MODE_STREAM)
  hs_compile(db, "needle")
  text <- "haystack needle haystack"

  for (cut in seq_len(nchar(text) - 1L)) {
    stream <- hs_stream_open(db)
    first <- hs_stream_scan(stream, substr(text, 1L, cut))
    second <- hs_stream_scan(stream, substr(text, cut + 1L, nchar(text)))
    hs_stream_close(stream)

    matches <- rbind(first, second)
    expect_equal(nrow(matches), 1L, info = cut)
    expect_equal(matches$to, 15, info = cut)
  }
})

test_that("end-anchored matches are reported when the stream closes", {
  skip_if_not(hs_available())

  db <- hs_database(HS_MODE_STREAM)
  hs_compile(db, "foo$")
  stream <- hs_stream_open(db)

  expect_equal(nrow(hs_stream_scan(stream, "xfoo")), 0L)
  at_close <- hs_stream_close(stream)

  expect_equal(nrow(at_close), 1L)
  expect_equal(at_close$to, 4)
})

test_that("closed streams cannot be scanned or closed again", {
  skip_if_not(hs_available())

  db <- hs_database(HS_MODE_STREAM)
  hs_compile(db, "foo")
  stream <- hs_stream_open(db)
  hs_stream_close(stream)

  expect_output(print(stream), "closed")
  expect_error(hs_stream_scan(stream, "foo"), "already closed", class = "vectorscan_error")
  expect_error(hs_stream_close(stream), "already closed", class = "vectorscan_error")
})

test_that("a stream keeps its database alive", {
  skip_if_not(hs_available())

  make_stream <- function() {
    db <- hs_database(HS_MODE_STREAM)
    hs_compile(db, "foo.*bar")
    hs_stream_open(db)
  }
  stream <- make_stream()
  invisible(gc())

  hs_stream_scan(stream, "foo")
  invisible(gc())
  expect_equal(nrow(hs_stream_scan(stream, "bar")), 1L)
  hs_stream_close(stream)
})

test_that("unclosed streams are released by their finalizer", {
  skip_if_not(hs_available())

  db <- hs_database(HS_MODE_STREAM)
  hs_compile(db, "foo")
  for (i in 1:50) {
    stream <- hs_stream_open(db)
    hs_stream_scan(stream, "foo")
  }
  rm(stream)
  expect_no_error(invisible(gc()))
})

test_that("stream scans accept callbacks and stop early", {
  skip_if_not(hs_available())

  db <- hs_database(HS_MODE_STREAM)
  hs_compile(db, "o")
  stream <- hs_stream_open(db)
  on.exit(hs_stream_close(stream), add = TRUE)

  seen <- 0L
  count <- hs_stream_scan(stream, "ooooo", callback = function(...) {
    seen <<- seen + 1L
    seen >= 2L
  })

  expect_equal(seen, 2L)
  expect_equal(count, 2L)
})

test_that("streams need a stream-mode database", {
  skip_if_not(hs_available())

  db <- hs_database()
  hs_compile(db, "foo")

  expect_error(hs_stream_open(db))
})
