import Foundation

public class AuthDecryptionService {
    enum Errors: Error {
        case couldNotInitialiseDefaults
    }
    private let serializer: Serializing
    private let pairingStorage: PairingStorage

    public init(groupIdentifier: String) throws {
        let keychainStorage = GroupKeychainStorage(serviceIdentifier: groupIdentifier)
        let kms = KeyManagementService(keychain: keychainStorage)
        self.serializer = Serializer(kms: kms, logger: ConsoleLogger(prefix: "🔐", loggingLevel: .off))
        guard let defaults = UserDefaults(suiteName: groupIdentifier) else {
            throw Errors.couldNotInitialiseDefaults
        }
        pairingStorage = PairingStorage(storage: SequenceStore<WCPairing>(store: .init(defaults: defaults, identifier: PairStorageIdentifiers.pairings.rawValue)))
    }

    public func decryptMessage(topic: String, ciphertext: String) throws -> RPCRequest {
        let (rpcRequest, _, _): (RPCRequest, String?, Data) = try serializer.deserialize(topic: topic, encodedEnvelope: ciphertext)
        setPairingMetadata(rpcRequest: rpcRequest, topic: topic)
        return rpcRequest
    }

    public func getMetadata(topic: String) -> AppMetadata? {
        pairingStorage.getPairing(forTopic: topic)?.peerMetadata
    }

    private func setPairingMetadata(rpcRequest: RPCRequest, topic: String) {
        guard var pairing = pairingStorage.getPairing(forTopic: topic),
              pairing.peerMetadata == nil,
              let peerMetadata = try? rpcRequest.params?.get(AuthRequestParams.self).requester.metadata
        else { return }

        pairing.updatePeerMetadata(peerMetadata)
        pairingStorage.setPairing(pairing)
    }
}
