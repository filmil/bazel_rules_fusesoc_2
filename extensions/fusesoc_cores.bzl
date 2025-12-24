load(":fusesoc_repo.bzl", "fusesoc_repo")

def _impl(mctx):
    # install libraries
    seen_libs = {}
    seen_cores = []
    for module in mctx.modules:
        for library in module.tags.library:
            url = library.url
            if url in seen_libs.keys():
                continue
            seen_libs |= {library.url: library.name}

        for core in module.tags.core:
            name = core.name
            if name in seen_cores:
                continue
            seen_cores += [name]
    fusesoc_repo(
        name = "fusesoc_cores",
        libraries = seen_libs,
        cores = seen_cores
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
        "name": attr.string(),
    }
)

fusesoc_cores = module_extension(
    implementation = _impl,
    tag_classes = {
        "library": _library,
        "core": _core,
    },
)
