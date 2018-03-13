filegroup(
    name = "srcs",
    srcs = glob(
        ["**"],
        exclude = [
            "*~",
            ".*",
        ],
    ),
    visibility = ["//tools:__pkg__"],
)

filegroup(
    name = "embedded_tools_srcs",
    srcs = [":srcs"],
    visibility = ["//tools:__pkg__"],
)
