import SpriteKit

class UpgradeSpinner: SKNode {
    private let segments: [String]
    private let spinner: SKNode

    init(segments: [String], size: CGSize) {
        self.segments = segments
        self.spinner = SKNode()
        super.init()
        setupSpinner(size: size)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupSpinner(size: CGSize) {
        let segmentAngle = 2 * CGFloat.pi / CGFloat(segments.count)
        let radius = size.width / 2

        for (index, segmentName) in segments.enumerated() {
            let startAngle = CGFloat(index) * segmentAngle
            let endAngle = startAngle + segmentAngle

            let path = CGMutablePath()
            path.move(to: .zero)
            path.addArc(center: .zero, radius: radius, startAngle: startAngle, endAngle: endAngle, clockwise: false)

            let segment = SKShapeNode(path: path)
            segment.fillColor = SKColor.random()
            segment.strokeColor = .black
            segment.lineWidth = 2

            let label = SKLabelNode(text: segmentName)
            label.position = CGPoint(
                x: cos((startAngle + endAngle) / 2) * radius * 0.7,
                y: sin((startAngle + endAngle) / 2) * radius * 0.7
            )
            label.fontSize = 16
            label.fontColor = .black
            label.zRotation = -(startAngle + endAngle) / 2

            segment.addChild(label)
            spinner.addChild(segment)
        }

        addChild(spinner)
    }
    func spin(completion: @escaping (String) -> Void) {
        let randomSpin = CGFloat.random(in: 2 * CGFloat.pi...10 * CGFloat.pi)
        let spinAction = SKAction.rotate(byAngle: randomSpin, duration: 2)
        spinAction.timingMode = .easeOut

        spinner.run(spinAction) { [weak self] in
            guard let self = self else { return }
            let finalAngle = randomSpin.truncatingRemainder(dividingBy: 2 * CGFloat.pi)
            let selectedSegment = self.determineResult(finalAngle: finalAngle)
            completion(selectedSegment)
        }
    }

    private func determineResult(finalAngle: CGFloat) -> String {
        let normalizedAngle = (finalAngle + CGFloat.pi / 2).truncatingRemainder(dividingBy: 2 * CGFloat.pi)
        let segmentAngle = 2 * CGFloat.pi / CGFloat(segments.count)
        let index = Int(normalizedAngle / segmentAngle) % segments.count
        return segments[index]
    }
}

private extension SKColor {
    static func random() -> SKColor {
        return SKColor(hue: CGFloat.random(in: 0...1), saturation: 0.7, brightness: 0.9, alpha: 1)
    }
}
