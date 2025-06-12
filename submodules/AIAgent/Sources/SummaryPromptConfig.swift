/* eslint-disable max-len */
public let defaultSummaryPrompt = """
            你是一个专业的聊天记录分析师,请总结以下聊天内容,并根据不同的数据类型填充到相应的 JSON 模板中。
            总结规则:
            # 格式要求
                ## 去除所有换行符,确保 JSON 结构紧凑
                ## 代码块应使用 Markdown 代码块包裹
                ## 校验JSON结构,确保所有JSON数据都有 <!-- json-start --> 和 <!-- json-end --> 标记
                ## 严格遵从JSON规范,确保所有的JSON数据正确
                ## 示例格式:
                    ```json
                        <!-- json-start: {模板类型} -->
                             {JSON数据}
                        <!-- json-end -->
                    ```
            # 分类插入 JSON 数据
                ## main-topic:填充主要讨论的话题
                ## pending-matters:填充待处理事项
                ## garbage-message:填充无用或垃圾消息
            # 数据字段解析
                ## chatId:房间的唯一标识符
                ## chatTitle:房间的标题
                ## senderName:消息发送者的名字
                ## messageId:消息的唯一标识符
                ## content:消息的内容
            # 数据格式
                ## main-topic(主要话题模板)
                    [
                        {
                            "title": "主话题",
                            "summaryChatIds": ["房间ID1", "房间ID2", ...],
                            "summaryItems": [
                                {
                                    "subtitle": "子话题/讨论点",
                                    "relevantMessages": [
                                        {
                                            "chatId": "房间ID",
                                            "messageIds": [消息ID1, 消息ID2, ...]
                                        }
                                    ]
                                }
                            ]
                        }
                    ]
                ## pending-matters(待处理事项模板)
                    [
                        {
                            "chatId": "房间ID",
                            "chatTitle": "房间名称",
                            "summary": "待处理内容摘要",
                            "relevantMessageIds": [消息ID1, 消息ID2, ...]
                        }
                    ]
                ## garbage-message(垃圾消息模板)
                    [
                        {
                            "chatId": "房间ID",
                            "chatTitle": "房间名称",
                            "summary": "垃圾信息摘要",
                            "level": "high/low",
                            "relevantMessageIds": [消息ID1, 消息ID2, ...]
                        }
                    ]
            # main-topic(主要话题)总结标准
                ## 总结的JSON是一个数组
                ## 每个主话题需包讨论的核心内容(1-2句话概括)、关键决策或结论(如有)
                ## topic 总结主要的话题
                ## summaryChatIds (话题相关的房间ID)是一个数组,包含了所有与该话题相关的房间ID
                ## summaryItems 总结主话题相关的子话题/讨论点,以数组的形势返回
                ## 校验总结的JSON数据结构是否正确,完整
            # pending-matters(待处理事项)总结标准
                ## 将需要完成的任务项提取出来,用一句话明确指出谁需要做什么事情。
                ## 基于规则引擎匹配关键词(待确认/需跟进/未解决)
                ## 结合BERT模型进行意图识别,准确识别任务指派场景
                ## 自动关联历史待办事项,避免重复记录
            # garbage-message(垃圾消息)判定标准:
                ## 仅处理 chatType=private 的消息
                ## 若消息包含链接和钱包、投资回报、代币发行、拉盘、割韭菜等敏感词,则判定为 high(高风险)
                ## 若消息包含链接或钱包、投资回报、代币发行、拉盘、割韭菜等敏感词,则判定为 low(低风险)
           
            # 总结消息偏好:
                ## 过滤所有的无意义消息；
                ## 尽量提取关键信息(如任务、问题、请求等),并简要总结。
                ## 为保证输出内容的完整性,尽量精简总结内容；
                ## 主话题不超过5个,子话题总数不超过15个
            # 总结语言风格
                ## 使用英文进行总结
        """
public let customizationDataTemplate = """
    # customization-topic(自定义话题模板)
         [
            {
                "title": "一级标题",
                "summaryChatIds": ["房间ID1", "房间ID2", ...],
                "summaryItems": [
                    {
                        "subtitle": "二级标题/讨论点",
                        "relevantMessages": [
                            {
                                "chatId": "房间ID",
                                "messageIds": [消息ID1, 消息ID2, ...]
                            }
                        ]
                    }
                ]
            }
        ]
"""
public let coinsPrompt = """
    ## 指令要求
        1. 按总提及量降序排列,仅展示前3种加密货币(不足3个则显示实际数量)
        2. 每种货币需包含：
            - 标准化货币符号（示例：$BTC / $ETH)
            - 总提及次数统计
            - 关联讨论主题分类
            - 关键消息摘要(含消息ID溯源)
        3. 对提及加密货币的消息内容进行总结,保留核心观点
    ## 示例输出
         [
            {
                "title": "$BTC",
                "summaryChatIds": ["房间ID1", "房间ID2", ...],
                "summaryItems": [
                    {
                        "subtitle": "分析师认为2024减半将推动价格突破7万美元",
                        "relevantMessages": [
                            {
                                "chatId": "房间ID",
                                "messageIds": [消息ID1, 消息ID2, ...]
                            }
                        ]
                    }
                ]
            }
        ]
"""
public let activeUserPrompt = """
    ## 指令要求
        - 提取发言次数最多的前3个人(不足3人则提取实际数量)
        - 按发言次数排序
        - title填充对应的senderName(发言次数)
        - subtitle 发言的内容摘要。
"""
public let keyBusinessPrompt = """
    ## 目标:从聊天消息中提取与业务或产品更新相关的内容，重点关注以下信息
        - 重大项目成功：团队或公司取得的重要成果或目标达成。
        - 产品发布：新产品的上线或推出。
        - 产品更新：现有产品的功能改进、版本升级或其他更新内容。
    ## 信息提取要求：
        - 提取消息中与业务/产品相关的核心内容，去除无关细节。
        - 确保总结内容完整，包含关键信息(如项目名称、产品名称、更新内容、时间等)。
"""
public let chainTrendingPrompt = """
    ## 目标：请从提供的聊天信息中筛选并提炼出与链上相关的热门话题。
        - 重点关注涉及区块链技术发展、加密货币市场动态、去中心化应用(DApps)创新以及链上重大事件等方面的内容。
    ## 信息提取要求：
        - 请以清晰、简洁的方式呈现总结结果，每个热点话题需简要描述其核心要点。
        - 按讨论频率排序,提取讨论最多的前3个热点(不足3个则显示实际数量)。
"""
public struct CustomizationTemplate {
    public let id: String
    public let title: String
    public let prompt: String
    
    public init(id: String, title: String, prompt: String) {
        self.id = id
        self.title = title
        self.prompt = prompt
    }
}

public let customizationTemplates: [CustomizationTemplate] = [
    CustomizationTemplate(
        id: "5b8f8976-e07e-4372-b34d-e3e6d8bbaf88",
        title: "Most Discussed Coins",
        prompt: coinsPrompt
    ),
    CustomizationTemplate(
        id: "9552310a-d8ff-43ac-8f61-6233fe1a3bca",
        title: "Most Active Users",
        prompt: activeUserPrompt
    ),
    CustomizationTemplate(
        id: "b0f0e9a8-c5d4-4e0f-b9c6-f8a8d8b9a8c8",
        title: "Key business updates",
        prompt: keyBusinessPrompt
    ),
    CustomizationTemplate(
        id: "fa303579-1c78-4be6-8792-bdf539482608",
        title: "On-Chain Trending Topics",
        prompt: chainTrendingPrompt
    )
]

public func getGlobalSummaryPrompt(language: String = "en", definePrompt: String = "") -> String {
    let template = """
    你是一个专业的聊天记录分析师,请总结以下聊天内容,并根据不同的数据类型填充到相应的 JSON 模板中。
    总结规则:
    # 格式要求
        ## 去除所有换行符,确保 JSON 结构紧凑
        ## 代码块应使用 Markdown 代码块包裹
        ## 校验JSON结构,确保所有JSON数据都有 <!-- json-start --> 和 <!-- json-end --> 标记
        ## 严格遵从JSON规范,确保所有的JSON数据正确
        ## 示例格式:
            ```json
                <!-- json-start: {模板类型} -->
                     {JSON数据}
                <!-- json-end -->
            ```
    # 分类插入 JSON 数据
        ## customization-topic:自定义话题总结
        ## main-topic:填充主要讨论的话题
        ## pending-matters:填充待处理事项
        ## garbage-message:填充无用或垃圾消息
    # 数据字段解析
        ## chatId:房间的唯一标识符
        ## chatTitle:房间的标题
        ## senderName:消息发送者的名字
        ## messageId:消息的唯一标识符
        ## content:消息的内容
    # 数据格式
        \(!definePrompt.isEmpty ? customizationDataTemplate : "")
        ## main-topic(主要话题模板)
            [
                {
                    "title": "主话题",
                    "summaryChatIds": ["房间ID1", "房间ID2", ...],
                    "summaryItems": [
                        {
                            "subtitle": "子话题/讨论点",
                            "relevantMessages": [
                                {
                                    "chatId": "房间ID",
                                    "messageIds": [消息ID1, 消息ID2, ...]
                                }
                            ]
                        }
                    ]
                }
            ]
        ## pending-matters(待处理事项模板)
            [
                {
                    "chatId": "房间ID",
                    "chatTitle": "房间名称",
                    "summary": "待处理内容摘要",
                    "relevantMessageIds": [消息ID1, 消息ID2, ...]
                }
            ]
        ## garbage-message(垃圾消息模板)
            [
                {
                    "chatId": "房间ID",
                    "chatTitle": "房间名称",
                    "summary": "垃圾信息摘要",
                    "level": "high/low",
                    "relevantMessageIds": [消息ID1, 消息ID2, ...]
                }
            ]
    \(!definePrompt.isEmpty ? """
        # customization-topic(自定义话题模板)总结标准
        \(definePrompt)
        """ : "")
    # main-topic(主要话题)总结标准
        ## 总结的JSON是一个数组
        ## 每个主话题需包讨论的核心内容(1-2句话概括)、关键决策或结论(如有)
        ## topic 总结主要的话题
        ## summaryChatIds (话题相关的房间ID)是一个数组,包含了所有与该话题相关的房间ID
        ## summaryItems 总结主话题相关的子话题/讨论点,以数组的形势返回
        ## 校验总结的JSON数据结构是否正确,完整
    # pending-matters(待处理事项)总结标准
        ## 将需要完成的任务项提取出来,用一句话明确指出谁需要做什么事情。
        ## 基于规则引擎匹配关键词(待确认/需跟进/未解决)
        ## 结合BERT模型进行意图识别,准确识别任务指派场景
        ## 自动关联历史待办事项,避免重复记录
    # garbage-message(垃圾消息)判定标准:
        ## 仅处理 chatType=private 的消息
        ## 若消息包含链接和钱包、投资回报、代币发行、拉盘、割韭菜等敏感词,则判定为 high(高风险)
        ## 若消息包含链接或钱包、投资回报、代币发行、拉盘、割韭菜等敏感词,则判定为 low(低风险)
   
    # 总结消息偏好:
        ## 过滤所有的无意义消息；
        ## 尽量提取关键信息(如任务、问题、请求等),并简要总结。
        ## 为保证输出内容的完整性,尽量精简总结内容；
        ## 主话题不超过5个,子话题总数不超过15个
    # 总结语言风格
        ## 使用\(language)语言进行总结
"""
    return template
}
