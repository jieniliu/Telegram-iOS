load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")

swift_library(
    name = "AIAgent",
    module_name = "AIAgent",
    srcs = glob([
		"Sources/**/*.swift",
    ]),
    copts = [
        "-warnings-as-errors",
    ],
    deps = [
        "//submodules/Markdown",
    ],
    visibility = [
        "//visibility:public",
    ],
)
