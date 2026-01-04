
def _impl(rctx):
    rctx.execute(["touch", "fusesoc.conf"])
    rctx.download_and_extract(
        url = rctx.attr.fusesoc_url,
        strip_prefix = "fusesoc",
    )

    fusesoc_path = "./bin/fusesoc.shar"

    result = rctx.execute(["pwd"])
    pwd = result.stdout.strip()

    cmdline = [
        str(fusesoc_path),
        "--cores-root={}".format(pwd),
        "--config={}/fusesoc.conf".format(pwd),
    ]


    for library, name in rctx.attr.libraries.items():
        cmdlineX = cmdline +            ["library",
            "add",
            "--sync-type", "git",
            name,
            library,]
        result = rctx.execute(cmdlineX)
        if result.return_code:
            print("result", library, result.stdout)
            print("result", library, result.stderr)
            fail("oops")

    result = rctx.execute(cmdline + [
        "library", "update"
    ])
    if result.return_code:
        print("update:", result)

    result = rctx.execute(["ls", "-laR"])


    result = rctx.execute(cmdline + [
        "library", "list"
    ])
    if result.return_code:
        print("list: ", result)


    for core in rctx.attr.cores:
        result = rctx.execute(cmdline + [
            "fetch",
            core,
        ])
        if result.return_code:
            print("result", core, result.stdout)
            print("result", core, result.stderr)
            fail("oops")

    rctx.execute(cmdline + ["library", "list"])
    if result.return_code:
        print("result", result.stdout)
        print("result", result.stderr)
        fail("oops")

    # Don't get confused about any cores that have BUILD files.
    rctx.execute(["bash", "-c", "find -name 'BUILD*' | xargs rm"])

    for cmdline_fragment in rctx.attr.cmdlines:
        cmdline_list = cmdline_fragment.split(' ')
        cmdline_all = cmdline + cmdline_list
        result = rctx.execute(cmdline_all)
        if result.return_code:
            print(cmdline_all)
            print("run stdout:", core, result.stdout)
            print("run stderr", core, result.stderr)
            fail("oops")

    for core in rctx.attr.cores:
        result = rctx.execute(cmdline + [
            "run",
            "--setup",
            "--tool", "vivado",
            core,
        ])
        if result.return_code:
            print("run stdout:", core, result.stdout)
            print("run stderr", core, result.stderr)
            fail("oops")

    rctx.file("BUILD.bazel", content = """\
package(default_visibility = ["//visibility:public"])

exports_files(glob(["build/**", "fusesoc_libraries/**"]))

filegroup(
    name = "config",
    srcs = [
        "fusesoc.conf",
    ],
)

filegroup(
    name = "libraries",
    srcs = glob(
        ["fusesoc_libraries/**"],
        exclude = [ "**/.git/**", "**/BUILD"],
    ),
)

filegroup(
    name = "all",
    srcs = glob(["**/*"], exclude = ["bin/**", "**/BUILD"]),
)
    """)



fusesoc_repo = repository_rule(
    implementation = _impl,
    attrs = {
        "repo_name": attr.string_list(),
        "libraries": attr.string_dict(),
        "cores": attr.string_list(),
        "fusesoc_url": attr.string(
            default = "https://github.com/filmil/bazel_rules_fusesoc_2/releases/download/v0.5.0/fusesoc-bin-linux-amd64.zip",
        ),
        "cmdlines": attr.string_list(
            default = [],
        ),
    },
)
