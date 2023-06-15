import SwiftUI
import WalletConnectPairing

@available(iOS 14.0, *)
public struct ModalContainerView: View {
    
    @Environment(\.presentationMode) var presentationMode
    
    @State var showModal: Bool = false
    
    let projectId: String
    let metadata: AppMetadata
    
    public init(projectId: String, metadata: AppMetadata) {
        self.projectId = projectId
        self.metadata = metadata
    }
    
    public var body: some View {
        
        VStack(spacing: 0) {
            
            Color.thickOverlay
                .colorScheme(.light)
                .onTapGesture {
                    withAnimation {
                        showModal = false
                    }
                }
            
            if showModal {
                ModalSheet(
                    viewModel: .init(
                        isShown: $showModal,
                        projectId: projectId,
                        interactor: DefaultModalSheetInteractor(
                            projectId: projectId,
                            metadata: metadata
                        )
                    )
                )
                .environment(\.projectId, projectId)
                .transition(.move(edge: .bottom))
                .animation(.spring(), value: showModal)
            }
        }
        .edgesIgnoringSafeArea(.all)
        .onChangeBackported(of: showModal, perform: { newValue in
            if newValue == false {
                withAnimation {
                    dismiss()
                }
            }
        })
        .onAppear {
            withAnimation {
                showModal = true
            }
        }
    }
    
    private func dismiss() {
        // Small delay so the sliding transition can happen before cross disolve starts
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            presentationMode.wrappedValue.dismiss()
        }
    }
}
