//
//  RTLAlert.swift
//  CouponManagerApp
//
//  A native-looking RTL alert based on UIAlertController.
//  Presents the smallest, most natural iOS alert with RTL alignment.
//

import SwiftUI

struct RTLAlertButton {
    let title: String
    let role: ButtonRole?
    let action: (() -> Void)?
    
    init(_ title: String, role: ButtonRole? = nil, action: (() -> Void)? = nil) {
        self.title = title
        self.role = role
        self.action = action
    }
}

// UIKit presenter that shows UIAlertController when binding toggles true
private struct UIKitRTLAlertPresenter: UIViewControllerRepresentable {
    @Binding var isPresented: Bool
    let title: String
    let message: String?
    let buttons: [RTLAlertButton]

    func makeUIViewController(context: Context) -> UIViewController {
        let vc = UIViewController()
        vc.view.isHidden = true
        vc.view.backgroundColor = .clear
        return vc
    }

    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {
        guard isPresented else { return }
        guard uiViewController.presentedViewController == nil else { return }

        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.view.semanticContentAttribute = .forceRightToLeft

        for btn in buttons {
            let style: UIAlertAction.Style
            switch btn.role {
            case .destructive: style = .destructive
            case .cancel: style = .cancel
            default: style = .default
            }
            let action = UIAlertAction(title: btn.title, style: style) { _ in
                // Dismiss and fire callback
                self.isPresented = false
                btn.action?()
            }
            alert.addAction(action)
        }

        // Present on next runloop tick to avoid UIKit warnings
        DispatchQueue.main.async {
            uiViewController.present(alert, animated: true, completion: nil)
        }
    }
}

private struct RTLAlertModifier: ViewModifier {
    @Binding var isPresented: Bool
    let title: String
    let message: String?
    let buttons: [RTLAlertButton]
    
    func body(content: Content) -> some View {
        content.background(
            UIKitRTLAlertPresenter(isPresented: $isPresented,
                                   title: title,
                                   message: message,
                                   buttons: buttons)
        )
    }
}

extension View {
    func rtlAlert(_ title: String,
                  isPresented: Binding<Bool>,
                  message: String? = nil,
                  buttons: [RTLAlertButton]) -> some View {
        modifier(RTLAlertModifier(isPresented: isPresented,
                                  title: title,
                                  message: message,
                                  buttons: buttons))
    }
}
