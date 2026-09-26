test_that("block scanning returns match data frames", {
  skip_if_not(hs_available())

  db <- hs_database()
  hs_compile(db, c("foo", "bar"), ids = c(10L, 20L))

  matches <- hs_scan(db, "foobar")

  expect_s3_class(matches, "data.frame")
  expect_equal(matches$id, c(10L, 20L))
  expect_equal(matches$from, c(NA_real_, NA_real_))
  expect_equal(matches$to, c(3, 6))
})

test_that("SOM flags preserve start offsets", {
  skip_if_not(hs_available())

  db <- hs_database()
  hs_compile(db, "bar", flags = HS_FLAG_SOM_LEFTMOST)

  matches <- hs_scan(db, "foobar")

  expect_equal(matches$from, 3)
  expect_equal(matches$to, 6)
})

test_that("callbacks can terminate scans", {
  skip_if_not(hs_available())

  db <- hs_database()
  hs_compile(db, c("foo", "bar"))
  seen <- integer()

  count <- hs_scan(db, "foobar", callback = function(id, from, to, flags, ctx) {
    seen <<- c(seen, id)
    TRUE
  })

  expect_equal(count, 1L)
  expect_length(seen, 1)
})

test_that("vectored scans can match across blocks", {
  skip_if_not(hs_available())

  db <- hs_database(HS_MODE_VECTORED)
  hs_compile(db, "foobar")

  matches <- hs_scan_vector(db, c("foo", "bar"))

  expect_equal(matches$id, 0L)
  expect_equal(matches$to, 6)
})

test_that("streams can match across chunks", {
  skip_if_not(hs_available())

  db <- hs_database(HS_MODE_STREAM)
  hs_compile(db, "foobar")
  stream <- hs_stream_open(db)

  expect_equal(nrow(hs_stream_scan(stream, "foo")), 0L)
  matches <- hs_stream_scan(stream, "bar")
  close_matches <- hs_stream_close(stream)

  expect_equal(matches$id, 0L)
  expect_equal(matches$to, 6)
  expect_equal(nrow(close_matches), 0L)
})

test_that("serialized databases round trip", {
  skip_if_not(hs_available())

  db <- hs_database()
  hs_compile(db, "foo")

  restored <- hs_deserialize(hs_serialize(db))
  matches <- hs_scan(restored, "foo")

  expect_equal(matches$id, 0L)
  expect_equal(matches$to, 3)
})
