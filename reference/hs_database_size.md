# Get database size

Get database size

## Usage

``` r
hs_database_size(database)
```

## Arguments

- database:

  A compiled `hs_database` object.

## Value

Database size in bytes.

## Examples

``` r
if (hs_available()) {
  db <- hs_database()
  hs_compile(db, "foo")
  hs_database_size(db)
}
#> [1] 1000
```
