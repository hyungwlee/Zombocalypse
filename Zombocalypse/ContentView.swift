//
//  ContentView.swift
//  Zombocalypse
//
//
//

import SwiftUI
import SpriteKit

struct ContentView: View {
    let context = ZPGameContext(dependencies: .init(),
                                gameMode: .single)
    let screenSize: CGSize = UIScreen.main.bounds.size
    
    var body: some View {
        SpriteView(scene: ZPGameScene(context: context,
                                      size: screenSize))
    }
}

#Preview {
    ContentView()
        .ignoresSafeArea()
}
