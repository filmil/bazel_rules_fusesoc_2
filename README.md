# Bazel rules for fusesoc (EDA automation)

[![Test](https://github.com/filmil/bazel_rules_fusesoc_2/actions/workflows/test.yml/badge.svg)](https://github.com/filmil/bazel_rules_fusesoc_2/actions/workflows/test.yml)
[![Tag and Release](https://github.com/filmil/bazel_rules_fusesoc_2/actions/workflows/tag-and-release.yml/badge.svg)](https://github.com/filmil/bazel_rules_fusesoc_2/actions/workflows/tag-and-release.yml)
[![Publish to my Bazel registry](https://github.com/filmil/bazel_rules_fusesoc_2/actions/workflows/publish.yml/badge.svg)](https://github.com/filmil/bazel_rules_fusesoc_2/actions/workflows/publish.yml)

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
cd integration && bazel build //... && cat bazel-bin/fusesoc.txt
```
