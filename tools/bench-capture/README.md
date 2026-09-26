# Capture-groups benchmark (M0)

The numbers behind `.agents/capture-groups.md`. Nothing here ships in the
package.

```sh
Rscript gen.R          # writes log_1.txt and log_0.01.txt (1M lines each)
Rscript base.R         # utils::strcapture(), regexec(), grepl()

# (a) PCRE2 + JIT
cc -O2 pcre2cap.c $(pkg-config --cflags --libs libpcre2-8) -o pcre2cap
./pcre2cap log_1.txt && ./pcre2cap log_0.01.txt

# (b) Chimera: needs a Vectorscan build with Chimera and PCRE 8.45 (see the
# plan's "Not chosen" section for the patches that took)
cc -O2 chcap.c -I<vectorscan>/chimera -I<vectorscan>/src -I<build> \
  -L<build>/lib -lchimera -lhs -lpcre -lc++ -o chcap
./chcap log_1.txt && ./chcap log_0.01.txt
```
