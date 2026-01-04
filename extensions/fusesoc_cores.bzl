load(":fusesoc_repo.bzl", "fusesoc_repo")

def _impl(mctx):
    seen_libs = {}
    seen_cores = []
    seen_configs = []
    cmdlines = []
    for module in mctx.modules:
        for library in module.tags.library:
            url = library.url
            if url in seen_libs.keys():
                continue
            seen_libs |= {library.url: library.name}

        for core in module.tags.core:
            name = core.name
            config = "{name}_{command}_{tool}_{phase}_{target}".format(
                name = core.name,
                command = core.command,
                tool = core.tool,
                phase = core.phase,
                target = core.target,
            )
            if not name in seen_cores:
                seen_cores += [name]
            if config in seen_configs:
                continue
            seen_configs += [config]

            cmdline = "{command} --tool {tool} {phase}".format(
                command = core.command,
                tool = core.tool,
                phase = core.phase,
            )
            if core.target:
                cmdline = "{} --target {target}".format(
                    cmdline, target = core.target)
            cmdline = "{} {core}".format(cmdline, core = core.name)
            cmdlines += [cmdline]


    fusesoc_repo(
        name = "fusesoc_cores",
        libraries = seen_libs,
        cores = seen_cores,
        cmdlines = cmdlines,
    )

_library = tag_class(
    attrs = {
        "name": attr.string(
            mandatory = True,
        ),
        "url": attr.string(
            mandatory = True,
        ),
    },
)
_core = tag_class(
    attrs = {
        "name": attr.string(mandatory = True),
        "command": attr.string(default = "run"),
        "tool": attr.string(default = "vivado"),
        "phase": attr.string(default = "--setup"),
        "target": attr.string(),
    }
)

fusesoc_cores = module_extension(
    implementation = _impl,
    tag_classes = {
        "library": _library,
        "core": _core,
    },
)
