filegroup(
    name = "srcs",
    srcs = glob(
        ["**"],
        exclude = [
            "*~",
            ".*",
        ],
    ) + [
        "//tools/bash/runfiles:srcs",
    ],
    visibility = ["//tools:__pkg__"],
)

filegroup(
    name = "embedded_tools",
    srcs = glob(
        ["**"],
        exclude = [
            "*~",
            ".*",
        ],
    ) + [
        "//tools/bash/runfiles:embedded_tools",
    ],
    visibility = ["//tools:__pkg__"],
)
