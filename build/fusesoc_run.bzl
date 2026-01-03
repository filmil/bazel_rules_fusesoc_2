load("@bazel_skylib//lib:paths.bzl", "paths")
load("@bazel_rules_bid//build:rules.bzl", "run_docker_cmd")


CONTAINER = "filipfilmar/eda_tools:0.0"


def _script_cmd(
    script_path,
    dir_reference,
    cache_dir,
    source_dir="", mounts=None, envs=None, tools=None):
    return run_docker_cmd(
        CONTAINER,
        script_path,
        dir_reference,
        scratch_dir="{}:/.cache".format(cache_dir),
        source_dir=source_dir,
        mounts=mounts,
        envs=envs,
        tools=tools,
    )


def _fusesoc_run(ctx):
    cmd = "fusesoc"
    docker_run = ctx.executable._script
    output_dir_path = "build.{}".format(ctx.label.name)
    output_dir = ctx.actions.declare_directory(output_dir_path)
    outputs = [output_dir]
    cache_dir = ctx.actions.declare_directory("cache.{}".format(ctx.label.name))
    outputs += [cache_dir]
    # A fusesoc convention on output subdirectories.
    target_tool = "{}-{}".format(ctx.attr.target, ctx.attr.tool)
    groups = {}
    for group, files in ctx.attr.output_groups.items():
        deps = [
            ctx.actions.declare_file(
                paths.join(
                    paths.basename(output_dir.path),
                    f,
                )
            ) for f in files]
        outputs.extend(deps)
        groups[group] = depset(deps)

    log_file = ctx.actions.declare_file(paths.join(output_dir_path, "output.log"))
    outputs += [log_file]

    ref = ctx.attr.cores_root.files.to_list()[0]
    input_dir = paths.dirname(ref.path)
    allfiles = ctx.attr.cores_input.files.to_list()
    core_names = " ".join(ctx.attr.systems)
    envs_dict = ctx.attr.env
    mounts = ctx.attr.mount
    envs = sorted([ "{}={}".format(k, v) for k, v in envs_dict.items() ])

    # tools.
    tools = ctx.attr.tools
    tools_expanded = []
    tools_depsets = []
    for tool_target in tools:
        files = tool_target.files
        tools_depsets += [ files ]
        for tool_file in files.to_list():
            tools_expanded += [ tool_file.path ]

    script = _script_cmd(
        docker_run.path,
        output_dir.path,
        cache_dir.path,
        envs=",".join(envs),
        mounts=",".join(mounts),
        tools=",".join(tools_expanded),
    )
    ctx.actions.run_shell(
        progress_message = \
            "{cmd} {command} {core_names} {tool}-{target}".format(
            cmd=cmd, core_names=core_names, tool=ctx.attr.tool,
            target=ctx.attr.target,
            command=ctx.attr.command,
        ),
        inputs = [ref] + allfiles,
        outputs = outputs,
        tools = tools_depsets + [docker_run],
        mnemonic = "FuseSoc",
        command = """\
        {script} \
          {cmd} \
          --cores-root={input_dir} \
          {command} \
          --target={target} \
          --tool={tool} \
          --build-root={build_root} \
          {stage_flag} \
          {core_names} 2>&1 &> {log_file} || ( echo {log_file} && exit 1)
        """.format(
            script=script,
            cmd=cmd,
            target=ctx.attr.target,
            tool=ctx.attr.tool,
            build_root=output_dir.path,
            input_dir=input_dir,
            core_names=core_names,
            log_file=log_file.path,
            command=ctx.attr.command,
            stage_flag=ctx.attr.stage_flag,
        ),
    )

    return [
        DefaultInfo(
            files = depset(outputs),
            runfiles = ctx.runfiles(files=outputs),
        ),
        OutputGroupInfo(**groups),
    ]


fusesoc_run = rule(
    implementation = _fusesoc_run,
    attrs = {
        "tool": attr.string(
            default="verilator",
        ),
        "target": attr.string(
            default="sim",
        ),
        "command": attr.string(
            default = "run",
        ),
        "cores_root": attr.label(
            mandatory = True,
            allow_single_file = True,
        ),
        "cores_input": attr.label(
            mandatory = True,
        ),
        "stage_flag": attr.string(
            default = "--build",
        ),
        "systems": attr.string_list(),
        # A trick from:
        # https://github.com/lowRISC/opentitan/blob/master/rules/fusesoc.bzl#L101
        # Requires knowing the output dir structure. Sigh.
        "output_groups": attr.string_list_dict(
            allow_empty = True,
            doc = "Mapping from a filegroup group name to the list of files",
        ),
        "env": attr.string_dict(
            allow_empty = True,
            doc = "A dictionary of env variables to define for fusesoc run."
        ),
        "mount": attr.string_dict(
            allow_empty = True,
            doc = "A dictionary of mounts to define for the run."
        ),
        "_script": attr.label(
            default = Label("@bazel_rules_bid//build:docker_run"),
            executable = True,
            cfg = "host",
        ),
        "tools": attr.label_list(
            allow_empty= True,
        ),
    },
)
