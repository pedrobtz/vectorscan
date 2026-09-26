test_that("serialized databases give the same matches", {
  skip_if_not(hs_available())

  db <- hs_database()
  hs_compile(db, c("foo", "ba[rz]", "\\d{3}"), ids = c(1L, 2L, 3L))
  restored <- hs_deserialize(hs_serialize(db))

  for (x in c("foobar", "bazfoo 123", "", "nothing here", strrep("foo", 50))) {
    expect_equal(hs_scan(restored, x), hs_scan(db, x), info = x)
  }
  expect_equal(hs_database_size(restored), hs_database_size(db))
  expect_equal(hs_info(restored), hs_info(db))
})

test_that("serialized databases keep start-of-match offsets", {
  skip_if_not(hs_available())

  db <- hs_database()
  hs_compile(
    db,
    c("foo", "bar"),
    flags = c(HS_FLAG_NONE, HS_FLAG_SOM_LEFTMOST)
  )
  restored <- hs_deserialize(hs_serialize(db))

  expect_equal(hs_scan(restored, "foobar"), hs_scan(db, "foobar"))
})

test_that("serialized databases keep their mode", {
  skip_if_not(hs_available())

  db <- hs_database(HS_MODE_STREAM)
  hs_compile(db, "foo.*bar")
  restored <- hs_deserialize(hs_serialize(db))

  expect_equal(restored$mode, db$mode)
  stream <- hs_stream_open(restored)
  hs_stream_scan(stream, "foo")
  expect_equal(nrow(hs_stream_scan(stream, "bar")), 1L)
  hs_stream_close(stream)
})

test_that("hs_save() and hs_load() round trip through a file", {
  skip_if_not(hs_available())

  db <- hs_database()
  hs_compile(db, c("foo", "bar"))
  path <- tempfile(fileext = ".hsdb")
  on.exit(unlink(path), add = TRUE)

  expect_identical(hs_save(db, path), path)
  expect_true(file.exists(path))
  expect_equal(hs_scan(hs_load(path), "foobar"), hs_scan(db, "foobar"))
})

test_that("corrupt serialized bytes are rejected", {
  skip_if_not(hs_available())

  db <- hs_database()
  hs_compile(db, "foo")
  bytes <- hs_serialize(db)

  expect_error(hs_deserialize(raw()))
  expect_error(hs_deserialize(bytes[seq_len(length(bytes) %/% 2)]))
  expect_error(hs_deserialize(as.raw(rep(0x5a, 256))))
})

test_that("only compiled databases can be serialized", {
  expect_error(hs_serialize(hs_database()), class = "vectorscan_error")
  expect_error(hs_deserialize("not raw"), class = "vectorscan_error")
})

test_that("serialized bytes are plain Vectorscan bytes plus metadata", {
  skip_if_not(hs_available())

  db <- hs_database()
  hs_compile(db, c("foo", "bar"), ids = c(5L, 6L), flags = c(0L, HS_FLAG_SOM_LEFTMOST))
  bytes <- hs_serialize(db)

  expect_equal(attr(bytes, "hs_pattern_ids"), c(5L, 6L))
  expect_equal(attr(bytes, "hs_pattern_flags"), c(0L, HS_FLAG_SOM_LEFTMOST))
})

test_that("without metadata, from is reported as Vectorscan gives it", {
  skip_if_not(hs_available())

  db <- hs_database()
  hs_compile(db, "foo")
  plain <- as.vector(hs_serialize(db))
  restored <- hs_deserialize(plain)

  expect_equal(restored$mode, HS_MODE_BLOCK)
  expect_equal(hs_scan(restored, "foo")$from, 0)
})

test_that("hs_save() files are tagged and hs_load() reads plain files too", {
  skip_if_not(hs_available())

  db <- hs_database(HS_MODE_STREAM)
  hs_compile(db, "foo")
  tagged <- tempfile()
  plain <- tempfile()
  on.exit(unlink(c(tagged, plain)), add = TRUE)

  hs_save(db, tagged)
  expect_identical(readBin(tagged, "raw", 8L), charToRaw("VSCANRDB"))

  writeBin(as.vector(hs_serialize(db)), plain)
  loaded <- hs_load(plain)
  expect_equal(loaded$mode, HS_MODE_STREAM)
  expect_equal(loaded$pattern_ids, integer())
})

test_that("damaged hs_save() files are rejected", {
  skip_if_not(hs_available())

  db <- hs_database()
  hs_compile(db, "foo")
  path <- tempfile()
  on.exit(unlink(path), add = TRUE)
  hs_save(db, path)
  good <- readBin(path, "raw", file.info(path)$size)

  write_and_load <- function(bytes) {
    writeBin(bytes, path)
    hs_load(path)
  }
  version_2 <- good
  version_2[9:12] <- as.raw(c(2, 0, 0, 0))
  huge_count <- good
  huge_count[13:16] <- as.raw(c(255, 255, 255, 127))

  expect_error(write_and_load(version_2), "unsupported version", class = "vectorscan_error")
  expect_error(write_and_load(huge_count), "truncated", class = "vectorscan_error")
  expect_error(write_and_load(good[1:14]), class = "vectorscan_error")
  expect_error(write_and_load(good[1:30]))
})
