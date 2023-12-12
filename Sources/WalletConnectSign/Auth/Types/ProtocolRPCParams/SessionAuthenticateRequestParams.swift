import Foundation

/// wc_sessionAuthenticate RPC method request param
struct SessionAuthenticateRequestParams: Codable, Equatable {
    let requester: Participant
    let caip222Request: Caip222Request
}
