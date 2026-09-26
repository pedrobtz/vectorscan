/* (b) Chimera (Hyperscan prefilter + PCRE 8.45): the same capture loop. */
#include <ch.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>
static double now(void) { struct timespec t; clock_gettime(CLOCK_MONOTONIC, &t); return t.tv_sec + t.tv_nsec / 1e9; }
typedef struct { long matched, bytes; } acc_t;
static ch_callback_t on_match(unsigned id, unsigned long long from, unsigned long long to, unsigned flags,
                              unsigned size, const ch_capture_t *cap, void *ctx) {
  (void)id; (void)from; (void)to; (void)flags; acc_t *a = ctx; a->matched++;
  for (unsigned g = 1; g < size; g++) if (cap[g].flags == CH_CAPTURE_FLAG_ACTIVE) a->bytes += cap[g].to - cap[g].from;
  return CH_CALLBACK_TERMINATE;   /* first match per line */
}
int main(int argc, char **argv) {
  const char *fmt = "^(\\S+ \\S+) \\[(\\w+)\\] ([^ :]+):(\\d+) - (.*)$";
  FILE *f = fopen(argv[1], "rb"); fseek(f, 0, SEEK_END); long sz = ftell(f); rewind(f);
  char *buf = malloc(sz + 1); fread(buf, 1, sz, f); buf[sz] = 0; fclose(f);
  ch_database_t *db; ch_compile_error_t *ce; ch_scratch_t *scr = NULL;
  if (ch_compile(fmt, CH_FLAG_UTF8, CH_MODE_GROUPS, NULL, &db, &ce) != CH_SUCCESS) { printf("compile: %s\n", ce->message); return 1; }
  ch_alloc_scratch(db, &scr);
  acc_t a = {0, 0}; long lines = 0; double t0 = now();
  for (char *p = buf; *p; ) {
    char *nl = strchr(p, '\n'); size_t len = nl ? (size_t)(nl - p) : strlen(p);
    ch_scan(db, p, (unsigned)len, 0, scr, on_match, NULL, &a);
    lines++; p = nl ? nl + 1 : p + len;
  }
  printf("%s: %ld lines, %ld matched, %.3fs\n", argv[1], lines, a.matched, now() - t0);
  return 0;
}
