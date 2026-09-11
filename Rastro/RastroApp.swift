//
//  RastroApp.swift
//  Rastro
//
//  Created by JoseAlvarez on 8/31/26.
//

import SwiftUI

@main
struct RastroApp: App {
    @State private var model = SearchModel()

    var body: some Scene {
        MenuBarExtra("Rastro", systemImage: "magnifyingglass") {
            SearchView(model: model)
                .frame(width: 420, height: 440)
        }
        .menuBarExtraStyle(.window)
    }
}
