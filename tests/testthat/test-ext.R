test_that("extended expression parameters record flags", {
  ext <- hs_ext(min_offset = 1, min_length = 3)

  expect_s3_class(ext, "hs_ext")
  expect_equal(ext$flags, 5L)
  expect_equal(ext$min_offset, 1L)
  expect_equal(ext$min_length, 3L)
})

test_that("extended expression parameters validate values", {
  expect_snapshot(error = TRUE, {
    hs_ext(min_length = -1)
  })
})
