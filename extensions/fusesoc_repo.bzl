
def _impl(rctx):
    rctx.execute(["touch", "fusesoc.conf"])
    rctx.download_and_extract(
        url = rctx.attr.fusesoc_url.format(
            version = rctx.attr.version,
            os = rctx.os.name,
            arch = rctx.os.arch,
        ),
        strip_prefix = "fusesoc",
    )
    rctx.download_and_extract(
        url = rctx.attr.edalize_read_url.format(
            version = rctx.attr.version,
            os = rctx.os.name,
            arch = rctx.os.arch,
        ),
        strip_prefix = "edalize_read",
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

    rctx.file("BUILD.bazel", content = """\
package(default_visibility = ["//visibility:public"])

exports_files(glob(["fusesoc_libraries/**"]))

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

    edalize_read_path = "./bin/edalize_read"

    result = rctx.execute("find . -name *.eda.yml".split(' '))
    if result.return_code:
        print("result", result.stdout)
        print("result", result.stderr)
        fail("oops")

    loads = []
    filegroups = [
        '\npackage(default_visibility = ["//visibility:public"])\n',
    ]
    last_core_name = None
    for eda_file in result.stdout.strip().split('\n'):
        eda_file_components = eda_file.split('/')
        tool = eda_file_components[-2]
        core_name = eda_file_components[-3]
        print("tool/core: ", tool, core_name)
        safe_name = "{core_name}_{tool}".format(core_name=core_name,tool=tool).replace(
            '.', '_').replace('-', '_')

        print("last_core_name: ", last_core_name)
        print("core_name: ", core_name)
        if last_core_name != core_name:
            if last_core_name:
                content = '\n'.join(loads + filegroups)
                print("CONTENT", content)
                rctx.file(
                    "build/{core_name}/BUILD.bazel".format(core_name=last_core_name),
                    content = '\n'.join(loads + filegroups),
                )
                rctx.file(
                    "build/{core_name}/{core_name}.bzl".format(core_name=last_core_name),
                    content = '\n'.join(loads),
                )
            loads = []
            filegroups = [
                '\npackage(default_visibility = ["//visibility:public"])\n',
            ]

        loads += [
            """load(":{tool}/{core_name}.eda.yml.bzl",
    _{safe_name}_SOURCES = "SOURCES",
    _{safe_name}_HEADERS = "HEADERS",
    {safe_name}_INCLUDE_DIRS = "INCLUDE_DIRS",
)
            """.format(
                tool=tool, core_name=core_name, safe_name=safe_name,
            ),
        ]
        filegroups += [
            """filegroup(name = "{safe_name}_srcs", srcs = _{safe_name}_SOURCES)
""".format(safe_name=safe_name),
            """filegroup(name = "{safe_name}_hdrs", srcs = _{safe_name}_HEADERS)
""".format(safe_name=safe_name),
        ]

        cmdline = [
            edalize_read_path,
            "--source", tool,
            "--edafile", eda_file,
            "--output", "{}.bzl".format(eda_file),
        ]
        result = rctx.execute(cmdline)
        if result.return_code:
            print("result", result.stdout)
            print("result", result.stderr)
            fail("oops")

        last_core_name = core_name

    content = '\n'.join(loads + filegroups)
    print("CONTENT", content)
    rctx.file(
        "build/{core_name}/BUILD.bazel".format(core_name=core_name),
        content = '\n'.join(loads + filegroups),
    )
    rctx.file(
        "build/{core_name}/{core_name}.bzl".format(core_name=last_core_name),
        content = '\n'.join(loads),
    )


fusesoc_repo = repository_rule(
    implementation = _impl,
    attrs = {
        "repo_name": attr.string_list(),
        "libraries": attr.string_dict(),
        "cores": attr.string_list(),
        "version": attr.string(default = "v0.7.3"),
        "fusesoc_url": attr.string(
            default = "https://github.com/filmil/bazel_rules_fusesoc_2/releases/download/{version}/fusesoc-bin-{os}-{arch}.zip",
        ),
        "edalize_read_url": attr.string(
            default = "https://github.com/filmil/bazel_rules_fusesoc_2/releases/download/{version}/edalize_read-bin-{os}-{arch}.zip",
        ),
        "cmdlines": attr.string_list(
            default = [],
        ),
    },
)
