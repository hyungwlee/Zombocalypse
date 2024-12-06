import SpriteKit

class ShopState {
    private var spinner: UpgradeSpinner?
    private var upgradeChoiceScreen: UpgradeChoiceScreen?

    func enterState(scene: SKScene) {
        scene.backgroundColor = .blue
        let label = SKLabelNode(text: "Shop State")
        label.position = CGPoint(x: scene.size.width / 2, y: scene.size.height - 50)
        label.fontSize = 40
        label.fontColor = .white
        scene.addChild(label)

        spinner = UpgradeSpinner(segments: ["Upgrade A", "Upgrade B", "Upgrade C", "Upgrade D"], size: CGSize(width: 300, height: 300))
        spinner?.position = CGPoint(x: scene.size.width / 2, y: scene.size.height / 2)
        if let spinner = spinner {
            scene.addChild(spinner)
        }

        let button = SKLabelNode(text: "Spin for Upgrade")
        button.name = "spinButton"
        button.fontSize = 30
        button.fontColor = .yellow
        button.position = CGPoint(x: scene.size.width / 2, y: 100)
        scene.addChild(button)
    }

    func handleTouch(_ touch: UITouch, scene: SKScene) {
        let location = touch.location(in: scene)
        let touchedNode = scene.atPoint(location)

        if touchedNode.name == "spinButton" {
            spinner?.spin { selectedSegment in
                print("Selected Upgrade: \(selectedSegment)")
                self.showUpgradeChoices(scene: scene)
            }
        } else if let upgradeChoiceScreen = upgradeChoiceScreen {
            upgradeChoiceScreen.handleTouch(touch, in: scene)
        }
    }
      private func showUpgradeChoices(scene: SKScene) {
        let options = ["Upgrade 1", "Upgrade 2", "Upgrade 3"]
        upgradeChoiceScreen = UpgradeChoiceScreen(options: options)
        upgradeChoiceScreen?.position = CGPoint(x: scene.size.width / 2, y: scene.size.height / 2)
        upgradeChoiceScreen?.setButtonActions([
            { print("Upgrade 1 selected") },
            { print("Upgrade 2 selected") },
            { print("Upgrade 3 selected") }
        ])

        if let upgradeChoiceScreen = upgradeChoiceScreen {
            scene.addChild(upgradeChoiceScreen)
        }
    }

    func exitState(scene: SKScene) {
        scene.removeAllChildren()
    }
}
