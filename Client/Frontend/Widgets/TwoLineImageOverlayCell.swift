// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/

import UIKit
import Shared
import SiteImageView

class TwoLineImageOverlayCell: UITableViewCell,
                               ReusableCell,
                               ThemeApplicable {
    struct UX {
        static let imageSize: CGFloat = 28
        static let borderViewMargin: CGFloat = 16
        static let iconBorderWidth: CGFloat = 0.5
    }

    /// Cell reuse causes the chevron to appear where it shouldn't. So, we use a different reuseIdentifier to prevent that.
    static let accessoryUsageReuseIdentifier = "temporary-reuse-identifier"

    // Tableview cell items
    private lazy var selectedView: UIView = .build { _ in }

    lazy var containerView: UIView = .build { view in
        view.backgroundColor = .clear
    }

    lazy var leftImageView: FaviconImageView = .build { imageView in
        imageView.contentMode = .scaleAspectFit
        imageView.layer.cornerRadius = 5.0
        imageView.clipsToBounds = true
        imageView.layer.borderWidth = UX.iconBorderWidth
        imageView.backgroundColor = .clear
    }

    lazy var leftOverlayImageView: UIImageView = .build { imageView in
        imageView.contentMode = .scaleAspectFit
        imageView.clipsToBounds = true
    }

    lazy var stackView: UIStackView = .build { stackView in
        stackView.spacing = 8
        stackView.axis = .vertical
        stackView.distribution = .fillProportionally
    }

    lazy var titleLabel: UILabel = .build { label in
        label.font = DynamicFontHelper.defaultHelper.preferredFont(withTextStyle: .body, size: 16)
        label.textAlignment = .natural
    }

    lazy var descriptionLabel: UILabel = .build { label in
        label.font = DynamicFontHelper.defaultHelper.preferredFont(withTextStyle: .body, size: 14)
        label.textAlignment = .natural
    }

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupLayout()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupLayout() {
        separatorInset = UIEdgeInsets(top: 0,
                                      left: UX.imageSize + 2 * UX.borderViewMargin,
                                      bottom: 0,
                                      right: 0)
        selectionStyle = .default
        stackView.addArrangedSubview(titleLabel)
        stackView.addArrangedSubview(descriptionLabel)

        containerView.addSubview(leftImageView)
        containerView.addSubview(stackView)
        containerView.addSubview(leftOverlayImageView)

        contentView.addSubview(containerView)
        bringSubviewToFront(containerView)

        NSLayoutConstraint.activate([
            containerView.topAnchor.constraint(equalTo: contentView.topAnchor),
            containerView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            containerView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
            containerView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor,
                                                    constant: -16),

            leftImageView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor,
                                                   constant: 16),
            leftImageView.centerYAnchor.constraint(equalTo: containerView.centerYAnchor),
            leftImageView.heightAnchor.constraint(equalToConstant: UX.imageSize),
            leftImageView.widthAnchor.constraint(equalToConstant: UX.imageSize),
            leftImageView.trailingAnchor.constraint(equalTo: stackView.leadingAnchor,
                                                    constant: -16),

            leftOverlayImageView.trailingAnchor.constraint(equalTo: leftImageView.trailingAnchor,
                                                           constant: 8),
            leftOverlayImageView.bottomAnchor.constraint(equalTo: leftImageView.bottomAnchor,
                                                         constant: 8),
            leftOverlayImageView.heightAnchor.constraint(equalToConstant: 22),
            leftOverlayImageView.widthAnchor.constraint(equalToConstant: 22),

            stackView.topAnchor.constraint(equalTo: containerView.topAnchor,
                                           constant: 8),
            stackView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor,
                                              constant: -8),
            stackView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor,
                                                constant: -8),
        ])

        selectedBackgroundView = selectedView
    }

    func applyTheme(theme: Theme) {
        backgroundColor = theme.colors.layer5
        selectedView.backgroundColor = theme.colors.layer5Hover
        titleLabel.textColor = theme.colors.textPrimary
        descriptionLabel.textColor = theme.colors.textSecondary
        leftImageView.layer.borderColor = theme.colors.borderPrimary.cgColor
    }

    override func prepareForReuse() {
        super.prepareForReuse()

        selectionStyle = .default
        separatorInset = UIEdgeInsets(top: 0,
                                      left: UX.imageSize + 2 * UX.borderViewMargin,
                                      bottom: 0,
                                      right: 0)
        leftImageView.image = nil
    }
}
