load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")

swift_library(
    name = "AIAgent",
    module_name = "AIAgent",
    srcs = [
        "Sources/AIAgent.swift",
        "Sources/TestAIAgentController.swift",
        "Sources/SmallGroupsMessageManager.swift",
        "Sources/AgentServiceManager.swift",
        "Sources/AgentNetworkCenter.swift",
        "Sources/AgentChatHistoryManager.swift",
        "Sources/SummaryPromptConfig.swift",
        "Sources/Chat/AIAgentController.swift",
        "Sources/Chat/AIAgentControllerExtension.swift",
        "Sources/Chat/ChatHistoryListItem.swift",
        "Sources/Chat/ChatHistoryListItemNode.swift",
        # 移除了 MomentEntry.swift, MomentItemNode.swift, MomentListItem.swift - 这些组件已不再使用
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
        "//submodules/ItemListUI:ItemListUI",
    ],
    visibility = [
        "//visibility:public",
    ],
)
