# Integration test repository for `rules_fusesoc`

## Testing

```
bazel build //... && cat bazel-bin/fusesoc.txt
```

The above should print the `fusesoc` help page. The `fusesoc` instance is a
hermetic instance installed by `bazel`.

