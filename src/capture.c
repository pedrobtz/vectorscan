/* PCRE2, the engine behind hs_capture(). Built only when configure found a
   PCRE2 (system or vendored); see .agents/capture-groups.md. */

#define R_NO_REMAP
#include <R.h>
#include <Rinternals.h>
#include <string.h>

#ifdef HAVE_PCRE2

#ifndef PCRE2_CODE_UNIT_WIDTH
#define PCRE2_CODE_UNIT_WIDTH 8
#endif
#include <pcre2.h>

/* list(version = "10.48 2026-...", jit = TRUE/FALSE, source = "system" or
   "vendored"). `jit` is whether this PCRE2 was built with JIT support; a
   pattern can still fall back to the interpreter at run time. */
SEXP vctrsn_pcre2_info(void) {
  char version[64] = "";
  pcre2_config(PCRE2_CONFIG_VERSION, version);
  uint32_t jit = 0;
  pcre2_config(PCRE2_CONFIG_JIT, &jit);

  SEXP out = PROTECT(Rf_allocVector(VECSXP, 3));
  SEXP names = PROTECT(Rf_allocVector(STRSXP, 3));
  SET_STRING_ELT(names, 0, Rf_mkChar("version"));
  SET_STRING_ELT(names, 1, Rf_mkChar("jit"));
  SET_STRING_ELT(names, 2, Rf_mkChar("source"));
  Rf_setAttrib(out, R_NamesSymbol, names);
  SET_VECTOR_ELT(out, 0, Rf_mkString(version));
  SET_VECTOR_ELT(out, 1, Rf_ScalarLogical(jit != 0));
#ifdef VCTRSN_PCRE2_VENDORED
  SET_VECTOR_ELT(out, 2, Rf_mkString("vendored"));
#else
  SET_VECTOR_ELT(out, 2, Rf_mkString("system"));
#endif
  UNPROTECT(2);
  return out;
}

/* -- compiled patterns ------------------------------------------------------ */

static void pcre2_code_finalizer(SEXP xptr) {
  pcre2_code *code = (pcre2_code *)R_ExternalPtrAddr(xptr);
  if (code != NULL) {
    pcre2_code_free(code);
    R_ClearExternalPtr(xptr);
  }
}

static pcre2_code *pcre2_code_addr(SEXP xptr) {
  if (TYPEOF(xptr) != EXTPTRSXP) {
    Rf_error("Internal error: PCRE2 pattern pointer is invalid.");
  }
  pcre2_code *code = (pcre2_code *)R_ExternalPtrAddr(xptr);
  if (code == NULL) {
    Rf_error("PCRE2 pattern pointer is no longer valid.");
  }
  return code;
}

/* Compile `pattern` (a UTF-8 string) as base R's regexec(perl = TRUE) does:
   PCRE2_UTF without PCRE2_UCP. JIT-compile it when this PCRE2 can; a JIT
   failure only means the interpreter runs instead.

   Returns list(ptr, names, jit): `names` has one entry per capture group,
   "" for unnamed groups. */
SEXP vctrsn_pcre2_compile(SEXP pattern) {
  const char *text = Rf_translateCharUTF8(STRING_ELT(pattern, 0));
  int errcode = 0;
  PCRE2_SIZE erroffset = 0;
  pcre2_code *code = pcre2_compile((PCRE2_SPTR)text, PCRE2_ZERO_TERMINATED,
                                   PCRE2_UTF, &errcode, &erroffset, NULL);
  if (code == NULL) {
    PCRE2_UCHAR message[256];
    pcre2_get_error_message(errcode, message, sizeof(message));
    Rf_error("Invalid pattern at offset %d: %s", (int)erroffset,
             (const char *)message);
  }

  SEXP xptr = PROTECT(R_MakeExternalPtr(code, R_NilValue, R_NilValue));
  R_RegisterCFinalizerEx(xptr, pcre2_code_finalizer, TRUE);

  int jit = pcre2_jit_compile(code, PCRE2_JIT_COMPLETE) == 0;

  uint32_t ncap = 0;
  pcre2_pattern_info(code, PCRE2_INFO_CAPTURECOUNT, &ncap);
  SEXP names = PROTECT(Rf_allocVector(STRSXP, ncap));
  for (uint32_t g = 0; g < ncap; ++g) {
    SET_STRING_ELT(names, g, R_BlankString);
  }

  /* Name table entries: a 2-byte group number, then the NUL-terminated
     name, padded to `entry_size`. */
  uint32_t name_count = 0, entry_size = 0;
  PCRE2_SPTR table = NULL;
  pcre2_pattern_info(code, PCRE2_INFO_NAMECOUNT, &name_count);
  pcre2_pattern_info(code, PCRE2_INFO_NAMEENTRYSIZE, &entry_size);
  pcre2_pattern_info(code, PCRE2_INFO_NAMETABLE, &table);
  for (uint32_t k = 0; k < name_count; ++k) {
    PCRE2_SPTR entry = table + (size_t)k * entry_size;
    uint32_t group = ((uint32_t)entry[0] << 8) | entry[1];
    if (group >= 1 && group <= ncap) {
      SET_STRING_ELT(names, group - 1,
                     Rf_mkCharCE((const char *)(entry + 2), CE_UTF8));
    }
  }

  SEXP out = PROTECT(Rf_allocVector(VECSXP, 3));
  SEXP out_names = PROTECT(Rf_allocVector(STRSXP, 3));
  SET_STRING_ELT(out_names, 0, Rf_mkChar("ptr"));
  SET_STRING_ELT(out_names, 1, Rf_mkChar("names"));
  SET_STRING_ELT(out_names, 2, Rf_mkChar("jit"));
  Rf_setAttrib(out, R_NamesSymbol, out_names);
  SET_VECTOR_ELT(out, 0, xptr);
  SET_VECTOR_ELT(out, 1, names);
  SET_VECTOR_ELT(out, 2, Rf_ScalarLogical(jit));
  UNPROTECT(4);
  return out;
}

/* -- capturing over a character vector ------------------------------------- */

/* PCRE2's per-call allocations (the match data) come from R_alloc(), which
   R reclaims itself if the call is left by an error or an interrupt, so no
   exit path can leak them. */
static void *r_alloc_for_pcre2(size_t size, void *unused) {
  (void)unused;
  return R_alloc(size, 1);
}

static void r_free_for_pcre2(void *ptr, void *unused) {
  (void)ptr;
  (void)unused;
}

/* Match every element of `x` once (the first match, as regexec() does) and
   fill one character column per capture group in place.

   Returns list(matched, groups, errors):
   - matched: TRUE / FALSE per element, NA for NA input or a PCRE2 error;
   - groups:  list of character vectors, NA where the element did not match
              or the group did not participate;
   - errors:  the PCRE2 error code per element, 0 where there was none. */
SEXP vctrsn_pcre2_capture_many(SEXP code_xptr, SEXP x) {
  pcre2_code *code = pcre2_code_addr(code_xptr);
  R_xlen_t n = XLENGTH(x);

  uint32_t ncap = 0;
  pcre2_pattern_info(code, PCRE2_INFO_CAPTURECOUNT, &ncap);

  SEXP matched = PROTECT(Rf_allocVector(LGLSXP, n));
  SEXP errors = PROTECT(Rf_allocVector(INTSXP, n));
  SEXP groups = PROTECT(Rf_allocVector(VECSXP, ncap));
  for (uint32_t g = 0; g < ncap; ++g) {
    SET_VECTOR_ELT(groups, g, Rf_allocVector(STRSXP, n));
  }
  int *matched_p = LOGICAL(matched);
  int *errors_p = INTEGER(errors);

  pcre2_general_context *gcontext =
      pcre2_general_context_create(r_alloc_for_pcre2, r_free_for_pcre2, NULL);
  pcre2_match_data *md = pcre2_match_data_create_from_pattern(code, gcontext);
  if (gcontext == NULL || md == NULL) {
    Rf_error("Out of memory while preparing a PCRE2 match.");
  }

  /* Each subject is scanned from our own buffer with zeroed padding after
     it. PCRE2's JIT scans with wide loads that may read a little past the
     end of the subject (within the same page, so safely); from R's heap
     those bytes are neighbouring objects, which valgrind reports as
     uninitialised. The buffer is R_alloc()ed and only ever grown before the
     per-element vmax mark, so it survives the loop and cannot leak. */
  char *buffer = NULL;
  size_t capacity = 0;
  const size_t padding = 64;

  for (R_xlen_t i = 0; i < n; ++i) {
    if ((i & 1023) == 1023) {
      R_CheckUserInterrupt();
    }

    errors_p[i] = 0;
    SEXP element = STRING_ELT(x, i);
    int rc = PCRE2_ERROR_NOMATCH;
    PCRE2_SIZE *ov = NULL;
    const char *text = NULL;

    if (element != NA_STRING) {
      /* An upper bound on the element's UTF-8 length: translation from any
         R encoding at most quadruples the byte count. */
      size_t need = 4 * (size_t)LENGTH(element) + padding;
      if (need > capacity) {
        capacity = need > 2 * capacity ? need : 2 * capacity;
        buffer = R_alloc(capacity, 1);
      }
    }

    const void *vmax = vmaxget();
    if (element == NA_STRING) {
      matched_p[i] = NA_LOGICAL;
    } else {
      const char *utf8 = Rf_translateCharUTF8(element);
      size_t length = strlen(utf8);
      if (length + padding > capacity) {
        Rf_error("Internal error: UTF-8 string longer than expected.");
      }
      memcpy(buffer, utf8, length);
      memset(buffer + length, 0, padding);
      text = buffer;
      rc = pcre2_match(code, (PCRE2_SPTR)text, length, 0, 0, md, NULL);
      if (rc > 0) {
        matched_p[i] = TRUE;
        ov = pcre2_get_ovector_pointer(md);
      } else if (rc == PCRE2_ERROR_NOMATCH) {
        matched_p[i] = FALSE;
      } else {
        matched_p[i] = NA_LOGICAL;
        errors_p[i] = rc;
      }
    }

    for (uint32_t g = 1; g <= ncap; ++g) {
      SEXP column = VECTOR_ELT(groups, g - 1);
      if (ov != NULL && (int)g < rc && ov[2 * g] != PCRE2_UNSET) {
        SET_STRING_ELT(column, i,
                       Rf_mkCharLenCE(text + ov[2 * g],
                                      (int)(ov[2 * g + 1] - ov[2 * g]),
                                      CE_UTF8));
      } else {
        SET_STRING_ELT(column, i, NA_STRING);
      }
    }
    /* Releases what translateCharUTF8() took, never the match data, which
       was allocated before the loop. */
    vmaxset(vmax);
  }

  SEXP out = PROTECT(Rf_allocVector(VECSXP, 3));
  SEXP names = PROTECT(Rf_allocVector(STRSXP, 3));
  SET_STRING_ELT(names, 0, Rf_mkChar("matched"));
  SET_STRING_ELT(names, 1, Rf_mkChar("groups"));
  SET_STRING_ELT(names, 2, Rf_mkChar("errors"));
  Rf_setAttrib(out, R_NamesSymbol, names);
  SET_VECTOR_ELT(out, 0, matched);
  SET_VECTOR_ELT(out, 1, groups);
  SET_VECTOR_ELT(out, 2, errors);
  UNPROTECT(5);
  return out;
}

#else

SEXP vctrsn_pcre2_info(void) { return R_NilValue; }

static SEXP no_pcre2(void) {
  Rf_error("This build of vectorscan has no PCRE2, so capture groups are unavailable.");
  return R_NilValue;
}

SEXP vctrsn_pcre2_compile(SEXP pattern) { return no_pcre2(); }

SEXP vctrsn_pcre2_capture_many(SEXP code_xptr, SEXP x) { return no_pcre2(); }

#endif
