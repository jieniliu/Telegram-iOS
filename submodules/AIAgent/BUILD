load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")

swift_library(
    name = "AIAgent",
    module_name = "AIAgent",
    srcs = [
        "Sources/AIAgent.swift",
        "Sources/AIAgentController.swift",
        "Sources/SmallGroupsMessageManager.swift",
        "Sources/AgentServiceManager.swift",
        "Sources/AgentNetworkCenter.swift",
        "Sources/AgentChatHistoryManager.swift",
        "Sources/SummaryPromptConfig.swift",
    ],
    copts = [
    ],
    deps = [
        "//submodules/SSignalKit/SwiftSignalKit:SwiftSignalKit",
        "//submodules/AsyncDisplayKit:AsyncDisplayKit",
        "//submodules/Display:Display",
        "//submodules/Postbox:Postbox",
        "//submodules/AccountContext:AccountContext",
        "//submodules/TelegramCore:TelegramCore",
        "//submodules/TelegramPresentationData:TelegramPresentationData",
        "//submodules/PresentationDataUtils:PresentationDataUtils",
        "//submodules/TelegramUIPreferences:TelegramUIPreferences",
        "//submodules/UIKitRuntimeUtils:UIKitRuntimeUtils",
    ],
    visibility = [
        "//visibility:public",
    ],
)
