//
//  ProgressiveBlurView.swift
//  Aidoku
//

import UIKit

final class ProgressiveBlurView: UIView {
    private struct BlurLayer {
        let view: UIVisualEffectView
        let animator: UIViewPropertyAnimator
        let intensity: CGFloat
        let mask: CAGradientLayer
    }

    private var blurLayers: [BlurLayer] = []
    private let tintLayer = CAGradientLayer()
    private let steps: Int

    init(steps: Int = 5) {
        self.steps = steps
        super.init(frame: .zero)
        isUserInteractionEnabled = false

        for index in 0..<steps {
            let view = UIVisualEffectView(effect: nil)
            view.isUserInteractionEnabled = false
            view.overrideUserInterfaceStyle = .dark
            let animator = UIViewPropertyAnimator(duration: 1, curve: .linear) {
                view.effect = UIBlurEffect(style: .dark)
            }
            animator.pausesOnCompletion = true
            let intensity = 0.2 + 0.8 * CGFloat(index + 1) / CGFloat(steps)
            animator.fractionComplete = intensity

            let mask = CAGradientLayer()
            mask.colors = [UIColor.clear.cgColor, UIColor.black.cgColor]
            mask.startPoint = CGPoint(x: 0.5, y: 0)
            mask.endPoint = CGPoint(x: 0.5, y: 1)
            view.layer.mask = mask

            addSubview(view)
            blurLayers.append(BlurLayer(view: view, animator: animator, intensity: intensity, mask: mask))
        }

        tintLayer.colors = [
            UIColor.black.withAlphaComponent(0).cgColor,
            UIColor.black.withAlphaComponent(0.9).cgColor
        ]
        tintLayer.startPoint = CGPoint(x: 0.5, y: 0)
        tintLayer.endPoint = CGPoint(x: 0.5, y: 1)
        layer.addSublayer(tintLayer)

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(reapplyIntensity),
            name: UIApplication.didBecomeActiveNotification,
            object: nil
        )
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
        for blurLayer in blurLayers where blurLayer.animator.state == .active {
            blurLayer.animator.stopAnimation(false)
            blurLayer.animator.finishAnimation(at: .current)
        }
    }

    @objc private func reapplyIntensity() {
        for blurLayer in blurLayers {
            blurLayer.animator.fractionComplete = blurLayer.intensity
        }
    }

    override func layoutSubviews() {
        super.layoutSubviews()

        CATransaction.begin()
        CATransaction.setDisableActions(true)
        for (index, blurLayer) in blurLayers.enumerated() {
            blurLayer.view.frame = bounds
            blurLayer.mask.frame = blurLayer.view.bounds
            let start = NSNumber(value: Double(index) / Double(steps + 1))
            let end = NSNumber(value: Double(index + 2) / Double(steps + 1))
            blurLayer.mask.locations = [start, end]
        }
        tintLayer.frame = bounds
        CATransaction.commit()
    }
}
