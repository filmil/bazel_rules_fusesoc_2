# Bazel rules for fusesoc (EDA automation)

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
