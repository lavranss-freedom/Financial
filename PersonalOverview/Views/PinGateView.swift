import SwiftUI

struct PinGateView: View {
    @EnvironmentObject var store: AppDataStore
    @State private var pin = ""
    @State private var confirmPin = ""
    @State private var stage: Stage = .enter
    @State private var errorText: String?

    enum Stage {
        case setup
        case confirm
        case enter
    }

    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            Text("Personal Overview")
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundStyle(AppTheme.gold)
            Text(header)
                .font(.subheadline)
                .foregroundStyle(AppTheme.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            secureDots(for: displayPin)

            if let errorText {
                Text(errorText)
                    .font(.footnote)
                    .foregroundStyle(AppTheme.negative)
            }

            if stage == .setup && pin.count >= 4 {
                Button("Continue") { goConfirm() }
                    .font(.headline)
                    .foregroundStyle(AppTheme.navy)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 10)
                    .background(AppTheme.gold)
                    .clipShape(Capsule())
            }

            if stage == .confirm && confirmPin.count >= 4 && confirmPin.count == pin.count {
                Button("Save PIN") { tryFinishSetup() }
                    .font(.headline)
                    .foregroundStyle(AppTheme.navy)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 10)
                    .background(AppTheme.gold)
                    .clipShape(Capsule())
            }

            if stage == .enter && pin.count >= 4 {
                Button("Unlock") { tryUnlock() }
                    .font(.headline)
                    .foregroundStyle(AppTheme.navy)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 10)
                    .background(AppTheme.gold)
                    .clipShape(Capsule())
            }

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 3), spacing: 12) {
                ForEach(1...9, id: \.self) { n in
                    padButton("\(n)") { appendDigit("\(n)") }
                }
                Color.clear.frame(height: 56)
                padButton("0") { appendDigit("0") }
                padButton("⌫") { deleteDigit() }
            }
            .padding(.horizontal, 40)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AppTheme.navy.ignoresSafeArea())
        .onAppear {
            stage = store.needsPINSetup ? .setup : .enter
        }
    }

    private var header: String {
        switch stage {
        case .setup: return "Create a PIN (4–6 digits) to lock your book"
        case .confirm: return "Confirm your PIN"
        case .enter: return "Enter PIN to unlock"
        }
    }

    private var displayPin: String {
        stage == .confirm ? confirmPin : pin
    }

    private func secureDots(for value: String) -> some View {
        HStack(spacing: 12) {
            ForEach(0..<6, id: \.self) { i in
                Circle()
                    .fill(i < value.count ? AppTheme.gold : AppTheme.navyElevated)
                    .frame(width: 12, height: 12)
                    .overlay(Circle().stroke(AppTheme.border, lineWidth: 1))
            }
        }
    }

    private func padButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.title2.weight(.semibold))
                .foregroundStyle(AppTheme.textPrimary)
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(AppTheme.navyCard)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private func appendDigit(_ d: String) {
        errorText = nil
        switch stage {
        case .setup:
            guard pin.count < 6 else { return }
            pin += d
            if pin.count == 6 { goConfirm() }
        case .confirm:
            guard confirmPin.count < 6 else { return }
            confirmPin += d
            if confirmPin.count == pin.count { tryFinishSetup() }
        case .enter:
            guard pin.count < 6 else { return }
            pin += d
            if let stored = KeychainHelper.loadPIN(), pin.count == stored.count {
                tryUnlock()
            }
        }
    }

    private func deleteDigit() {
        errorText = nil
        switch stage {
        case .setup:
            if !pin.isEmpty { pin.removeLast() }
        case .confirm:
            if !confirmPin.isEmpty { confirmPin.removeLast() }
            else { stage = .setup; pin = ""; confirmPin = "" }
        case .enter:
            if !pin.isEmpty { pin.removeLast() }
        }
    }

    private func goConfirm() {
        stage = .confirm
        confirmPin = ""
    }

    private func tryFinishSetup() {
        guard confirmPin == pin else {
            errorText = "PINs do not match"
            confirmPin = ""
            return
        }
        if store.setupPIN(pin) {
            pin = ""
            confirmPin = ""
        } else {
            errorText = "Could not save PIN"
        }
    }

    private func tryUnlock() {
        if store.unlock(with: pin) {
            pin = ""
        } else {
            errorText = "Wrong PIN"
            pin = ""
        }
    }
}
