# Flags from letters or names

Turns flags written as text into the integer flags
[`hs_compile()`](https://pedrobtz.github.io/vectorscan/reference/hs_compile.md)
takes.
[`hs_compile()`](https://pedrobtz.github.io/vectorscan/reference/hs_compile.md)
and the verbs call it for flags given as strings, so `flags = "i"` and
`flags = HS_FLAG_CASELESS` compile the same database.

## Usage

``` r
hs_flags(x)
```

## Arguments

- x:

  A character vector, one string per pattern.

## Value

An integer vector of flags, as long as `x`.

## Details

Each string is either

- letters, as after the closing `/` of an expression in Hyperscan's
  pattern files (see
  [`hs_read_patterns()`](https://pedrobtz.github.io/vectorscan/reference/hs_read_patterns.md)):
  `i` caseless, `s` dotall, `m` multiline, `H` single match, `V` allow
  empty, `8` UTF-8, `W` Unicode properties, `P` prefilter, `L` leftmost
  start of match, `C` combination, `Q` quiet; or

- names separated by `|`, `,` or spaces, with or without the `HS_FLAG_`
  prefix and in any case: `"caseless|dotall"`, `"HS_FLAG_UTF8, ucp"`.

`""` means no flags.

## See also

[vectorscan-constants](https://pedrobtz.github.io/vectorscan/reference/vectorscan-constants.md)
for the flags themselves.

## Examples

``` r
hs_flags("i")
#> [1] 1
hs_flags(c("is", "caseless|dotall", "HS_FLAG_SOM_LEFTMOST", ""))
#> [1]   3   3 256   0
identical(hs_flags("i8"), bitwOr(HS_FLAG_CASELESS, HS_FLAG_UTF8))
#> [1] TRUE
```
