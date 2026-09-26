test_that("hs_version() names the linked Vectorscan", {
  v <- hs_version()
  expect_type(v, "character")
  expect_length(v, 1L)
  if (hs_available()) {
    expect_match(v, "^[0-9]+\\.[0-9]+")
  } else {
    expect_true(is.na(v))
  }
})

test_that("a callback's own error comes out unchanged", {
  skip_if_not(hs_available())

  db <- hs_compile("o")
  custom <- structure(
    class = c("my_condition", "error", "condition"),
    list(message = "my custom error", call = NULL)
  )
  calls <- 0L
  expect_error(
    hs_scan(db, "ooo", callback = function(...) {
      calls <<- calls + 1L
      stop(custom)
    }),
    "my custom error",
    class = "my_condition"
  )
  expect_identical(calls, 1L)

  vdb <- hs_database(HS_MODE_VECTORED)
  hs_compile(vdb, "o")
  expect_error(hs_scan_vector(vdb, "o", callback = function(...) stop("vec")), "vec")

  sdb <- hs_database(HS_MODE_STREAM)
  hs_compile(sdb, c("o", "x$"))
  s1 <- hs_stream_open(sdb)
  expect_error(hs_stream_scan(s1, "o", callback = function(...) stop("streamed")), "streamed")
  hs_stream_close(s1)
  s2 <- hs_stream_open(sdb)
  hs_stream_scan(s2, "x")
  expect_error(hs_stream_close(s2, callback = function(...) stop("closing")), "closing")
  expect_output(print(s2), "closed")
})

test_that("SOM horizon modes give start offsets in stream mode", {
  skip_if_not(hs_available())

  expect_error(
    hs_compile(hs_database(HS_MODE_STREAM), "foo.*bar", flags = HS_FLAG_SOM_LEFTMOST),
    class = "vectorscan_error_compile"
  )

  db <- hs_database(bitwOr(HS_MODE_STREAM, HS_MODE_SOM_HORIZON_LARGE))
  hs_compile(db, "foo.*bar", flags = HS_FLAG_SOM_LEFTMOST)
  stream <- hs_stream_open(db)
  hs_stream_scan(stream, "xx foo")
  m <- hs_stream_scan(stream, " and then bar")
  hs_stream_close(stream)

  expect_equal(m$from, 3)
  expect_equal(m$to, 19)
})

test_that("hs_stream_size() reports stream state bytes", {
  skip_if_not(hs_available())

  sdb <- hs_database(HS_MODE_STREAM)
  hs_compile(sdb, c("foo.*bar", "baz"))
  expect_gt(hs_stream_size(sdb), 0)
  expect_error(hs_stream_size(hs_compile("foo")), class = "vectorscan_error_db_mode")
})

test_that("native errors carry a class per Vectorscan error", {
  skip_if_not(hs_available())

  err <- tryCatch(hs_compile(c("ok", "a(b")), error = function(e) e)
  expect_s3_class(err, "vectorscan_error_compile")
  expect_s3_class(err, "vectorscan_error")
  expect_identical(err$expression, 1L)
  expect_match(err$reason, "parenthesis")

  bad <- tryCatch(hs_stream_open(hs_compile("foo")), error = function(e) e)
  expect_s3_class(bad, "vectorscan_error_native")
  expect_true(is.integer(bad$code) && bad$code < 0L)

  junk <- tryCatch(hs_deserialize(as.raw(rep(0x5a, 256))), error = function(e) e)
  expect_s3_class(junk, "vectorscan_error_native")
})
