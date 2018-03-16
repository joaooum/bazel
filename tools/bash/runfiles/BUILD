package(default_visibility = ["//visibility:public"])

filegroup(
    name = "srcs",
    srcs = glob(
        ["**"],
        exclude = [
            "*~",
            ".*",
        ],
    ),
    visibility = ["//tools/bash:__pkg__"],
)

filegroup(
    name = "embedded_tools",
    srcs = [
        "BUILD.tools",
        "runfiles.sh",
    ],
    visibility = ["//tools/bash:__pkg__"],
)

sh_library(
    name = "runfiles_sh_lib",
    srcs = ["runfiles.sh"],
)

sh_test(
    name = "runfiles_sh_test",
    srcs = select({
        "//src/conditions:windows": ["runfiles_windows_test.sh"],
        "//conditions:default": ["runfiles_posix_test.sh"],
    }),
    deps = [":runfiles_sh_lib"],
)

test_suite(
    name = "windows_tests",
    tags = [
        "-no_windows",
        "-slow",
    ],
)

test_suite(
    name = "all_windows_tests",
    tests = [
        ":windows_tests",
    ],
    visibility = ["//tools:__pkg__"],
)
