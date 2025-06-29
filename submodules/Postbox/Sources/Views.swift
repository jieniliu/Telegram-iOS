import Foundation

// Local definition to avoid circular dependency
public enum AgentChatViewKey: Hashable {
    case allChats
    case chatCount
    
    public func hash(into hasher: inout Hasher) {
        switch self {
        case .allChats:
            hasher.combine(0)
        case .chatCount:
            hasher.combine(1)
        }
    }
}

// Placeholder implementation to avoid circular dependency
final class MutableAgentChatView: MutablePostboxView {
    let viewKey: AgentChatViewKey
    
    init(postbox: PostboxImpl, viewKey: AgentChatViewKey) {
        self.viewKey = viewKey
    }
    
    func replay(postbox: PostboxImpl, transaction: PostboxTransaction) -> Bool {
        return false
    }
    
    func refreshDueToExternalTransaction(postbox: PostboxImpl) -> Bool {
        return false
    }
    
    func immutableView() -> PostboxView {
        return AgentChatViewPlaceholder(self)
    }
}

// Placeholder immutable view to avoid circular dependency
public final class AgentChatViewPlaceholder: PostboxView {
    public let viewKey: AgentChatViewKey
    public let chatData: [String] = [] // Placeholder data
    public let chatCount: Int = 0
    
    init(_ mutableView: MutableAgentChatView) {
        self.viewKey = mutableView.viewKey
    }
}

public enum PostboxViewKey: Hashable {
    public struct HistoryView: Equatable {
        public var peerId: PeerId
        public var threadId: Int64?
        public var clipHoles: Bool
        public var trackHoles: Bool
        public var orderStatistics: MessageHistoryViewOrderStatistics
        public var ignoreMessagesInTimestampRange: ClosedRange<Int32>?
        public var ignoreMessageIds: Set<MessageId>
        public var anchor: HistoryViewInputAnchor
        public var combinedReadStates: MessageHistoryViewReadState?
        public var transientReadStates: MessageHistoryViewReadState?
        public var tag: HistoryViewInputTag?
        public var appendMessagesFromTheSameGroup: Bool
        public var namespaces: MessageIdNamespaces
        public var count: Int
        
        public init(
            peerId: PeerId,
            threadId: Int64?,
            clipHoles: Bool,
            trackHoles: Bool,
            orderStatistics: MessageHistoryViewOrderStatistics = [],
            ignoreMessagesInTimestampRange: ClosedRange<Int32>? = nil,
            ignoreMessageIds: Set<MessageId> = Set(),
            anchor: HistoryViewInputAnchor,
            combinedReadStates: MessageHistoryViewReadState? = nil,
            transientReadStates: MessageHistoryViewReadState? = nil,
            tag: HistoryViewInputTag? = nil,
            appendMessagesFromTheSameGroup: Bool,
            namespaces: MessageIdNamespaces,
            count: Int
        ) {
            self.peerId = peerId
            self.threadId = threadId
            self.clipHoles = clipHoles
            self.trackHoles = trackHoles
            self.orderStatistics = orderStatistics
            self.ignoreMessagesInTimestampRange = ignoreMessagesInTimestampRange
            self.ignoreMessageIds = ignoreMessageIds
            self.anchor = anchor
            self.combinedReadStates = combinedReadStates
            self.transientReadStates = transientReadStates
            self.tag = tag
            self.appendMessagesFromTheSameGroup = appendMessagesFromTheSameGroup
            self.namespaces = namespaces
            self.count = count
        }
    }
    
    case itemCollectionInfos(namespaces: [ItemCollectionId.Namespace])
    case itemCollectionIds(namespaces: [ItemCollectionId.Namespace])
    case itemCollectionInfo(id: ItemCollectionId)
    case peerChatState(peerId: PeerId)
    case orderedItemList(id: Int32)
    case preferences(keys: Set<ValueBoxKey>)
    case preferencesPrefix(keyPrefix: ValueBoxKey)
    case globalMessageTags(globalTag: GlobalMessageTags, position: MessageIndex, count: Int, groupingPredicate: ((Message, Message) -> Bool)?)
    case peer(peerId: PeerId, components: PeerViewComponents)
    case pendingMessageActions(type: PendingMessageActionType)
    case invalidatedMessageHistoryTagSummaries(peerId: PeerId?, threadId: Int64?, tagMask: MessageTags, namespace: MessageId.Namespace)
    case pendingMessageActionsSummary(type: PendingMessageActionType, peerId: PeerId, namespace: MessageId.Namespace)
    case historyTagSummaryView(tag: MessageTags, peerId: PeerId, threadId: Int64?, namespace: MessageId.Namespace, customTag: MemoryBuffer?)
    case historyCustomTagSummariesView(peerId: PeerId, threadId: Int64?, namespace: MessageId.Namespace)
    case cachedPeerData(peerId: PeerId)
    case unreadCounts(items: [UnreadMessageCountsItem])
    case combinedReadState(peerId: PeerId, handleThreads: Bool)
    case peerNotificationSettings(peerIds: Set<PeerId>)
    case pendingPeerNotificationSettings
    case messageOfInterestHole(location: MessageOfInterestViewLocation, namespace: MessageId.Namespace, count: Int)
    case localMessageTag(LocalMessageTags)
    case messages(Set<MessageId>)
    case additionalChatListItems
    case cachedItem(ItemCacheEntryId)
    case peerPresences(peerIds: Set<PeerId>)
    case synchronizeGroupMessageStats
    case peerNotificationSettingsBehaviorTimestampView
    case peerChatInclusion(PeerId)
    case basicPeer(PeerId)
    case allChatListHoles(PeerGroupId)
    case historyTagInfo(peerId: PeerId, tag: MessageTags)
    case topChatMessage(peerIds: [PeerId])
    case contacts(accountPeerId: PeerId?, includePresences: Bool)
    case deletedMessages(peerId: PeerId)
    case notice(key: NoticeEntryKey)
    case messageGroup(id: MessageId)
    case isContact(id: PeerId)
    case chatListIndex(id: PeerId)
    case peerTimeoutAttributes
    case messageHistoryThreadIndex(id: PeerId, summaryComponents: ChatListEntrySummaryComponents)
    case messageHistoryThreadInfo(peerId: PeerId, threadId: Int64)
    case storySubscriptions(key: PostboxStorySubscriptionsKey)
    case storiesState(key: PostboxStoryStatesKey)
    case storyItems(peerId: PeerId)
    case storyExpirationTimeItems
    case peerStoryStats(peerIds: Set<PeerId>)
    case story(id: StoryId)
    case savedMessagesIndex(peerId: PeerId)
    case savedMessagesStats(peerId: PeerId)
    case chatInterfaceState(peerId: PeerId)
    case historyView(HistoryView)
    case agentChat(AgentChatViewKey)

    public func hash(into hasher: inout Hasher) {
        switch self {
        case .itemCollectionInfos:
            hasher.combine(0)
        case .itemCollectionIds:
            hasher.combine(1)
        case let .peerChatState(peerId):
            hasher.combine(peerId)
        case let .itemCollectionInfo(id):
            hasher.combine(id)
        case let .orderedItemList(id):
            hasher.combine(id)
        case .preferences:
            hasher.combine(3)
        case .preferencesPrefix:
            hasher.combine(21)
        case .globalMessageTags:
            hasher.combine(4)
        case let .peer(peerId, _):
            hasher.combine(peerId)
        case let .pendingMessageActions(type):
            hasher.combine(type)
        case let .invalidatedMessageHistoryTagSummaries(peerId, threadId, tagMask, namespace):
            hasher.combine(peerId)
            hasher.combine(threadId)
            hasher.combine(tagMask)
            hasher.combine(namespace)
        case let .pendingMessageActionsSummary(type, peerId, namespace):
            hasher.combine(type)
            hasher.combine(peerId)
            hasher.combine(namespace)
        case let .historyTagSummaryView(tag, peerId, threadId, namespace, customTag):
            hasher.combine(tag)
            hasher.combine(peerId)
            hasher.combine(threadId)
            hasher.combine(namespace)
            hasher.combine(customTag)
        case let .historyCustomTagSummariesView(peerId, threadId, namespace):
            hasher.combine(peerId)
            hasher.combine(threadId)
            hasher.combine(namespace)
        case let .cachedPeerData(peerId):
            hasher.combine(peerId)
        case .unreadCounts:
            hasher.combine(5)
        case .combinedReadState:
            hasher.combine(16)
        case .peerNotificationSettings:
            hasher.combine(6)
        case .pendingPeerNotificationSettings:
            hasher.combine(7)
        case let .messageOfInterestHole(location, namespace, count):
            hasher.combine(8)
            hasher.combine(location)
            hasher.combine(namespace)
            hasher.combine(count)
        case let .localMessageTag(tag):
            hasher.combine(tag)
        case .messages:
            hasher.combine(10)
        case .additionalChatListItems:
            hasher.combine(11)
        case let .cachedItem(id):
            hasher.combine(id)
        case .peerPresences:
            hasher.combine(13)
        case .synchronizeGroupMessageStats:
            hasher.combine(14)
        case .peerNotificationSettingsBehaviorTimestampView:
            hasher.combine(15)
        case let .peerChatInclusion(peerId):
            hasher.combine(peerId)
        case let .basicPeer(peerId):
            hasher.combine(peerId)
        case let .allChatListHoles(groupId):
            hasher.combine(groupId)
        case let .historyTagInfo(peerId, tag):
            hasher.combine(peerId)
            hasher.combine(tag)
        case let .topChatMessage(peerIds):
            hasher.combine(peerIds)
        case .contacts:
            hasher.combine(16)
        case let .deletedMessages(peerId):
            hasher.combine(peerId)
        case let .notice(key):
            hasher.combine(key)
        case let .messageGroup(id):
            hasher.combine(id)
        case let .isContact(id):
            hasher.combine(id)
        case let .chatListIndex(id):
            hasher.combine(id)
        case .peerTimeoutAttributes:
            hasher.combine(17)
        case let .messageHistoryThreadIndex(id, _):
            hasher.combine(id)
        case let .messageHistoryThreadInfo(peerId, threadId):
            hasher.combine(peerId)
            hasher.combine(threadId)
        case let .storySubscriptions(key):
            hasher.combine(18)
            hasher.combine(key)
        case let .storiesState(key):
            hasher.combine(key)
        case let .storyItems(peerId):
            hasher.combine(peerId)
        case .storyExpirationTimeItems:
            hasher.combine(19)
        case let .peerStoryStats(peerIds):
            hasher.combine(peerIds)
        case let .story(id):
            hasher.combine(id)
        case let .savedMessagesIndex(peerId):
            hasher.combine(peerId)
        case let .savedMessagesStats(peerId):
            hasher.combine(peerId)
        case let .chatInterfaceState(peerId):
            hasher.combine(peerId)
        case let .historyView(historyView):
            hasher.combine(20)
            hasher.combine(historyView.peerId)
            hasher.combine(historyView.threadId)
        case let .agentChat(key):
            hasher.combine(21)
            hasher.combine(key)
        }
    }
    
    public static func ==(lhs: PostboxViewKey, rhs: PostboxViewKey) -> Bool {
        switch lhs {
        case let .itemCollectionInfos(lhsNamespaces):
            if case let .itemCollectionInfos(rhsNamespaces) = rhs, lhsNamespaces == rhsNamespaces {
                return true
            } else {
                return false
            }
        case let .itemCollectionIds(lhsNamespaces):
            if case let .itemCollectionIds(rhsNamespaces) = rhs, lhsNamespaces == rhsNamespaces {
                return true
            } else {
                return false
            }
        case let .itemCollectionInfo(id):
            if case .itemCollectionInfo(id) = rhs {
                return true
            } else {
                return false
            }
        case let .peerChatState(peerId):
            if case .peerChatState(peerId) = rhs {
                return true
            } else {
                return false
            }
        case let .orderedItemList(id):
            if case .orderedItemList(id) = rhs {
                return true
            } else {
                return false
            }
        case let .preferences(lhsKeys):
            if case let .preferences(rhsKeys) = rhs, lhsKeys == rhsKeys {
                return true
            } else {
                return false
            }
        case let .preferencesPrefix(lhsKeyPrefix):
            if case let .preferencesPrefix(rhsKeyPrefix) = rhs, lhsKeyPrefix == rhsKeyPrefix {
                return true
            } else {
                return false
            }
        case let .globalMessageTags(globalTag, position, count, _):
            if case .globalMessageTags(globalTag, position, count, _) = rhs {
                return true
            } else {
                return false
            }
        case let .peer(peerId, components):
            if case .peer(peerId, components) = rhs {
                return true
            } else {
                return false
            }
        case let .pendingMessageActions(type):
            if case .pendingMessageActions(type) = rhs {
                return true
            } else {
                return false
            }
        case let .invalidatedMessageHistoryTagSummaries(peerId, threadId, tagMask, namespace):
            if case .invalidatedMessageHistoryTagSummaries(peerId, threadId, tagMask, namespace) = rhs {
                return true
            } else {
                return false
            }
        case let .pendingMessageActionsSummary(type, peerId, namespace):
            if case .pendingMessageActionsSummary(type, peerId, namespace) = rhs {
                return true
            } else {
                return false
            }
        case let .historyTagSummaryView(tag, peerId, threadId, namespace, customTag):
            if case .historyTagSummaryView(tag, peerId, threadId, namespace, customTag) = rhs {
                return true
            } else {
                return false
            }
        case let .historyCustomTagSummariesView(peerId, threadId, namespace):
            if case .historyCustomTagSummariesView(peerId, threadId, namespace) = rhs {
                return true
            } else {
                return false
            }
        case let .cachedPeerData(peerId):
            if case .cachedPeerData(peerId) = rhs {
                return true
            } else {
                return false
            }
        case let .unreadCounts(lhsItems):
            if case let .unreadCounts(rhsItems) = rhs, lhsItems == rhsItems {
                return true
            } else {
                return false
            }
        case let .combinedReadState(peerId, handleThreads):
            if case .combinedReadState(peerId, handleThreads) = rhs {
                return true
            } else {
                return false
            }
        case let .peerNotificationSettings(peerIds):
            if case .peerNotificationSettings(peerIds) = rhs {
                return true
            } else {
                return false
            }
        case .pendingPeerNotificationSettings:
            if case .pendingPeerNotificationSettings = rhs {
                return true
            } else {
                return false
            }
        case let .messageOfInterestHole(peerId, namespace, count):
            if case .messageOfInterestHole(peerId, namespace, count) = rhs {
                return true
            } else {
                return false
            }
        case let .localMessageTag(tag):
            if case .localMessageTag(tag) = rhs {
                return true
            } else {
                return false
            }
        case let .messages(ids):
            if case .messages(ids) = rhs {
                return true
            } else {
                return false
            }
        case .additionalChatListItems:
            if case .additionalChatListItems = rhs {
                return true
            } else {
                return false
            }
        case let .cachedItem(id):
            if case .cachedItem(id) = rhs {
                return true
            } else {
                return false
            }
        case let .peerPresences(ids):
            if case .peerPresences(ids) = rhs {
                return true
            } else {
                return false
            }
        case .synchronizeGroupMessageStats:
            if case .synchronizeGroupMessageStats = rhs {
                return true
            } else {
                return false
            }
        case .peerNotificationSettingsBehaviorTimestampView:
            if case .peerNotificationSettingsBehaviorTimestampView = rhs {
                return true
            } else {
                return false
            }
        case let .peerChatInclusion(id):
            if case .peerChatInclusion(id) = rhs {
                return true
            } else {
                return false
            }
        case let .basicPeer(id):
            if case .basicPeer(id) = rhs {
                return true
            } else {
                return false
            }
        case let .allChatListHoles(groupId):
            if case .allChatListHoles(groupId) = rhs {
                return true
            } else {
                return false
            }
        case let .historyTagInfo(peerId, tag):
            if case .historyTagInfo(peerId, tag) = rhs {
                return true
            } else {
                return false
            }
        case let .topChatMessage(peerIds):
            if case .topChatMessage(peerIds) = rhs {
                return true
            } else {
                return false
            }
        case let .contacts(accountPeerId, includePresences):
            if case .contacts(accountPeerId, includePresences) = rhs {
                return true
            } else {
                return false
            }
        case let .deletedMessages(peerId):
            if case .deletedMessages(peerId) = rhs {
                return true
            } else {
                return false
            }
        case let .notice(key):
            if case .notice(key) = rhs {
                return true
            } else {
                return false
            }
        case let .messageGroup(id):
            if case .messageGroup(id) = rhs {
                return true
            } else {
                return false
            }
        case let .isContact(id):
            if case .isContact(id) = rhs {
                return true
            } else {
                return false
            }
        case let .chatListIndex(id):
            if case .chatListIndex(id) = rhs {
                return true
            } else {
                return false
            }
        case .peerTimeoutAttributes:
            if case .peerTimeoutAttributes = rhs {
                return true
            } else {
                return false
            }
        case let .messageHistoryThreadIndex(id, summaryComponents):
            if case .messageHistoryThreadIndex(id, summaryComponents) = rhs {
                return true
            } else {
                return false
            }
        case let .messageHistoryThreadInfo(peerId, threadId):
            if case .messageHistoryThreadInfo(peerId, threadId) = rhs {
                return true
            } else {
                return false
            }
        case let .storySubscriptions(key):
            if case .storySubscriptions(key) = rhs {
                return true
            } else {
                return false
            }
        case let .storiesState(key):
            if case .storiesState(key) = rhs {
                return true
            } else {
                return false
            }
        case let .storyItems(peerId):
            if case .storyItems(peerId) = rhs {
                return true
            } else {
                return false
            }
        case .storyExpirationTimeItems:
            if case .storyExpirationTimeItems = rhs {
                return true
            } else {
                return false
            }
        case let .peerStoryStats(peerIds):
            if case .peerStoryStats(peerIds) = rhs {
                return true
            } else {
                return false
            }
        case let .story(id):
            if case .story(id) = rhs {
                return true
            } else {
                return false
            }
        case let .savedMessagesIndex(peerId):
            if case .savedMessagesIndex(peerId) = rhs {
                return true
            } else {
                return false
            }
        case let .savedMessagesStats(peerId):
            if case .savedMessagesStats(peerId) = rhs {
                return true
            } else {
                return false
            }
        case let .chatInterfaceState(peerId):
            if case .chatInterfaceState(peerId) = rhs {
                return true
            } else {
                return false
            }
        case let .historyView(historyView):
            if case .historyView(historyView) = rhs {
                return true
            } else {
                return false
            }
        case let .agentChat(key):
            if case .agentChat(key) = rhs {
                return true
            } else {
                return false
            }
        }
    }
}

func postboxViewForKey(postbox: PostboxImpl, key: PostboxViewKey) -> MutablePostboxView {
    switch key {
    case let .itemCollectionInfos(namespaces):
        return MutableItemCollectionInfosView(postbox: postbox, namespaces: namespaces)
    case let .itemCollectionIds(namespaces):
        return MutableItemCollectionIdsView(postbox: postbox, namespaces: namespaces)
    case let .itemCollectionInfo(id):
        return MutableItemCollectionInfoView(postbox: postbox, id: id)
    case let .peerChatState(peerId):
        return MutablePeerChatStateView(postbox: postbox, peerId: peerId)
    case let .orderedItemList(id):
        return MutableOrderedItemListView(postbox: postbox, collectionId: id)
    case let .preferences(keys):
        return MutablePreferencesView(postbox: postbox, keys: keys)
    case let .preferencesPrefix(keyPrefix):
        return MutablePreferencesPrefixView(postbox: postbox, keyPrefix: keyPrefix)
    case let .globalMessageTags(globalTag, position, count, groupingPredicate):
        return MutableGlobalMessageTagsView(postbox: postbox, globalTag: globalTag, position: position, count: count, groupingPredicate: groupingPredicate)
    case let .peer(peerId, components):
        return MutablePeerView(postbox: postbox, peerId: peerId, components: components)
    case let .pendingMessageActions(type):
        return MutablePendingMessageActionsView(postbox: postbox, type: type)
    case let .invalidatedMessageHistoryTagSummaries(peerId, threadId, tagMask, namespace):
        return MutableInvalidatedMessageHistoryTagSummariesView(postbox: postbox, peerId: peerId, threadId: threadId, tagMask: tagMask, namespace: namespace)
    case let .pendingMessageActionsSummary(type, peerId, namespace):
        return MutablePendingMessageActionsSummaryView(postbox: postbox, type: type, peerId: peerId, namespace: namespace)
    case let .historyTagSummaryView(tag, peerId, threadId, namespace, customTag):
        return MutableMessageHistoryTagSummaryView(postbox: postbox, tag: tag, peerId: peerId, threadId: threadId, namespace: namespace, customTag: customTag)
    case let .historyCustomTagSummariesView(peerId, threadId, namespace):
        return MutableMessageHistoryCustomTagSummariesView(postbox: postbox, peerId: peerId, threadId: threadId, namespace: namespace)
    case let .cachedPeerData(peerId):
        return MutableCachedPeerDataView(postbox: postbox, peerId: peerId)
    case let .unreadCounts(items):
        return MutableUnreadMessageCountsView(postbox: postbox, items: items)
    case let .combinedReadState(peerId, handleThreads):
        return MutableCombinedReadStateView(postbox: postbox, peerId: peerId, handleThreads: handleThreads)
    case let .peerNotificationSettings(peerIds):
        return MutablePeerNotificationSettingsView(postbox: postbox, peerIds: peerIds)
    case .pendingPeerNotificationSettings:
        return MutablePendingPeerNotificationSettingsView(postbox: postbox)
    case let .messageOfInterestHole(location, namespace, count):
        return MutableMessageOfInterestHolesView(postbox: postbox, location: location, namespace: namespace, count: count)
    case let .localMessageTag(tag):
        return MutableLocalMessageTagsView(postbox: postbox, tag: tag)
    case let .messages(ids):
        return MutableMessagesView(postbox: postbox, ids: ids)
    case .additionalChatListItems:
        return MutableAdditionalChatListItemsView(postbox: postbox)
    case let .cachedItem(id):
        return MutableCachedItemView(postbox: postbox, id: id)
    case let .peerPresences(ids):
        return MutablePeerPresencesView(postbox: postbox, ids: ids)
    case .synchronizeGroupMessageStats:
        return MutableSynchronizeGroupMessageStatsView(postbox: postbox)
    case .peerNotificationSettingsBehaviorTimestampView:
        return MutablePeerNotificationSettingsBehaviorTimestampView(postbox: postbox)
    case let .peerChatInclusion(peerId):
        return MutablePeerChatInclusionView(postbox: postbox, peerId: peerId)
    case let .basicPeer(peerId):
        return MutableBasicPeerView(postbox: postbox, peerId: peerId)
    case let .allChatListHoles(groupId):
        return MutableAllChatListHolesView(postbox: postbox, groupId: groupId)
    case let .historyTagInfo(peerId, tag):
        return MutableHistoryTagInfoView(postbox: postbox, peerId: peerId, tag: tag)
    case let .topChatMessage(peerIds):
        return MutableTopChatMessageView(postbox: postbox, peerIds: Set(peerIds))
    case let .contacts(accountPeerId, includePresences):
        return MutableContactPeersView(postbox: postbox, accountPeerId: accountPeerId, includePresences: includePresences)
    case let .deletedMessages(peerId):
        return MutableDeletedMessagesView(peerId: peerId)
    case let .notice(key):
        return MutableLocalNoticeEntryView(postbox: postbox, key: key)
    case let .messageGroup(id):
        return MutableMessageGroupView(postbox: postbox, id: id)
    case let .isContact(id):
        return MutableIsContactView(postbox: postbox, id: id)
    case let .chatListIndex(id):
        return MutableChatListIndexView(postbox: postbox, id: id)
    case .peerTimeoutAttributes:
        return MutablePeerTimeoutAttributesView(postbox: postbox)
    case let .messageHistoryThreadIndex(id, summaryComponents):
        return MutableMessageHistoryThreadIndexView(postbox: postbox, peerId: id, summaryComponents: summaryComponents)
    case let .messageHistoryThreadInfo(peerId, threadId):
        return MutableMessageHistoryThreadInfoView(postbox: postbox, peerId: peerId, threadId: threadId)
    case let .storySubscriptions(key):
        return MutableStorySubscriptionsView(postbox: postbox, key: key)
    case let .storiesState(key):
        return MutableStoryStatesView(postbox: postbox, key: key)
    case let .storyItems(peerId):
        return MutableStoryItemsView(postbox: postbox, peerId: peerId)
    case .storyExpirationTimeItems:
        return MutableStoryExpirationTimeItemsView(postbox: postbox)
    case let .peerStoryStats(peerIds):
        return MutablePeerStoryStatsView(postbox: postbox, peerIds: peerIds)
    case let .story(id):
        return MutableStoryView(postbox: postbox, id: id)
    case let .savedMessagesIndex(peerId):
        return MutableMessageHistorySavedMessagesIndexView(postbox: postbox, peerId: peerId)
    case let .savedMessagesStats(peerId):
        return MutableMessageHistorySavedMessagesStatsView(postbox: postbox, peerId: peerId)
    case let .chatInterfaceState(peerId):
        return MutableChatInterfaceStateView(postbox: postbox, peerId: peerId)
    case let .historyView(historyView):
        return MutableMessageHistoryView(
            postbox: postbox,
            orderStatistics: historyView.orderStatistics,
            clipHoles: historyView.clipHoles,
            trackHoles: historyView.trackHoles,
            peerIds: .single(peerId: historyView.peerId, threadId: historyView.threadId),
            ignoreMessagesInTimestampRange: historyView.ignoreMessagesInTimestampRange,
            ignoreMessageIds: historyView.ignoreMessageIds,
            anchor: historyView.anchor,
            combinedReadStates: historyView.combinedReadStates,
            transientReadStates: historyView.transientReadStates,
            tag: historyView.tag,
            appendMessagesFromTheSameGroup: historyView.appendMessagesFromTheSameGroup,
            namespaces: historyView.namespaces,
            count: historyView.count,
            topTaggedMessages: [:],
            additionalDatas: []
        )
    case let .agentChat(key):
        return MutableAgentChatView(postbox: postbox, viewKey: key)
    }
}
