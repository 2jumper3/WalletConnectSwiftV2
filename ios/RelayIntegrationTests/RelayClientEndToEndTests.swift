import Foundation
import Combine
import XCTest
import WalletConnectUtils
import Starscream
@testable import WalletConnectRelay

private class RelayKeychainStorageMock: KeychainStorageProtocol {
    func add<T>(_ item: T, forKey key: String) throws where T : WalletConnectKMS.GenericPasswordConvertible {}
    func read<T>(key: String) throws -> T where T : WalletConnectKMS.GenericPasswordConvertible {
        return try T(rawRepresentation: Data())
    }
    func delete(key: String) throws {}
    func deleteAll() throws {}
}

class WebSocketFactoryMock: WebSocketFactory {
    private let webSocket: WebSocket
    
    init(webSocket: WebSocket) {
        self.webSocket = webSocket
    }
    
    func create(with url: URL) -> WebSocketConnecting {
        return webSocket
    }
}

final class RelayClientEndToEndTests: XCTestCase {

    private var publishers = Set<AnyCancellable>()

    func makeRelayClient() -> RelayClient {
        let clientIdStorage = ClientIdStorage(keychain: KeychainStorageMock())
        let socketAuthenticator = SocketAuthenticator(
            clientIdStorage: clientIdStorage,
            relayHost: InputConfig.relayHost
        )
        let urlFactory = RelayUrlFactory(
            relayHost: InputConfig.relayHost,
            projectId: InputConfig.projectId,
            socketAuthenticator: socketAuthenticator
        )
        let socket = WebSocket(url: urlFactory.create())
        let webSocketFactory = WebSocketFactoryMock(webSocket: socket)
        let logger = ConsoleLogger()
        let dispatcher = Dispatcher(
            socketFactory: webSocketFactory,
            relayUrlFactory: urlFactory,
            socketConnectionType: .manual,
            logger: logger
        )
        return RelayClient(dispatcher: dispatcher, logger: logger, keyValueStorage: RuntimeKeyValueStorage(), clientIdStorage: clientIdStorage)
    }

    func testSubscribe() {
        let relayClient = makeRelayClient()

        try! relayClient.connect()
        let subscribeExpectation = expectation(description: "subscribe call succeeds")
        subscribeExpectation.assertForOverFulfill = true
        relayClient.socketConnectionStatusPublisher.sink { status in
            if status == .connected {
                Task(priority: .high) {  try await relayClient.subscribe(topic: "ecb78f2df880c43d3418ddbf871092b847801932e21765b250cc50b9e96a9131") }
                subscribeExpectation.fulfill()
            }
        }.store(in: &publishers)

        wait(for: [subscribeExpectation], timeout: InputConfig.defaultTimeout)
    }

    func testEndToEndPayload() {
        let relayA = makeRelayClient()
        let relayB = makeRelayClient()

        try! relayA.connect()
        try! relayB.connect()

        let randomTopic = String.randomTopic()
        let payloadA = "A"
        let payloadB = "B"
        var subscriptionATopic: String!
        var subscriptionBTopic: String!
        var subscriptionAPayload: String!
        var subscriptionBPayload: String!

        let expectationA = expectation(description: "publish payloads send and receive successfuly")
        let expectationB = expectation(description: "publish payloads send and receive successfuly")

        expectationA.assertForOverFulfill = false
        expectationB.assertForOverFulfill = false

        relayA.messagePublisher.sink { topic, payload, _ in
            (subscriptionATopic, subscriptionAPayload) = (topic, payload)
            expectationA.fulfill()
        }.store(in: &publishers)

        relayB.messagePublisher.sink { topic, payload, _ in
            (subscriptionBTopic, subscriptionBPayload) = (topic, payload)
            expectationB.fulfill()
        }.store(in: &publishers)

        relayA.socketConnectionStatusPublisher.sink {  _ in
            Task(priority: .high) {
                try await relayA.publish(topic: randomTopic, payload: payloadA, tag: 0, prompt: false, ttl: 60)
                try await relayA.subscribe(topic: randomTopic)
            }
        }.store(in: &publishers)
        relayB.socketConnectionStatusPublisher.sink {  _ in
            Task(priority: .high) {
                try await relayB.publish(topic: randomTopic, payload: payloadB, tag: 0, prompt: false, ttl: 60)
                try await relayB.subscribe(topic: randomTopic)
            }
        }.store(in: &publishers)

        wait(for: [expectationA, expectationB], timeout: InputConfig.defaultTimeout)

        XCTAssertEqual(subscriptionATopic, randomTopic)
        XCTAssertEqual(subscriptionBTopic, randomTopic)

        XCTAssertEqual(subscriptionBPayload, payloadA)
        XCTAssertEqual(subscriptionAPayload, payloadB)
    }
}

extension String {
    static func randomTopic() -> String {
        "\(UUID().uuidString)\(UUID().uuidString)".replacingOccurrences(of: "-", with: "").lowercased()
    }
}
