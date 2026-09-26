/* (a) PCRE2 + JIT: match each line and read the group offsets, as a C
   capture loop would before writing columns. */
#define PCRE2_CODE_UNIT_WIDTH 8
#include <pcre2.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>
static double now(void) { struct timespec t; clock_gettime(CLOCK_MONOTONIC, &t); return t.tv_sec + t.tv_nsec / 1e9; }
int main(int argc, char **argv) {
  const char *fmt = "^(\\S+ \\S+) \\[(\\w+)\\] ([^ :]+):(\\d+) - (.*)$";
  FILE *f = fopen(argv[1], "rb"); fseek(f, 0, SEEK_END); long sz = ftell(f); rewind(f);
  char *buf = malloc(sz + 1); fread(buf, 1, sz, f); buf[sz] = 0; fclose(f);
  int err; PCRE2_SIZE eo;
  pcre2_code *re = pcre2_compile((PCRE2_SPTR)fmt, PCRE2_ZERO_TERMINATED, PCRE2_UTF, &err, &eo, NULL);
  int jit = pcre2_jit_compile(re, PCRE2_JIT_COMPLETE) == 0;
  pcre2_match_data *md = pcre2_match_data_create_from_pattern(re, NULL);
  double t0 = now(); long lines = 0, matched = 0, bytes = 0;
  for (char *p = buf; *p; ) {
    char *nl = strchr(p, '\n'); size_t len = nl ? (size_t)(nl - p) : strlen(p);
    int rc = pcre2_match(re, (PCRE2_SPTR)p, len, 0, 0, md, NULL);
    if (rc > 0) { PCRE2_SIZE *ov = pcre2_get_ovector_pointer(md); matched++; for (int g = 1; g < rc; g++) bytes += ov[2*g+1] - ov[2*g]; }
    lines++; p = nl ? nl + 1 : p + len;
  }
  printf("%s: %ld lines, %ld matched, jit=%d, %.3fs\n", argv[1], lines, matched, jit, now() - t0);
  return 0;
}
