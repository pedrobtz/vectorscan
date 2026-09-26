# Serialize a database

The bytes are exactly what Vectorscan's `hs_serialize_database()`
produces, so they can be deserialized by any compatible Vectorscan or
Hyperscan build. The pattern ids and flags, which Vectorscan does not
store, are attached as the attributes `hs_pattern_ids` and
`hs_pattern_flags`;
[`hs_deserialize()`](https://pedrobtz.github.io/vectorscan/reference/hs_deserialize.md)
uses them to report `from = NA` for patterns compiled without
[HS_FLAG_SOM_LEFTMOST](https://pedrobtz.github.io/vectorscan/reference/vectorscan-constants.md),
as the original database does.

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
#> 1  0   NA  3     0
```
