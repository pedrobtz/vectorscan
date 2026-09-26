# Create extended expression parameters

`hs_ext()` creates extended compile parameters for one expression.

## Usage

``` r
hs_ext(
  min_offset = NULL,
  max_offset = NULL,
  min_length = NULL,
  edit_distance = NULL,
  hamming_distance = NULL
)
```

## Arguments

- min_offset, max_offset, min_length:

  Optional non-negative offsets.

- edit_distance, hamming_distance:

  Optional non-negative distances.

## Value

An object that can be passed to
[`hs_compile()`](https://pedrobtz.github.io/vectorscan/reference/hs_compile.md)
through `ext`.

## Examples

``` r
hs_ext(min_length = 3)
#> $flags
#> [1] 4
#> 
#> $min_offset
#> [1] 0
#> 
#> $max_offset
#> [1] 0
#> 
#> $min_length
#> [1] 3
#> 
#> $edit_distance
#> [1] 0
#> 
#> $hamming_distance
#> [1] 0
#> 
#> attr(,"class")
#> [1] "hs_ext"
```
