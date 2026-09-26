fmt <- "^(\\S+ \\S+) \\[(\\w+)\\] ([^ :]+):(\\d+) - (.*)$"
proto <- data.frame(
  timestamp = character(),
  level = character(),
  location = character(),
  line = integer(),
  text = character()
)
for (f in c("log_1.txt", "log_0.01.txt")) {
  x <- readLines(f)
  t1 <- system.time(r1 <- utils::strcapture(fmt, x, proto, perl = TRUE))[[
    "elapsed"
  ]]
  t2 <- system.time(m <- regexec(fmt, x, perl = TRUE))[["elapsed"]]
  t3 <- system.time(g <- grepl(fmt, x, perl = TRUE))[["elapsed"]]
  cat(sprintf(
    "%-13s strcapture %.2fs | regexec only %.2fs | grepl only %.2fs | matched %d\n",
    f,
    t1,
    t2,
    t3,
    sum(!is.na(r1$level))
  ))
}
