
import Foundation


public struct RelayClientFactory {

    public static func create(
        relayHost: String,
        projectId: String,
        socketFactory: WebSocketFactory,
        socketConnectionType: SocketConnectionType
    ) -> RelayClient {

        let keyValueStorage = UserDefaults.standard

        let keychainStorage = KeychainStorage(serviceIdentifier: "com.walletconnect.sdk")

        let logger = ConsoleLogger(loggingLevel: .debug)

        return RelayClientFactory.create(
            relayHost: relayHost,
            projectId: projectId,
            keyValueStorage: keyValueStorage,
            keychainStorage: keychainStorage,
            socketFactory: socketFactory,
            socketConnectionType: socketConnectionType,
            logger: logger
        )
    }


    public static func create(
        relayHost: String,
        projectId: String,
        keyValueStorage: KeyValueStorage,
        keychainStorage: KeychainStorageProtocol,
        socketFactory: WebSocketFactory,
        socketConnectionType: SocketConnectionType = .automatic,
        logger: ConsoleLogging
    ) -> RelayClient {

        let clientIdMigrationController = ClientIdMigrationController(serviceIdentifier: "com.walletconnect.sdk", keyValueStorage: keyValueStorage, logger: logger)

        let clientIdStorage = ClientIdStorage(keychain: keychainStorage, clientIdMigrationController: clientIdMigrationController)

        let socketAuthenticator = SocketAuthenticator(
            clientIdStorage: clientIdStorage,
            relayHost: relayHost
        )
        let relayUrlFactory = RelayUrlFactory(
            relayHost: relayHost,
            projectId: projectId,
            socketAuthenticator: socketAuthenticator
        )
        let dispatcher = Dispatcher(
            socketFactory: socketFactory,
            relayUrlFactory: relayUrlFactory,
            socketConnectionType: socketConnectionType,
            logger: logger
        )

        let rpcHistory = RPCHistoryFactory.createForRelay(keyValueStorage: keyValueStorage)

        return RelayClient(dispatcher: dispatcher, logger: logger, rpcHistory: rpcHistory, clientIdStorage: clientIdStorage)
    }
}
