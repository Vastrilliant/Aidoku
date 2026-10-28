//
//  ReaderSliderView.swift
//  Aidoku (iOS)
//
//  Created by Skitty on 1/20/22.
//

import UIKit

class ReaderSliderView: UIControl {
    enum SliderDirection {
        case forward
        case backward
    }

    static let fillColor = UIColor(red: 0x8D / 255, green: 0x8D / 255, blue: 0x93 / 255, alpha: 1)
    static let trackColor = UIColor(red: 0x48 / 255, green: 0x48 / 255, blue: 0x4A / 255, alpha: 1)
    static let barHeight: CGFloat = 8

    var direction: SliderDirection = .forward {
        didSet { setNeedsLayout() }
    }

    var minimumValue: CGFloat = 0
    var maximumValue: CGFloat = 1
    var currentValue: CGFloat = 0 {
        didSet {
            let boundedValue = min(max(currentValue, minimumValue), maximumValue)
            if currentValue != boundedValue {
                currentValue = boundedValue
                return
            }
            setNeedsLayout()
        }
    }

    private let trackView = UIView()
    private let fillView = UIView()

    override init(frame: CGRect) {
        super.init(frame: frame)
        trackView.backgroundColor = Self.trackColor
        trackView.layer.cornerRadius = Self.barHeight / 2
        trackView.isUserInteractionEnabled = false
        fillView.backgroundColor = Self.fillColor
        fillView.layer.cornerRadius = Self.barHeight / 2
        fillView.isUserInteractionEnabled = false
        addSubview(trackView)
        addSubview(fillView)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var intrinsicContentSize: CGSize {
        CGSize(width: UIView.noIntrinsicMetric, height: Self.barHeight)
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        let barY = (bounds.height - Self.barHeight) / 2
        trackView.frame = CGRect(x: 0, y: barY, width: bounds.width, height: Self.barHeight)

        let fillWidth = bounds.width * currentValue
        let x = direction == .forward ? 0 : bounds.width - fillWidth
        fillView.frame = CGRect(x: x, y: barY, width: fillWidth, height: Self.barHeight)
    }

    // larger touch target than the visible bar
    override func point(inside point: CGPoint, with event: UIEvent?) -> Bool {
        bounds.insetBy(dx: -8, dy: -16).contains(point)
    }

    private func value(for touch: UITouch) -> CGFloat {
        guard bounds.width > 0 else { return currentValue }
        let x = min(max(touch.location(in: self).x, 0), bounds.width)
        let fraction = x / bounds.width
        let value = direction == .forward ? fraction : 1 - fraction
        return minimumValue + (maximumValue - minimumValue) * value
    }
}

extension ReaderSliderView {
    override func beginTracking(_ touch: UITouch, with event: UIEvent?) -> Bool {
        currentValue = value(for: touch)
        sendActions(for: .valueChanged)
        return true
    }

    override func continueTracking(_ touch: UITouch, with event: UIEvent?) -> Bool {
        currentValue = value(for: touch)
        sendActions(for: .valueChanged)
        return true
    }

    override func endTracking(_ touch: UITouch?, with event: UIEvent?) {
        sendActions(for: .editingDidEnd)
    }

    override func cancelTracking(with event: UIEvent?) {
        endTracking(nil, with: event)
    }
}

extension ReaderSliderView {
    func move(toValue value: CGFloat) {
        currentValue = value
    }
}
