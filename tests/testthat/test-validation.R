test_that("typed errors have their own classes", {
  expect_error(
    hs_database(platform = list()),
    class = "vectorscan_error_platform"
  )
  expect_error(hs_database(0L), class = "vectorscan_error_mode")
  expect_error(
    hs_database(bitwOr(HS_MODE_BLOCK, HS_MODE_VECTORED)),
    class = "vectorscan_error_mode"
  )
})

test_that("every validation error is a vectorscan_error", {
  db <- hs_database()
  e <- function(expr) expect_error(expr, class = "vectorscan_error")

  # hs_database() mode
  e(hs_database("block"))
  e(hs_database(c(1L, 2L)))
  e(hs_database(NA_integer_))
  e(hs_database(1.5))
  e(hs_database(-1L))

  # database objects
  e(hs_compile(list(), "foo"))
  e(hs_scan(db, "foo"))
  e(hs_info(db))
  e(hs_database_size(db))
  e(hs_stream_open(db))

  # expressions
  e(hs_compile(db, 1))
  e(hs_compile(db, character()))
  e(hs_compile(db, c("foo", NA)))

  # ids and flags
  e(hs_compile(db, c("a", "b"), ids = c(1L, 2L, 3L)))
  e(hs_compile(db, "a", ids = "1"))
  e(hs_compile(db, "a", ids = NA))
  e(hs_compile(db, "a", ids = 1.5))
  e(hs_compile(db, "a", ids = -1L))
  e(hs_compile(db, c("a", "b"), flags = c(0L, 0L, 0L)))

  # extended parameters
  e(hs_ext(min_offset = "1"))
  e(hs_ext(max_offset = c(1, 2)))
  e(hs_ext(min_length = NA))
  e(hs_ext(edit_distance = 0.5))
  e(hs_ext(hamming_distance = -2))
  e(hs_compile(db, "a", ext = list(1)))
  e(hs_compile(db, "a", ext = "x"))

  # streams
  e(hs_stream_scan(list(), "foo"))
  e(hs_stream_close(list()))

  # serialization
  e(hs_deserialize(1:3))
})

test_that("scan inputs are validated", {
  skip_if_not(hs_available())

  db <- hs_database()
  hs_compile(db, "foo")
  vdb <- hs_database(HS_MODE_VECTORED)
  hs_compile(vdb, "foo")

  expect_error(hs_scan(db, 1), class = "vectorscan_error")
  expect_error(hs_scan(db, c("a", "b")), class = "vectorscan_error")
  expect_error(hs_scan(db, NA_character_), class = "vectorscan_error")
  expect_error(hs_scan_vector(vdb, c("a", NA)), class = "vectorscan_error")
  expect_error(hs_scan_vector(vdb, list("a", 1)), class = "vectorscan_error")
  expect_error(hs_scan_vector(vdb, 1), class = "vectorscan_error")
})

test_that("invalid patterns report Vectorscan's reason", {
  skip_if_not(hs_available())

  db <- hs_database()
  expect_error(hs_compile(db, "[a-"), "compile error at expression 0")
  expect_error(hs_compile(db, "a{2,1}"), "compile error at expression 0")
})
