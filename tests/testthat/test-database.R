test_that("database handles keep mode and state", {
  db <- hs_database()

  expect_s3_class(db, "hs_database")
  expect_equal(db$mode, HS_MODE_BLOCK)
  expect_equal(db$pattern_ids, integer())
  expect_equal(db$pattern_flags, integer())
})

test_that("mode validation rejects ambiguous modes", {
  expect_snapshot(error = TRUE, {
    hs_database(bitwOr(HS_MODE_BLOCK, HS_MODE_STREAM))
  })
})

test_that("compile validates expressions before native calls", {
  db <- hs_database()

  expect_snapshot(error = TRUE, {
    hs_compile(db, character())
  })
})

test_that("native availability is reported as a scalar logical", {
  expect_type(hs_available(), "logical")
  expect_length(hs_available(), 1)
})

test_that("native stubs fail clearly when unavailable", {
  skip_if(hs_available())

  db <- hs_database()
  expect_snapshot(error = TRUE, {
    hs_compile(db, "foo")
  })
})
