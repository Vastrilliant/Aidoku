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
    static let expandedBarHeight: CGFloat = 16

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
    private var currentBarHeight: CGFloat = ReaderSliderView.barHeight
    private var touchStartX: CGFloat = 0
    private var touchStartValue: CGFloat = 0

    override init(frame: CGRect) {
        super.init(frame: frame)
        trackView.backgroundColor = Self.fillColor
        trackView.isUserInteractionEnabled = false
        fillView.backgroundColor = Self.trackColor
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
        let height = currentBarHeight
        let barY = (bounds.height - height) / 2
        trackView.frame = CGRect(x: 0, y: barY, width: bounds.width, height: height)

        let fillWidth = bounds.width * currentValue
        let x = direction == .forward ? 0 : bounds.width - fillWidth
        fillView.frame = CGRect(x: x, y: barY, width: fillWidth, height: height)
    }

    // larger touch target than the visible bar
    override func point(inside point: CGPoint, with event: UIEvent?) -> Bool {
        bounds.insetBy(dx: -8, dy: -16).contains(point)
    }

    private func setExpanded(_ expanded: Bool) {
        currentBarHeight = expanded ? Self.expandedBarHeight : Self.barHeight
        UIView.animate(
            withDuration: 0.25,
            delay: 0,
            usingSpringWithDamping: 0.8,
            initialSpringVelocity: 0,
            options: [.beginFromCurrentState, .allowUserInteraction]
        ) {
            self.layoutIfNeeded()
        }
    }

    private func value(for touch: UITouch) -> CGFloat {
        guard bounds.width > 0 else { return currentValue }
        let delta = (touch.location(in: self).x - touchStartX) / bounds.width
        let signedDelta = direction == .forward ? delta : -delta
        return touchStartValue + (maximumValue - minimumValue) * signedDelta
    }
}

extension ReaderSliderView {
    override func beginTracking(_ touch: UITouch, with event: UIEvent?) -> Bool {
        touchStartX = touch.location(in: self).x
        touchStartValue = currentValue
        setExpanded(true)
        return true
    }

    override func continueTracking(_ touch: UITouch, with event: UIEvent?) -> Bool {
        currentValue = value(for: touch)
        sendActions(for: .valueChanged)
        return true
    }

    override func endTracking(_ touch: UITouch?, with event: UIEvent?) {
        setExpanded(false)
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
