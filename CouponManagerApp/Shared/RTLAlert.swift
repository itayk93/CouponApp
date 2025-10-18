//
//  RTLAlert.swift
//  CouponManagerApp
//
//  A lightweight custom alert presented as an overlay, with
//  right-to-left layout and trailing text alignment by default.
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

// UILabel wrapper שמכבד RTL
private struct RTLText: UIViewRepresentable {
    let text: String
    let font: UIFont
    let color: UIColor
    let isBold: Bool
    
    func makeUIView(context: Context) -> UILabel {
        let label = UILabel()
        label.numberOfLines = 0
        label.textAlignment = .right
        label.lineBreakMode = .byWordWrapping
        label.semanticContentAttribute = .forceRightToLeft
        return label
    }
    
    func updateUIView(_ uiView: UILabel, context: Context) {
        uiView.text = text
        uiView.font = isBold ? font.withWeight(.bold) : font
        uiView.textColor = color
        uiView.textAlignment = .right
        uiView.semanticContentAttribute = .forceRightToLeft
    }
}

// Extension לקבלת UIFont עם משקל
private extension UIFont {
    func withWeight(_ weight: UIFont.Weight) -> UIFont {
        let descriptor = fontDescriptor.addingAttributes([
            .traits: [UIFontDescriptor.TraitKey.weight: weight]
        ])
        return UIFont(descriptor: descriptor, size: pointSize)
    }
}

private struct RTLAlertModifier: ViewModifier {
    @Binding var isPresented: Bool
    let title: String
    let message: String?
    let buttons: [RTLAlertButton]
    
    func body(content: Content) -> some View {
        content
            .overlay(
                Group {
                    if isPresented {
                        ZStack {
                            // Dimmed background
                            Color.black.opacity(0.4)
                                .ignoresSafeArea()
                                .transition(.opacity)
                                .onTapGesture {
                                    // Prevent dismissal
                                }
                            
                            // Alert dialog ממורכז
                            alertBody
                                .transition(.scale.combined(with: .opacity))
                        }
                    }
                }
                .animation(.easeInOut(duration: 0.25), value: isPresented)
            )
    }
    
    @ViewBuilder
    private var alertBody: some View {
        VStack(alignment: .trailing, spacing: 11) {
            // Title
            RTLText(
                text: title,
                font: .systemFont(ofSize: 17, weight: .semibold),
                color: UIColor.label,
                isBold: true
            )
            .frame(maxWidth: .infinity, alignment: .trailing)
            
            // Message
            if let message = message, !message.isEmpty {
                RTLText(
                    text: message,
                    font: .systemFont(ofSize: 13),
                    color: UIColor.secondaryLabel,
                    isBold: false
                )
                .frame(maxWidth: .infinity, alignment: .trailing)
                .padding(.top, 1)
            }
            
            // Separator line
            Divider()
                .padding(.top, 8)
            
            // Buttons
            VStack(spacing: 0) {
                ForEach(Array(buttons.enumerated()), id: \.offset) { index, btn in
                    if index > 0 {
                        Divider()
                    }
                    
                    Button {
                        isPresented = false
                        btn.action?()
                    } label: {
                        Text(btn.title)
                            .font(.system(size: 17, weight: buttonWeight(for: btn.role)))
                            .foregroundColor(buttonColor(for: btn.role))
                            .frame(maxWidth: .infinity)
                            .frame(height: 44)
                    }
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 19)
        .padding(.bottom, 0)
        .frame(width: 270)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color(.secondarySystemBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.gray.opacity(0.3), lineWidth: 0.5)
        )
        .shadow(color: Color.black.opacity(0.3), radius: 24, x: 0, y: 12)
        .environment(\.layoutDirection, .rightToLeft)
    }
    
    private func buttonColor(for role: ButtonRole?) -> Color {
        switch role {
        case .destructive: return .red
        case .cancel: return Color.blue
        default: return Color.blue
        }
    }
    
    private func buttonWeight(for role: ButtonRole?) -> Font.Weight {
        switch role {
        case .cancel: return .semibold
        default: return .regular
        }
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
