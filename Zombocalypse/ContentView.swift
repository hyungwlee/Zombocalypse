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
        ZStack {
            SpriteView(scene: context.scene!, debugOptions: [.showsFPS, .showsNodeCount])
                .frame(width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.height)
                .edgesIgnoringSafeArea(.all)
        }
        .statusBarHidden()
    }
}

#Preview {
    ContentView()
        .ignoresSafeArea()
}
