# Synthetic log: n lines, a share `hit` of them in the target format.
set.seed(42)
make_log <- function(n, hit) {
  lv <- sample(c("INFO", "WARN", "ERROR", "DEBUG"), n, TRUE, prob = c(.7, .15, .05, .1))
  ts <- format(as.POSIXct("2026-09-26", tz = "UTC") + sort(runif(n, 0, 86400)), "%Y-%m-%d %H:%M:%OS3")
  loc <- sample(c("api.server", "db.pool", "auth.jwt", "cache.redis", "http.client"), n, TRUE)
  msg <- sample(c("request served in 12ms", "slow query took 1.8s", "token expired for user 12",
                  "cache miss for key user:42:profile", "retrying connection to upstream host"), n, TRUE)
  good <- sprintf("%s [%s] %s:%d - %s", ts, lv, loc, sample(1:500, n, TRUE), msg)
  bad <- sprintf("%s %s", ts, msg)                     # other format: no match
  ifelse(runif(n) < hit, good, bad)
}
for (hit in c(1, 0.01)) writeLines(make_log(1e6, hit), sprintf("log_%s.txt", hit))
