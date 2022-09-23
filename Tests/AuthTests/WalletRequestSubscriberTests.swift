import Foundation
import XCTest
import JSONRPC
import WalletConnectUtils
import WalletConnectNetworking
@testable import Auth
@testable import WalletConnectKMS
@testable import TestingUtils

class WalletRequestSubscriberTests: XCTestCase {
    var networkingInteractor: NetworkingInteractorMock!
    var sut: WalletRequestSubscriber!
    var messageFormatter: SIWEMessageFormatterMock!
    let defaultTimeout: TimeInterval = 0.01

    override func setUp() {
        networkingInteractor = NetworkingInteractorMock()
        messageFormatter = SIWEMessageFormatterMock()

        let walletErrorResponder = WalletErrorResponder(networkingInteractor: networkingInteractor, logger: ConsoleLoggerMock(), kms: KeyManagementServiceMock(), rpcHistory: RPCHistory(keyValueStore: CodableStore(defaults: RuntimeKeyValueStorage(), identifier: "")))
        sut = WalletRequestSubscriber(networkingInteractor: networkingInteractor,
                                      logger: ConsoleLoggerMock(),
                                      kms: KeyManagementServiceMock(),
                                      messageFormatter: messageFormatter, address: "", walletErrorResponder: walletErrorResponder)
    }

    func testSubscribeRequest() {
        let expectedMessage = "Expected Message"
        let expectedRequestId: RPCID = RPCID(1234)
        let messageExpectation = expectation(description: "receives formatted message")
        messageFormatter.formattedMessage = expectedMessage
        var messageId: RPCID!
        var message: String!
        sut.onRequest = { request in
            messageId = request.id
            message = request.message
            messageExpectation.fulfill()
        }

        let request = RPCRequest(method: AuthProtocolMethod.authRequest.method, params: AuthRequestParams.stub(id: expectedRequestId), id: expectedRequestId.right!)
        networkingInteractor.requestPublisherSubject.send(("123", request))

        wait(for: [messageExpectation], timeout: defaultTimeout)
        XCTAssertEqual(message, expectedMessage)
        XCTAssertEqual(messageId, expectedRequestId)
    }
}
