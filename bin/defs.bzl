def include_from_binary(name, src):
    """Produces a sequence of byte definitions for including into an
    assembly source.

    Args:
      name: the name of this bazel target.
      src: a source to be disasembled, usually a single file, or a filegroup
           with a single file in it.
    """
    _out = "{name}.h".format(name=name)
    native.genrule(
        name = name,
        outs = [ _out ],
        srcs = [ src ],
        cmd_bash = """
        $(location //build/bin/bintoinc) < $(location {inf}) > $(location {out})
        """.format(inf=src, out=_out),
        tags = [ "manual", "no-sandbox" ],
        tools = [
            "//build/bin/bintoinc",
        ]
    )
