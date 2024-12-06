import SpriteKit

class UpgradeChoiceScreen: SKNode {
    private let options: [String]
    private var buttonActions: [() -> Void] = []

    init(options: [String]) {
        self.options = options
        super.init()
        setupScreen()
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupScreen() {
        let overlay = SKShapeNode(rectOf: CGSize(width: 400, height: 300), cornerRadius: 20)
        overlay.fillColor = SKColor.black.withAlphaComponent(0.8)
        overlay.strokeColor = .white
        overlay.lineWidth = 2
        addChild(overlay)

        let titleLabel = SKLabelNode(text: "Choose Your Upgrade")
        titleLabel.fontSize = 30
        titleLabel.fontColor = .white
        titleLabel.position = CGPoint(x: 0, y: 100)
        addChild(titleLabel)

        for (index, option) in options.enumerated() {
            let button = createButton(withText: option, at: CGPoint(x: 0, y: 50 - index * 70))
            button.name = "button_\(index)"
            addChild(button)
        }
    }
      private func createButton(withText text: String, at position: CGPoint) -> SKNode {
        let button = SKShapeNode(rectOf: CGSize(width: 200, height: 50), cornerRadius: 10)
        button.fillColor = .gray
        button.strokeColor = .white
        button.position = position

        let label = SKLabelNode(text: text)
        label.fontSize = 20
        label.fontColor = .white
        label.verticalAlignmentMode = .center
        button.addChild(label)

        return button
    }

    func setButtonActions(_ actions: [() -> Void]) {
        buttonActions = actions
    }

    func handleTouch(_ touch: UITouch, in scene: SKScene) {
        let location = touch.location(in: self)
        for (index, child) in children.enumerated() {
            if child.contains(location) && index < buttonActions.count {
                buttonActions[index]()
                break
            }
        }
    }
}
