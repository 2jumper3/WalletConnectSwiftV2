import SwiftUI
import WalletConnectNetworking
import WalletConnectPairing

@available(iOS 14.0, *)
public class Web3ModalSheetController: UIHostingController<AnyView> {
    
    @MainActor dynamic required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    public init(projectId: String, metadata: AppMetadata) {
        let view = AnyView(
            ModalContainerView(projectId: projectId, metadata: metadata)
        )
        
        super.init(rootView: view)
        self.modalTransitionStyle = .crossDissolve
        self.modalPresentationStyle = .overFullScreen
    }
    
    override public func viewDidLoad() {
        super.viewDidLoad()
        self.view.backgroundColor = .clear
    }
}
