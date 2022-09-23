import Foundation

enum StorageDomainIdentifiers: String {
    case jsonRpcHistory = "com.walletconnect.sdk.wc_jsonRpcHistoryRecord"
    case pairings = "com.walletconnect.sdk.pairingSequences"
    case sessions = "com.walletconnect.sdk.sessionSequences"
    case proposals = "com.walletconnect.sdk.sessionProposals"
    case sessionToPairingTopic = "com.walletconnect.sdk.sessionToPairingTopic"
}
