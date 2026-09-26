skip_if(is.null(vectorscan:::pcre2_info()), "built without PCRE2")

test_that("match_limit stops catastrophic backtracking, JIT or not", {
  evil <- paste0(strrep("a", 28), "!")
  for (jit in c(TRUE, FALSE)) {
    p <- hs_capture_compile("^(a+)+$", jit = jit)
    expect_warning(
      out <- hs_capture(p, c(evil, "aaa"), match_limit = 10000),
      "1 element could not be matched \\(match limit exceeded\\)",
      info = paste("jit", jit)
    )
    expect_identical(out$V1, c(NA, "aaa"), info = paste("jit", jit))
  }
})

test_that("depth_limit bounds deep recursion; the defaults do not", {
  deep <- paste0(strrep("a", 3000), strrep("b", 3000))
  for (jit in c(TRUE, FALSE)) {
    p <- hs_capture_compile("^(a(?1)?b)$", jit = jit)
    expect_warning(
      out <- hs_capture(p, c(deep, "ab"), depth_limit = 50),
      "depth limit exceeded",
      info = paste("jit", jit)
    )
    expect_identical(is.na(out$V1), c(TRUE, FALSE), info = paste("jit", jit))
    expect_false(anyNA(hs_capture(p, c(deep, "ab"))$V1), info = paste("jit", jit))
  }
})

test_that("the interpreter and JIT give identical results", {
  set.seed(11)
  alphabet <- c(strsplit("abcdxy12 ,=", "")[[1]], "é")
  x <- c(NA, "", vapply(1:500, function(i) {
    paste(sample(alphabet, sample(0:16, 1), TRUE), collapse = "")
  }, character(1)))
  for (p in c("^(\\w+)=(\\d*)", "(a+)(b*)", "(?<k>[a-c]{2})(?<v>.)?", "(x)|(y)")) {
    expect_identical(
      hs_capture(hs_capture_compile(p, jit = FALSE), x),
      hs_capture(hs_capture_compile(p, jit = TRUE), x),
      info = p
    )
  }
  expect_output(print(hs_capture_compile("(a)", jit = FALSE)), "interpreted")
})

test_that("limits are validated", {
  expect_error(hs_capture("(a)", "a", match_limit = 0), class = "vectorscan_error")
  expect_error(hs_capture("(a)", "a", match_limit = "10"), class = "vectorscan_error")
  expect_error(hs_capture("(a)", "a", depth_limit = c(1, 2)), class = "vectorscan_error")
  expect_error(hs_capture("(a)", "a", depth_limit = 1.5), class = "vectorscan_error")
})

test_that("limits apply to rule sets too", {
  evil <- paste0(strrep("a", 28), "!")
  rules <- c(bad = "^(a+)+$", ok = "^(\\w+)!$")
  expect_warning(
    out <- hs_capture(rules, c(evil, "b!"), match_limit = 10000),
    NA
  )
  # the evil line fails the first rule on its limit, then matches the second
  expect_identical(out$pattern, c("ok", "ok"))
})
