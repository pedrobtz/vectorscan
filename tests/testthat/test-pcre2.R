test_that("PCRE2 comes from zuregex, recent enough, and reports its route", {
  info <- vectorscan:::pcre2_info()
  expect_named(info, c("version", "jit", "source"))
  version <- as.numeric_version(sub(" .*", "", info$version))
  expect_true(version >= "10.48")
  expect_type(info$jit, "logical")
  expect_identical(info$source, "zuregex")
})

test_that("vectorscan links no PCRE2 code of its own", {
  # hs_capture() calls zuregex's registered C API; a pcre2_ symbol in this
  # shared object would mean a second PCRE2 in the process.
  nm <- Sys.which("nm")
  skip_if(!nzchar(nm), "nm is not available")
  skip_on_os("windows")
  dll <- getLoadedDLLs()[["vectorscan"]][["path"]]
  syms <- suppressWarnings(system2(nm, shQuote(dll), stdout = TRUE, stderr = FALSE))
  # The symbol name is the last field; Mach-O prefixes an underscore.
  # vectorscan's own vctrsn_pcre2_*() functions are not PCRE2's.
  names <- sub("^.*[[:space:]]", "", syms)
  expect_length(grep("^_?pcre2_", names, value = TRUE), 0L)
})
