test_that("callbacks receive each match and the context", {
  skip_if_not(hs_available())

  db <- hs_database()
  hs_compile(db, c("foo", "bar"), ids = c(10L, 20L))
  seen <- list()

  count <- hs_scan(
    db,
    "foobar",
    callback = function(id, from, to, flags, context) {
      seen[[length(seen) + 1L]] <<- list(id = id, to = to, tag = context$tag)
      FALSE
    },
    context = list(tag = "ctx")
  )

  expect_equal(count, 2L)
  expect_equal(vapply(seen, `[[`, integer(1), "id"), c(10L, 20L))
  expect_equal(vapply(seen, `[[`, numeric(1), "to"), c(3, 6))
  expect_equal(unique(vapply(seen, `[[`, character(1), "tag")), "ctx")
})

test_that("an error in a callback stops the scan and is reported", {
  skip_if_not(hs_available())

  db <- hs_database()
  hs_compile(db, "o")
  calls <- 0L

  expect_error(
    suppressMessages(hs_scan(db, strrep("o", 100), callback = function(...) {
      calls <<- calls + 1L
      stop("boom")
    })),
    "callback failed"
  )
  expect_equal(calls, 1L)
})

test_that("scans work normally after a callback error", {
  skip_if_not(hs_available())

  db <- hs_database()
  hs_compile(db, "o")

  for (i in 1:20) {
    try(
      suppressMessages(hs_scan(db, "ooo", callback = function(...) stop("boom"))),
      silent = TRUE
    )
  }
  expect_equal(nrow(hs_scan(db, "ooo")), 3L)
})

test_that("callbacks see NA start offsets unless SOM is requested", {
  skip_if_not(hs_available())

  db <- hs_database()
  hs_compile(db, c("foo", "bar"), flags = c(HS_FLAG_NONE, HS_FLAG_SOM_LEFTMOST))
  from <- c()

  hs_scan(db, "foobar", callback = function(id, from_i, to, flags, context) {
    from <<- c(from, from_i)
    FALSE
  })

  expect_equal(from, c(NA, 3))
})

test_that("vectored scans pass callbacks through", {
  skip_if_not(hs_available())

  db <- hs_database(HS_MODE_VECTORED)
  hs_compile(db, "foobar")
  seen <- 0L

  hs_scan_vector(db, c("foo", "bar"), callback = function(...) {
    seen <<- seen + 1L
    FALSE
  })

  expect_equal(seen, 1L)
})

test_that("non-function callbacks are rejected", {
  skip_if_not(hs_available())

  db <- hs_database()
  hs_compile(db, "foo")

  expect_error(hs_scan(db, "foo", callback = "f"), class = "vectorscan_error")
})
