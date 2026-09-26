skip_if(is.null(vectorscan:::pcre2_info()), "built without PCRE2")

log_lines <- c(
  "2026-09-26 10:15:02.117 [INFO] api.server:42 - listening on :8080",
  "2026-09-26 10:15:07.901 [WARN] db.pool:118 - slow query took 1.8s",
  "garbage line without the format",
  NA,
  "2026-09-26 10:16:00.004 [ERROR] auth.jwt:77 - token expired for user 12"
)
fmt <- "^(\\S+ \\S+) \\[(\\w+)\\] ([^ :]+):(\\d+) - (.*)$"
proto <- data.frame(
  timestamp = character(), level = character(), location = character(),
  line = integer(), text = character()
)

test_that("hs_capture() equals utils::strcapture() on a log", {
  expect_identical(
    hs_capture(fmt, log_lines, proto),
    utils::strcapture(fmt, log_lines, proto, perl = TRUE)
  )
})

test_that("column names come from proto, named groups, or V<k>", {
  named <- "^(?<time>\\S+ \\S+) \\[(?<level>\\w+)\\] ([^ :]+):(\\d+) - (.*)$"

  expect_named(hs_capture(named, log_lines), c("time", "level", "V3", "V4", "V5"))
  expect_named(hs_capture(named, log_lines, proto), names(proto))
  expect_named(hs_capture(fmt, log_lines), paste0("V", 1:5))
})

test_that("without proto every column is character, with NA rows", {
  out <- hs_capture(fmt, log_lines)

  expect_s3_class(out, "data.frame")
  expect_identical(nrow(out), length(log_lines))
  expect_true(all(vapply(out, is.character, logical(1))))
  expect_true(all(is.na(out[3, ])))
  expect_true(all(is.na(out[4, ])))
  expect_identical(out$V2, c("INFO", "WARN", NA, NA, "ERROR"))
})

test_that("groups that do not take part are NA", {
  out <- hs_capture("^(\\w+)(?:=(\\d+))?$", c("a=1", "b"))
  expect_identical(out$V2, c("1", NA))
})

test_that("a compiled pattern can be reused", {
  compiled <- hs_capture_compile("(?<k>\\w+)=(?<v>\\w+)")

  expect_s3_class(compiled, "hs_capture_pattern")
  expect_output(print(compiled), "2 groups \\(k, v\\)")
  expect_identical(hs_capture(compiled, "a=b")$v, "b")
  expect_identical(hs_capture(compiled, c("x=y", "z"))$k, c("x", NA))
})

test_that("zero-length input gives a zero-row data frame", {
  out <- hs_capture(fmt, character(), proto)
  expect_identical(nrow(out), 0L)
  expect_identical(vapply(out, class, character(1)), vapply(proto, class, character(1)))
})

test_that("elements PCRE2 cannot match give NA rows and one warning", {
  expect_warning(
    out <- hs_capture("(\\w+)=(\\d)", c("a=1", rawToChar(as.raw(c(0x61, 0xff, 0x3d, 0x31))))),
    "1 element could not be matched"
  )
  expect_identical(out$V1, c("a", NA))
})

test_that("inputs are validated", {
  expect_error(hs_capture(c("a", "b"), "a"), class = "vectorscan_error")
  expect_error(hs_capture("(a)", 1), class = "vectorscan_error")
  expect_error(hs_capture("(a)(b)", "ab", proto), "2 capture groups but `proto` has 5", class = "vectorscan_error")
  expect_error(hs_capture("(a", "a"), "Invalid pattern")
})
