import Foundation
import Combine

class AuthResponseSubscriber {
    private let networkingInteractor: NetworkInteracting
    private let logger: ConsoleLogging
    private let rpcHistory: RPCHistory
    private let signatureVerifier: MessageVerifier
    private let messageFormatter: SIWECacaoFormatting
    private let pairingRegisterer: PairingRegisterer
    private var publishers = [AnyCancellable]()
    private let sessionStore: WCSessionStorage
    private let kms: KeyManagementServiceProtocol

    var onResponse: ((_ id: RPCID, _ result: Result<Cacao, AuthError>) -> Void)?

    init(networkingInteractor: NetworkInteracting,
         logger: ConsoleLogging,
         rpcHistory: RPCHistory,
         signatureVerifier: MessageVerifier,
         pairingRegisterer: PairingRegisterer,
         kms: KeyManagementServiceProtocol,
         sessionStore: WCSessionStorage,
         messageFormatter: SIWECacaoFormatting) {
        self.networkingInteractor = networkingInteractor
        self.logger = logger
        self.rpcHistory = rpcHistory
        self.kms = kms
        self.sessionStore = sessionStore
        self.signatureVerifier = signatureVerifier
        self.messageFormatter = messageFormatter
        self.pairingRegisterer = pairingRegisterer
        subscribeForResponse()
    }

    private func subscribeForResponse() {
        networkingInteractor.responseErrorSubscription(on: SessionAuthenticatedProtocolMethod())
            .sink { [unowned self] (payload: ResponseSubscriptionErrorPayload<SessionAuthenticateRequestParams>) in
                guard let error = AuthError(code: payload.error.code) else { return }
                onResponse?(payload.id, .failure(error))
            }.store(in: &publishers)

        networkingInteractor.responseSubscription(on: SessionAuthenticatedProtocolMethod())
            .sink { [unowned self] (payload: ResponseSubscriptionPayload<SessionAuthenticateRequestParams, SessionAuthenticateResponseParams>)  in

                pairingRegisterer.activate(pairingTopic: payload.topic, peerMetadata: nil)

                networkingInteractor.unsubscribe(topic: payload.topic)

                let requestId = payload.id
                let cacaos = payload.response.caip222Response
                let requestPayload = payload.request

                Task {
                    do {
                        try await recoverAndVerifySignature(caip222Request: payload.request.caip222Request, cacaos: cacaos)
                    } catch {
                        onResponse?(requestId, .failure(error as! AuthError))
                        return
                    }
                    let pairingTopic = "" // TODO - get pairing topic somehow here
                    let session = try createSession(from: payload.response, selfParticipant: payload.request.requester, pairingTopic: pairingTopic)
                }

            }.store(in: &publishers)
    }

    private func recoverAndVerifySignature(caip222Request: Caip222Request, cacaos: [Cacao]) async throws {
        try await cacaos.asyncForEach { [unowned self] cacao in
            guard
                let account = try? DIDPKH(did: cacao.p.iss).account,
                let message = try? messageFormatter.formatMessage(from: cacao.p)
            else {
                throw AuthError.malformedResponseParams
            }

            guard
                let recovered = try? messageFormatter.formatMessage(
                    from: caip222Request.cacaoPayload(account: account)
                ), recovered == message
            else {
                throw AuthError.messageCompromised
            }

            do {
                try await signatureVerifier.verify(
                    signature: cacao.s,
                    message: message,
                    account: account
                )
            } catch {
                logger.error("Signature verification failed with: \(error.localizedDescription)")
                throw AuthError.signatureVerificationFailed
            }

        }
    }

    private func createSession(from response: SessionAuthenticateResponseParams, selfParticipant: Participant, pairingTopic: String) throws -> Session {

        let selfPublicKey = try AgreementPublicKey(hex: selfParticipant.publicKey)
        let agreementKeys = try kms.performKeyAgreement(selfPublicKey: selfPublicKey, peerPublicKey: response.responder.publicKey)

        let sessionTopic = agreementKeys.derivedTopic()
        try kms.setAgreementSecret(agreementKeys, topic: sessionTopic)

        let expiry = Date()
            .addingTimeInterval(TimeInterval(WCSession.defaultTimeToLive))
            .timeIntervalSince1970

        let relay = RelayProtocolOptions(protocol: "irn", data: nil)

        let sessionNamespaces = buildSessionNamespaces()
        let requiredNamespaces = buildRequiredNamespaces()

        let settleParams = SessionType.SettleParams(
            relay: relay,
            controller: selfParticipant,
            namespaces: sessionNamespaces,
            sessionProperties: nil,
            expiry: Int64(expiry)
        )

        let session = WCSession(
            topic: sessionTopic,
            pairingTopic: pairingTopic,
            timestamp: Date(),
            selfParticipant: selfParticipant,
            peerParticipant: response.responder,
            settleParams: settleParams,
            requiredNamespaces: requiredNamespaces,
            acknowledged: false
        )

        sessionStore.setSession(session)


        return session.publicRepresentation()
    }

    private func buildSessionNamespaces() -> [String: SessionNamespace] {
        return [:]
    }

    private func buildRequiredNamespaces() -> [String: ProposalNamespace] {
        return [:]
    }
}

extension Sequence {
    func asyncForEach(_ operation: @escaping (Element) async throws -> Void) async throws {
        try await withThrowingTaskGroup(of: Void.self) { group in
            for element in self {
                group.addTask {
                    try await operation(element)
                }
            }
            try await group.waitForAll()
        }
    }
}