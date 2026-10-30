//
//  ReaderToolbarView.swift
//  Aidoku (iOS)
//
//  Created by Skitty on 8/15/22.
//

import UIKit

class ReaderToolbarView: UIView {
    var currentPageValue: Int? {
        didSet {
            if oldValue != currentPageValue {
                let feedbackGenerator = UISelectionFeedbackGenerator()
                feedbackGenerator.selectionChanged()
            }
        }
    }
    var currentPage: Int? {
        didSet { updatePageLabel() }
    }
    var totalPages: Int? {
        didSet { updatePageLabel() }
    }
    var title: String? {
        didSet { titleLabel.text = title }
    }

    let sliderView = ReaderSliderView()
    private let fadeView = ReaderToolbarFadeView()
    private let titleLabel = MarqueeLabelView()
    private let pageLabel = UILabel()

    init() {
        super.init(frame: .zero)
        configure()
        constrain()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure() {
        backgroundColor = .clear

        fadeView.isUserInteractionEnabled = false
        insertSubview(fadeView, at: 0)

        titleLabel.font = ReaderFont.publico(size: 16)
        titleLabel.textColor = ReaderSliderView.fillColor
        addSubview(titleLabel)

        pageLabel.font = ReaderFont.publico(size: 11)
        pageLabel.textColor = ReaderSliderView.fillColor
        pageLabel.textAlignment = .right
        pageLabel.numberOfLines = 1
        pageLabel.setContentCompressionResistancePriority(.required, for: .horizontal)
        pageLabel.setContentHuggingPriority(.required, for: .horizontal)
        addSubview(pageLabel)

        sliderView.semanticContentAttribute = .playback // for rtl languages
        addSubview(sliderView)
    }

    func constrain() {
        fadeView.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        pageLabel.translatesAutoresizingMaskIntoConstraints = false
        sliderView.translatesAutoresizingMaskIntoConstraints = false

        titleLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        NSLayoutConstraint.activate([
            fadeView.topAnchor.constraint(equalTo: topAnchor, constant: -72),
            fadeView.bottomAnchor.constraint(equalTo: bottomAnchor),
            fadeView.leadingAnchor.constraint(equalTo: leadingAnchor),
            fadeView.trailingAnchor.constraint(equalTo: trailingAnchor),

            titleLabel.leadingAnchor.constraint(equalTo: sliderView.leadingAnchor),
            titleLabel.topAnchor.constraint(equalTo: topAnchor, constant: 12),
            titleLabel.widthAnchor.constraint(lessThanOrEqualTo: sliderView.widthAnchor, multiplier: 0.5),
            titleLabel.trailingAnchor.constraint(lessThanOrEqualTo: pageLabel.leadingAnchor, constant: -16),

            pageLabel.trailingAnchor.constraint(equalTo: sliderView.trailingAnchor),
            pageLabel.centerYAnchor.constraint(equalTo: titleLabel.centerYAnchor),

            sliderView.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 10),
            sliderView.centerXAnchor.constraint(equalTo: centerXAnchor),
            sliderView.widthAnchor.constraint(equalTo: widthAnchor, multiplier: 0.9, constant: -36),
            sliderView.heightAnchor.constraint(equalToConstant: ReaderSliderView.barHeight),
            sliderView.bottomAnchor.constraint(equalTo: safeAreaLayoutGuide.bottomAnchor, constant: -14)
        ])
    }

    func displayPage(_ page: Int) {
        guard let totalPages = totalPages else {
            return
        }
        var page = page
        if page > totalPages {
            page = totalPages
        } else if page < 1 {
            page = 1
        }
        pageLabel.text = String(format: NSLocalizedString("%i_OF_%i"), page, totalPages)
        currentPageValue = page
    }

    func updatePageLabel() {
        guard var currentPage = currentPage, let totalPages = totalPages else {
            pageLabel.text = nil
            return
        }

        if currentPage > totalPages {
            currentPage = totalPages
        } else if currentPage < 1 {
            currentPage = 1
        }
        pageLabel.text = String(format: NSLocalizedString("%i_OF_%i"), currentPage, totalPages)
    }

    func updateSliderPosition() {
        guard let currentPage = currentPage, let totalPages = totalPages else { return }
        sliderView.move(toValue: CGFloat(currentPage - 1) / max(CGFloat(totalPages - 1), 1))
    }
}

private final class ReaderToolbarFadeView: UIView {
    override class var layerClass: AnyClass { CAGradientLayer.self }

    override init(frame: CGRect) {
        super.init(frame: frame)
        guard let gradient = layer as? CAGradientLayer else { return }
        let stops: [(CGFloat, CGFloat)] = [
            (0, 0), (0.15, 0.06), (0.3, 0.2), (0.45, 0.4), (0.6, 0.62), (0.8, 0.85), (1, 0.95)
        ]
        gradient.colors = stops.map { UIColor.black.withAlphaComponent($0.1).cgColor }
        gradient.locations = stops.map { NSNumber(value: Double($0.0)) }
        gradient.startPoint = CGPoint(x: 0.5, y: 0)
        gradient.endPoint = CGPoint(x: 0.5, y: 1)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
