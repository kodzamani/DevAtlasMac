import SwiftUI

// MARK: - Keyboard Shortcut Modifier

extension View {
    func keyboardShortcut(_ key: KeyEquivalent, modifiers: EventModifiers, action: @escaping () -> Void) -> some View {
        self.background(
            Button("") { action() }
                .keyboardShortcut(key, modifiers: modifiers)
                .frame(width: 0, height: 0)
                .opacity(0)
        )
    }
}
