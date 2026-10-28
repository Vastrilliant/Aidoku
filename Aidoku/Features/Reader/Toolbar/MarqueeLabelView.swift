//
//  MarqueeLabelView.swift
//  Aidoku
//

import UIKit

final class MarqueeLabelView: UIView {
    var text: String? {
        didSet {
            guard text != oldValue else { return }
            primaryLabel.text = text
            secondaryLabel.text = text
            setNeedsLayout()
            invalidateIntrinsicContentSize()
        }
    }

    var font: UIFont = .systemFont(ofSize: 16) {
        didSet {
            primaryLabel.font = font
            secondaryLabel.font = font
            setNeedsLayout()
            invalidateIntrinsicContentSize()
        }
    }

    var textColor: UIColor = .label {
        didSet {
            primaryLabel.textColor = textColor
            secondaryLabel.textColor = textColor
        }
    }

    private let contentView = UIView()
    private let primaryLabel = UILabel()
    private let secondaryLabel = UILabel()
    private let fadeMask = CAGradientLayer()

    private let gap: CGFloat = 40
    private let speed: CGFloat = 30
    private let fadeWidth: CGFloat = 18
    private let startDelay: CFTimeInterval = 1.5

    private var isMarqueeing = false
    private var laidOutSize: CGSize = .zero
    private var laidOutText: String?

    override init(frame: CGRect) {
        super.init(frame: frame)
        clipsToBounds = true
        addSubview(contentView)
        for label in [primaryLabel, secondaryLabel] {
            label.numberOfLines = 1
            label.lineBreakMode = .byClipping
            label.font = font
            label.textColor = textColor
            contentView.addSubview(label)
        }
        secondaryLabel.isHidden = true

        fadeMask.startPoint = CGPoint(x: 0, y: 0.5)
        fadeMask.endPoint = CGPoint(x: 1, y: 0.5)

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(restartIfNeeded),
            name: UIApplication.didBecomeActiveNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(restartIfNeeded),
            name: UIAccessibility.reduceMotionStatusDidChangeNotification,
            object: nil
        )
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    override var intrinsicContentSize: CGSize {
        CGSize(width: UIView.noIntrinsicMetric, height: ceil(font.lineHeight))
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        if window != nil {
            restartIfNeeded()
        } else {
            contentView.layer.removeAllAnimations()
        }
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        guard bounds.width > 0 else { return }
        if laidOutSize == bounds.size && laidOutText == text && (!isMarqueeing || contentView.layer.animation(forKey: "marquee") != nil) {
            return
        }
        laidOutSize = bounds.size
        laidOutText = text
        updateLayout()
    }

    @objc private func restartIfNeeded() {
        guard window != nil, bounds.width > 0 else { return }
        updateLayout()
    }

    private func updateLayout() {
        contentView.layer.removeAllAnimations()

        let textWidth = ceil(primaryLabel.sizeThatFits(CGSize(width: .greatestFiniteMagnitude, height: bounds.height)).width)
        let height = bounds.height
        let overflow = textWidth > bounds.width
        isMarqueeing = overflow && !UIAccessibility.isReduceMotionEnabled

        contentView.layer.removeAllAnimations()
        contentView.transform = .identity
        primaryLabel.frame = CGRect(x: 0, y: 0, width: textWidth, height: height)

        if isMarqueeing {
            secondaryLabel.isHidden = false
            secondaryLabel.frame = CGRect(x: textWidth + gap, y: 0, width: textWidth, height: height)
            contentView.frame = CGRect(x: 0, y: 0, width: textWidth * 2 + gap, height: height)
            applyFade(true)

            let distance = textWidth + gap
            let animation = CABasicAnimation(keyPath: "transform.translation.x")
            animation.fromValue = 0
            animation.toValue = -distance
            animation.duration = CFTimeInterval(distance / speed)
            animation.repeatCount = .infinity
            animation.timingFunction = CAMediaTimingFunction(name: .linear)
            animation.beginTime = CACurrentMediaTime() + startDelay
            animation.fillMode = .backwards
            contentView.layer.add(animation, forKey: "marquee")
        } else {
            secondaryLabel.isHidden = true
            contentView.frame = CGRect(x: 0, y: 0, width: overflow ? bounds.width : textWidth, height: height)
            primaryLabel.frame = contentView.bounds
            primaryLabel.lineBreakMode = overflow ? .byTruncatingTail : .byClipping
            applyFade(false)
        }
    }

    private func applyFade(_ enabled: Bool) {
        guard enabled, bounds.width > fadeWidth * 2 else {
            layer.mask = nil
            return
        }
        let fraction = fadeWidth / bounds.width
        fadeMask.frame = bounds
        fadeMask.colors = [
            UIColor.clear.cgColor,
            UIColor.black.cgColor,
            UIColor.black.cgColor,
            UIColor.clear.cgColor
        ]
        fadeMask.locations = [0, NSNumber(value: Double(fraction)), NSNumber(value: Double(1 - fraction)), 1]
        layer.mask = fadeMask
    }
}
