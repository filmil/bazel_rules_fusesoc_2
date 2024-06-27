# Bazel rules for fusesoc (EDA automation) [![Test status](https://github.com/filmil/bazel_rules_fusesoc_2/workflows/Test/badge.svg)](https://github.com/filmil/bazel_rules_fusesoc_2/workflows/Test/badge.svg)

For the time being, tis is a demo only. Don't read too much into it.

## Maintenance

### Example run

Install and run `fusesoc`:

```
bazel run //third_party/fusesoc -- --help
```

### Updating the list of fusesoc python dependencies.

```
bazel run //third_party/fusesoc:requirements.update
```

### Example use in a repository

```
cd integration && bazel build //...
```
