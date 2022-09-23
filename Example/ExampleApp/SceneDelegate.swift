import UIKit
import WalletConnectSign
import WalletConnectRelay
import Starscream

extension WebSocket: WebSocketConnecting { }

struct SocketFactory: WebSocketFactory {
    func create(with url: URL) -> WebSocketConnecting {
        return WebSocket(url: url)
    }
}

class SceneDelegate: UIResponder, UIWindowSceneDelegate {

    var window: UIWindow?

    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {

        let metadata = AppMetadata(
            name: "Example Wallet",
            description: "wallet description",
            url: "example.wallet",
            icons: ["https://avatars.githubusercontent.com/u/37784886"])

        Relay.configure(projectId: "3ca2919724fbfa5456a25194e369a8b4", socketFactory: SocketFactory())
        Sign.configure(metadata: metadata)
#if DEBUG
        if CommandLine.arguments.contains("-cleanInstall") {
            try? Sign.instance.cleanup()
        }
#endif

        guard let windowScene = (scene as? UIWindowScene) else { return }
        window = UIWindow(windowScene: windowScene)
        window?.rootViewController = UITabBarController.createExampleApp()
        window?.makeKeyAndVisible()
    }

    func scene(_ scene: UIScene, continue userActivity: NSUserActivity) {
        guard userActivity.activityType == NSUserActivityTypeBrowsingWeb,
              let incomingURL = userActivity.webpageURL else {
                  return
              }
        let wcUri = incomingURL.absoluteString.deletingPrefix("https://walletconnect.com/wc?uri=")
        let vc = ((window!.rootViewController as! UINavigationController).viewControllers[0] as! WalletViewController)
        Task(priority: .high) {try? await Sign.instance.pair(uri: WalletConnectURI(string: wcUri)!)}
        vc.onClientConnected = {
            Task(priority: .high) {
                do {
                    try await Sign.instance.pair(uri: WalletConnectURI(string: wcUri)!)
                } catch {
                    print(error)
                }
            }
        }
    }
}

extension UITabBarController {

    static func createExampleApp() -> UINavigationController {
        let responderController = UINavigationController(rootViewController: WalletViewController())
        return responderController
    }
}

extension String {
    func deletingPrefix(_ prefix: String) -> String {
        guard self.hasPrefix(prefix) else { return self }
        return String(self.dropFirst(prefix.count))
    }
}
