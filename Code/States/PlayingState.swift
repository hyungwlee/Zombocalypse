import SpriteKit

class PlayingState {
    func enterState(scene: SKScene) {
        scene.backgroundColor = .green
        let label = SKLabelNode(text: "Playing State")
        label.position = CGPoint(x: scene.size.width / 2, y: scene.size.height / 2)
        label.fontSize = 40
        label.fontColor = .white
        scene.addChild(label)
    }

    func exitState(scene: SKScene) {
        scene.removeAllChildren()
    }
}
