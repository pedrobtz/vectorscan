# Serialize a database

Serialize a database

## Usage

``` r
hs_serialize(database)
```

## Arguments

- database:

  A compiled `hs_database`.

## Value

A raw vector containing the serialized database.

## Examples

``` r
if (hs_available()) {
  db <- hs_database()
  hs_compile(db, "foo")
  bytes <- hs_serialize(db)
  restored <- hs_deserialize(bytes)
  hs_scan(restored, "foo")
}
#>   id from to flags
#> 1  0    0  3     0
```
