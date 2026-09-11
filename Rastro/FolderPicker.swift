//
//  FolderPicker.swift
//  Rastro
//
//  Created by JoseAlvarez on 9/10/26.
//


import AppKit

/// Wraps NSOpenPanel. There is no SwiftUI equivalent that returns a folder
/// with security scope attached, so we reach into AppKit.
@MainActor
enum FolderPicker {

    static func chooseFolder() -> URL? {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.prompt = "Index"
        panel.message = "Choose a folder to index."

        return panel.runModal() == .OK ? panel.url : nil
    }
}