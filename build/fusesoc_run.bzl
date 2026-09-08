"""Runs FuseSoC over a set of cores as a Bazel action.

FuseSoC and edalize come from the Python packages pinned in
//third_party/fusesoc, through the hermetic interpreter that rules_python
provides. The EDA programs that edalize drives (verilator, iverilog, vvp,
make, ...) are not part of FuseSoC; they arrive through the `tools`
attribute, and the directory of each one goes on PATH ahead of anything else,
because edalize starts them by name.

Nothing is taken from the machine the build runs on.
"""

load("@bazel_skylib//lib:paths.bzl", "paths")

def _fusesoc_run(ctx):
    output_dir_path = "build.{}".format(ctx.label.name)
    output_dir = ctx.actions.declare_directory(output_dir_path)
    outputs = [output_dir]

    # FuseSoC keeps per-user state under $HOME and its download cache under
    # $XDG_CACHE_HOME. Give it directories of its own, or it writes into the
    # home directory of whoever runs the build.
    cache_dir = ctx.actions.declare_directory("cache.{}".format(ctx.label.name))
    outputs += [cache_dir]

    # A file cannot be declared inside a declared directory: Bazel refuses
    # two outputs where one path is a prefix of the other. So the files
    # other rules ask for by name are copied out of the build root, once
    # FuseSoC is done, into a directory of declared files next to it.
    groups = {}
    copies = []
    files_dir = "{}.files".format(ctx.label.name)
    for group, files in ctx.attr.output_groups.items():
        deps = []
        for f in files:
            out = ctx.actions.declare_file(paths.join(files_dir, f))
            deps.append(out)
            copies.append((paths.join(output_dir.path, f), out.path))
        outputs.extend(deps)
        groups[group] = depset(deps)
    copy_cmd = "".join([
        'mkdir -p "$(dirname {dst})" && cp "{src}" "{dst}" && '.format(src = src, dst = dst)
        for src, dst in copies
    ])

    log_file = ctx.actions.declare_file("{}.log".format(output_dir_path))
    outputs += [log_file]

    ref = ctx.attr.cores_root.files.to_list()[0]
    input_dir = paths.dirname(ref.path)
    core_names = " ".join(ctx.attr.systems)

    fusesoc = ctx.attr._fusesoc[DefaultInfo].files_to_run

    # Every executable in `tools` is carried as its FilesToRunProvider, so
    # its runfiles reach the action, and its directory goes on PATH.
    tools = [fusesoc]
    path_dirs = []
    for target in ctx.attr.tools:
        files_to_run = target[DefaultInfo].files_to_run
        if files_to_run and files_to_run.executable:
            tools.append(files_to_run)
            directory = files_to_run.executable.dirname
            if directory not in path_dirs:
                path_dirs.append(directory)
        else:
            tools.append(target.files)

    exports = "".join([
        'export {}="{}"; '.format(k, v)
        for k, v in sorted(ctx.attr.env.items())
    ])

    ctx.actions.run_shell(
        progress_message = "fusesoc {command} {core_names} {tool}-{target}".format(
            core_names = core_names,
            tool = ctx.attr.tool,
            target = ctx.attr.target,
            command = ctx.attr.command,
        ),
        inputs = [ref] + ctx.attr.cores_input.files.to_list(),
        outputs = outputs,
        tools = tools,
        mnemonic = "FuseSoc",
        # PATH entries are absolute because edalize runs its tools from the
        # work root it creates, not from the action's directory.
        command = """\
        export HOME="$PWD/{cache}"; export XDG_CACHE_HOME="$PWD/{cache}"; \
        export PATH="{path}${{PATH:+:$PATH}}"; {exports} \
        {fusesoc} \
          --cores-root={input_dir} \
          {command} \
          --target={target} \
          --tool={tool} \
          --build-root={build_root} \
          {stage_flag} \
          {core_names} > {log_file} 2>&1 || ( cat {log_file} && exit 1); \
        {copy_cmd} true
        """.format(
            copy_cmd = copy_cmd,
            cache = cache_dir.path,
            path = ":".join(["$PWD/" + d for d in path_dirs]),
            exports = exports,
            fusesoc = fusesoc.executable.path,
            target = ctx.attr.target,
            tool = ctx.attr.tool,
            build_root = output_dir.path,
            input_dir = input_dir,
            core_names = core_names,
            log_file = log_file.path,
            command = ctx.attr.command,
            stage_flag = ctx.attr.stage_flag,
        ),
    )

    return [
        DefaultInfo(
            files = depset(outputs),
            runfiles = ctx.runfiles(files = outputs),
        ),
        OutputGroupInfo(**groups),
    ]

fusesoc_run = rule(
    implementation = _fusesoc_run,
    doc = """Runs one FuseSoC command over a set of cores.

The build root FuseSoC writes into is the rule's main output, as a directory.
Files inside it that other rules need are named in `output_groups`; each is
copied out into `<name>.files/<path>` and provided under its group, since a
file inside a directory output cannot be addressed on its own.

Example, a simulation built and run with Icarus Verilog:

```starlark
fusesoc_run(
    name = "hello_sim",
    cores_root = "cores/hello/hello.core",
    cores_input = ":hello_core_files",
    systems = ["example:util:hello:1.0"],
    tool = "icarus",
    target = "sim",
    stage_flag = "--run",
    tools = [
        "@iverilog//:iverilog",
        "@iverilog//:vvp",
        "@make//:make",
    ],
)
```
""",
    attrs = {
        "tool": attr.string(
            default = "verilator",
            doc = "The edalize backend, as FuseSoC's --tool names it.",
        ),
        "target": attr.string(
            default = "sim",
            doc = "The core target, as FuseSoC's --target names it.",
        ),
        "command": attr.string(
            default = "run",
            doc = "The FuseSoC subcommand.",
        ),
        "cores_root": attr.label(
            mandatory = True,
            allow_single_file = True,
            doc = "A file whose directory is passed as --cores-root.",
        ),
        "cores_input": attr.label(
            mandatory = True,
            doc = "Everything under the cores root, so the action can read it.",
        ),
        "stage_flag": attr.string(
            default = "--build",
            doc = "Which stage to stop after: --setup, --build or --run.",
        ),
        "systems": attr.string_list(
            doc = "The cores to run the command for, by VLNV.",
        ),
        # A trick from:
        # https://github.com/lowRISC/opentitan/blob/master/rules/fusesoc.bzl#L101
        # Requires knowing the output dir structure. Sigh.
        "output_groups": attr.string_list_dict(
            allow_empty = True,
            doc = "Mapping from an output group name to files under the build root.",
        ),
        "env": attr.string_dict(
            allow_empty = True,
            doc = "Environment variables set for the FuseSoC run.",
        ),
        "tools": attr.label_list(
            allow_empty = True,
            cfg = "exec",
            doc = "Executables the edalize backend starts by name: the " +
                  "simulator, make, and whatever else the tool needs. " +
                  "Each one's directory goes on PATH, first. A target " +
                  "that is not an executable is made available as a file.",
        ),
        "_fusesoc": attr.label(
            default = Label("//third_party/fusesoc:run_fusesoc"),
            executable = True,
            cfg = "exec",
        ),
    },
)
