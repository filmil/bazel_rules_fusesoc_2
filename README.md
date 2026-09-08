# Bazel rules for fusesoc (EDA automation)

[![Test](https://github.com/filmil/bazel_rules_fusesoc_2/actions/workflows/test.yml/badge.svg)](https://github.com/filmil/bazel_rules_fusesoc_2/actions/workflows/test.yml)
[![Tag and Release](https://github.com/filmil/bazel_rules_fusesoc_2/actions/workflows/tag-and-release.yml/badge.svg)](https://github.com/filmil/bazel_rules_fusesoc_2/actions/workflows/tag-and-release.yml)
[![Publish to my Bazel registry](https://github.com/filmil/bazel_rules_fusesoc_2/actions/workflows/publish.yml/badge.svg)](https://github.com/filmil/bazel_rules_fusesoc_2/actions/workflows/publish.yml)
[![Publish to the Bazel Central Registry](https://github.com/filmil/bazel_rules_fusesoc_2/actions/workflows/publish-bcr.yml/badge.svg)](https://github.com/filmil/bazel_rules_fusesoc_2/actions/workflows/publish-bcr.yml)

Bazel rules that run [FuseSoC][fusesoc] and [edalize][edalize] as build
actions, and a module extension that fetches FuseSoC core libraries and turns
each core's file lists into Bazel filegroups.

Nothing is taken from the machine the build runs on.
FuseSoC and edalize are Python packages pinned in
`third_party/fusesoc/requirements_lock.txt` and run through the interpreter
`rules_python` provides.
The EDA programs edalize drives are not part of FuseSoC; a `fusesoc_run`
target names them in `tools`, and they come from Bazel too, for example
`@verilator` from the Bazel Central Registry.

[fusesoc]: https://github.com/olofk/fusesoc
[edalize]: https://github.com/olofk/edalize

## Rules

### `fusesoc_run`

Runs one FuseSoC command over a set of cores.
The build root FuseSoC writes into is the rule's main output, as a directory;
files inside it that other rules need are named in `output_groups` and
provided under those group names.

```starlark
load("@rules_fusesoc//build:fusesoc_run.bzl", "fusesoc_run")

fusesoc_run(
    name = "hello_setup",
    cores_root = "cores/hello/hello.core",
    cores_input = ":hello_core_files",
    systems = ["example:util:hello:1.0"],
    target = "sim",
    tool = "verilator",
    stage_flag = "--setup",
)
```

`tools` lists the executables the edalize backend starts by name: the
simulator, `make`, and whatever else the backend needs.
Each one's directory goes first on `PATH` for the run.
The full attribute list is in `build/fusesoc_run.bzl`.

### `fusesoc_cores` extension

See `integration/MODULE.bazel` for a complete example: it registers two core
libraries, asks for cores by VLNV, and `integration/BUILD.bazel` then uses the
generated filegroups with `rules_verilator`.

The extension runs a released FuseSoC binary at fetch time, because a
repository rule cannot run a binary Bazel has yet to build.
That binary is built from this repository's own pinned requirements and
uploaded with each release; `fusesoc_repo` pins the release it uses by
version and checksum.

## Maintenance

### Example run

Run the hermetic `fusesoc`:

```
bazel run //third_party/fusesoc:run_fusesoc -- --help
```

### Updating the list of fusesoc python dependencies

```
bazel run //third_party/fusesoc:requirements.update
```

### Example use in a repository

```
cd integration && bazel build //... && cat bazel-bin/fusesoc.txt
```
