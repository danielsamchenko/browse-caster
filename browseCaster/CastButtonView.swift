//
//  CastButtonView.swift
//  browseCaster
//
//  Created by Daniel Samchenko on 2026-01-06.
//


import SwiftUI
import GoogleCast

struct CastButtonView: UIViewRepresentable {
    func makeUIView(context: Context) -> GCKUICastButton {
        let button = GCKUICastButton(frame: .zero)
        // Optional: button.tintColor = UIColor.label
        return button
    }

    func updateUIView(_ uiView: GCKUICastButton, context: Context) {}
}
