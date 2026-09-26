test_that("PCRE2 is linked, recent enough, and reports its route", {
  info <- vectorscan:::pcre2_info()
  skip_if(is.null(info), "built without PCRE2")

  expect_named(info, c("version", "jit", "source"))
  version <- as.numeric_version(sub(" .*", "", info$version))
  expect_true(version >= "10.34")
  expect_type(info$jit, "logical")
  expect_true(info$source %in% c("system", "vendored"))
})
