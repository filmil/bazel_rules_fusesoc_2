
def _impl(rctx):
    fusesoc_path = rctx.path(rctx.attr._fusesoc)
    rctx.file("BUILD.bazel", content = """\
filegroup(
    name = "all",
    srcs = glob(["**"]),
)
    """)

    result = rctx.execute(["pwd"])
    pwd = result.stdout.strip()
    print("pwd:", pwd)

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
        print (cmdlineX)
        result = rctx.execute(cmdlineX)
        if result.return_code:
            print("result", library, result.stdout)
            print("result", library, result.stderr)
            fail("oops")

    result = rctx.execute(cmdline + [
        "library", "update"
    ])
    print("update:", result.stdout)

    result = rctx.execute(cmdline + [
        "library", "list"
    ])
    print("list:\n", result.stdout)


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


fusesoc_repo = repository_rule(
    implementation = _impl,
    attrs = {
        "repo_name": attr.string_list(),
        "libraries": attr.string_dict(),
        "cores": attr.string_list(),
        "_fusesoc": attr.label(
            default = Label("//third_party/fusesoc:fusesoc.shar"),
            executable = True,
            cfg = "host",
        ),
    },
)
