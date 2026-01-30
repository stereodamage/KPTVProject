//
//  FocusBridge.swift
//  KinoPubTV
//
//  Created by Stereo on 2024-01-30.
//

import SwiftUI

struct FocusBridge: View {
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Color.white.opacity(0.001) // Nearly transparent but visible to Focus Engine
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onFocusChange { isFocused in
            if isFocused {
                action()
            }
        }
    }
}

extension View {
    func onFocusChange(perform action: @escaping (Bool) -> Void) -> some View {
        self.modifier(FocusChangeModifier(action: action))
    }
}

struct FocusChangeModifier: ViewModifier {
    let action: (Bool) -> Void
    @FocusState private var isFocused: Bool
    
    func body(content: Content) -> some View {
        content
            .focused($isFocused)
            .onChange(of: isFocused) { newValue in
                action(newValue)
            }
    }
}
