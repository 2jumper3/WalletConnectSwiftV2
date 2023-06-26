import Foundation
import Combine

class PushMessageSubscriber {
    private let networkingInteractor: NetworkInteracting
    private let pushMessagesDatabase: PushMessagesDatabase
    private let logger: ConsoleLogging
    private var publishers = [AnyCancellable]()
    private let pushMessagePublisherSubject = PassthroughSubject<PushMessageRecord, Never>()

    public var pushMessagePublisher: AnyPublisher<PushMessageRecord, Never> {
        pushMessagePublisherSubject.eraseToAnyPublisher()
    }

    init(networkingInteractor: NetworkInteracting,
         pushMessagesDatabase: PushMessagesDatabase,
         logger: ConsoleLogging) {
        self.networkingInteractor = networkingInteractor
        self.pushMessagesDatabase = pushMessagesDatabase
        self.logger = logger
        subscribeForPushMessages()
    }

    private func subscribeForPushMessages() {
        let protocolMethod = PushMessageProtocolMethod()
        networkingInteractor.requestSubscription(on: protocolMethod)
            .sink { [unowned self] (payload: RequestSubscriptionPayload<PushMessage>) in
                logger.debug("Received Push Message")

                let record = PushMessageRecord(id: payload.id.string, topic: payload.topic, message: payload.request, publishedAt: payload.publishedAt)
                pushMessagesDatabase.setPushMessageRecord(record)
                pushMessagePublisherSubject.send(record)

            }.store(in: &publishers)

    }
}
