//
//  ContentView.swift
//  Zombocalypse
//
//
//

import SwiftUI
import SpriteKit

struct ContentView: View {
    let context = ZPGameContext(dependencies: .init(), gameMode: .single)

    var body: some View {
        GeometryReader { geometry in
            // Directly initialize the game scene without optional binding
            let gameScene = ZPGameScene(context: context, size: geometry.size)
            
            SpriteView(scene: gameScene)
                .ignoresSafeArea()  // This ensures the game uses the full screen area
        }
    }
}

#Preview {
    ContentView()
        .ignoresSafeArea()
}
