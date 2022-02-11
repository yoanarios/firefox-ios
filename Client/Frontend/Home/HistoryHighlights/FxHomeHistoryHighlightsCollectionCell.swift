/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

import UIKit
import Storage

struct HistoryHighlightsCollectionCellConstants {
    static let maxNumberOfItemsPerColumn = 3
    static let maxNumberOfColumns = 3
}

struct HistoryHighlightsCollectionCellUX {
    static let estimatedCellHeight: CGFloat = 65
    static let verticalPadding: CGFloat = 8
    static let horizontalPadding: CGFloat = 16
}

class FxHomeHistoryHighlightsCollectionCell: UICollectionViewCell, ReusableCell {

    // MARK: - Properties
    var viewModel: FxHomeHistoryHightlightsVM?

    // MARK: - Variables
    /// We calculate the number of columns dynamically based on the numbers of items
    /// available such that we always have the appropriate number of columns for the
    /// rest of the dynamic calculations.
    var numberOfColumns: Int {
        guard let count = viewModel?.historyItems?.count else { return 0 }
        return Int(ceil(Double(count) / Double(HistoryHighlightsCollectionCellConstants.maxNumberOfItemsPerColumn)))
    }

    // MARK: - UI Elements
    lazy var collectionView: UICollectionView = {
        let collectionView = UICollectionView(frame: .zero,
                                              collectionViewLayout: compositionalLayout)
        collectionView.translatesAutoresizingMaskIntoConstraints = false
        collectionView.isScrollEnabled = true
        collectionView.alwaysBounceVertical = false
        collectionView.showsHorizontalScrollIndicator = false
        collectionView.backgroundColor = UIColor.clear
        collectionView.clipsToBounds = true
        collectionView.dataSource = self
        collectionView.delegate = self
        collectionView.register(HistoryHighlightsCell.self,
                                forCellWithReuseIdentifier: HistoryHighlightsCell.cellIdentifier)
        collectionView.contentInset = UIEdgeInsets(top: HistoryHighlightsCollectionCellUX.verticalPadding,
                                                   left: HistoryHighlightsCollectionCellUX.horizontalPadding,
                                                   bottom: HistoryHighlightsCollectionCellUX.verticalPadding,
                                                   right: HistoryHighlightsCollectionCellUX.horizontalPadding)

        return collectionView
    }()

    // MARK: - Inits
    convenience init(frame: CGRect,
                     and viewModel: FxHomeHistoryHightlightsVM) {
        self.init(frame: frame)
        setupLayout()
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupLayout()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Helper methods
    private func setupLayout() {
        contentView.addSubview(collectionView)

        NSLayoutConstraint.activate([
            collectionView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 2),
            collectionView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            collectionView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -2),
            collectionView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor)
        ])
    }

    private lazy var compositionalLayout: UICollectionViewCompositionalLayout = {
        let item = NSCollectionLayoutItem(
            layoutSize: NSCollectionLayoutSize(widthDimension: .fractionalWidth(1),
                                               heightDimension: .estimated(HistoryHighlightsCollectionCellUX.estimatedCellHeight))
        )

        let groupWidth: NSCollectionLayoutDimension
        if UIScreen.main.traitCollection.horizontalSizeClass == .compact {
            groupWidth = NSCollectionLayoutDimension.fractionalWidth(1)
        } else {
            groupWidth = NSCollectionLayoutDimension.fractionalWidth(1/3)
        }

        let verticalGroup = NSCollectionLayoutGroup.vertical(
            layoutSize: NSCollectionLayoutSize(widthDimension: groupWidth,
                                               heightDimension: .estimated(HistoryHighlightsCollectionCellUX.estimatedCellHeight)),
            subitems: [item, item, item]
        )

        let section = NSCollectionLayoutSection(group: verticalGroup)
        section.orthogonalScrollingBehavior = .continuous
        return UICollectionViewCompositionalLayout(section: section)
    }()
}

// MARK: - Collection View Data Source
extension FxHomeHistoryHighlightsCollectionCell: UICollectionViewDataSource {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        guard let count = viewModel?.historyItems?.count else { return 0 }

        // If there are less than or equal items to the max number of items allowed per column,
        // we can return the standard count, as we don't need to display filler cells.
        // However, if there's more items, filler cells needs to be accounted for, so sections
        // are always a multiple of the max number of items allowed per column.
        if count <= HistoryHighlightsCollectionCellConstants.maxNumberOfItemsPerColumn {
            return count
        } else {
            return numberOfColumns * HistoryHighlightsCollectionCellConstants.maxNumberOfItemsPerColumn
        }
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: HistoryHighlightsCell.cellIdentifier, for: indexPath) as! HistoryHighlightsCell

        let hideBottomLine = isBottomCell(indexPath: indexPath,
                                          totalItems: viewModel?.historyItems?.count)
        let cornersToRound = determineCornerToRound(indexPath: indexPath,
                                                    totalItems: viewModel?.historyItems?.count)

        guard let item = viewModel?.historyItems?[safe: indexPath.row] else {
            return configureFillerCell(cell, hideBottomLine: hideBottomLine, cornersToRound: cornersToRound)
        }

        if item.type == .item {
            return configureIndividualHighlightCell(cell, hideBottomLine: hideBottomLine, cornersToRound: cornersToRound, item: item)
        } else {
            return configureIndividualHighlightCell(cell, hideBottomLine: hideBottomLine, cornersToRound: cornersToRound, item: item)
        }
    }

    // MARK: - Cell helper functions

    /// Determines whether or not, given a certain number of items, a cell's given index
    /// path puts it at the bottom of its section, for any matrix.
    ///
    /// - Parameters:
    ///   - indexPath: The given cell's `IndexPath`
    ///   - totalItems: The number of total items
    /// - Returns: A boolean describing whether or the cell is a bottom cell.
    private func isBottomCell(indexPath: IndexPath, totalItems: Int?) -> Bool {
        guard let totalItems = totalItems else { return false }

        // First check if this is the last item in the list
        if indexPath.row == totalItems - 1
            || isBottomOfColumn(with: indexPath.row, totalItems: totalItems)
        { return true }

        return false
    }

    private func isBottomOfColumn(with currentIndex: Int, totalItems: Int) -> Bool {
        var bottomCellIndex: Int
        for column in 1...numberOfColumns {
            bottomCellIndex = (HistoryHighlightsCollectionCellConstants.maxNumberOfItemsPerColumn * column) - 1
            if currentIndex == bottomCellIndex { return true }
        }

        return false
    }

    private func determineCornerToRound(indexPath: IndexPath, totalItems: Int?) -> UIRectCorner {
        guard let totalItems = totalItems else { return [] }

        var cornersToRound = UIRectCorner()

        if isTopLeftCell(index: indexPath.row) { cornersToRound.insert(.topLeft) }
        if isTopRightCell(index: indexPath.row, totalItems: totalItems) { cornersToRound.insert(.topRight) }
        if isBottomLeftCell(index: indexPath.row, totalItems: totalItems) { cornersToRound.insert(.bottomLeft) }
        if isBottomRightCell(index: indexPath.row, totalItems: totalItems) { cornersToRound.insert(.bottomRight) }

        return cornersToRound
    }

    private func isTopLeftCell(index: Int) -> Bool {
       return index == 0
    }

    private func isTopRightCell(index: Int, totalItems: Int) -> Bool {
        let topRightIndex = (HistoryHighlightsCollectionCellConstants.maxNumberOfItemsPerColumn * (numberOfColumns - 1))
        return index == topRightIndex
    }

    private func isBottomLeftCell(index: Int, totalItems: Int) -> Bool {
        var bottomLeftIndex: Int {
            if totalItems <= HistoryHighlightsCollectionCellConstants.maxNumberOfItemsPerColumn {
                return totalItems - 1
            } else {
                return HistoryHighlightsCollectionCellConstants.maxNumberOfItemsPerColumn - 1
            }
        }

        if index == bottomLeftIndex { return true }

        return false
    }

    private func isBottomRightCell(index: Int, totalItems: Int) -> Bool {
        var bottomRightIndex: Int {
            if totalItems <= HistoryHighlightsCollectionCellConstants.maxNumberOfItemsPerColumn {
                return totalItems - 1
            } else {
                return (HistoryHighlightsCollectionCellConstants.maxNumberOfItemsPerColumn * numberOfColumns) - 1
            }
        }

        if index == bottomRightIndex { return true }

        return false
    }

    private func configureIndividualHighlightCell(_ cell: UICollectionViewCell,
                                                  hideBottomLine: Bool,
                                                  cornersToRound: UIRectCorner,
                                                  item: HighlightItem) -> UICollectionViewCell {

        guard let cell = cell as? HistoryHighlightsCell else { return UICollectionViewCell() }


        let itemURL = item.url2?.absoluteString ?? ""
        let site = Site(url: itemURL, title: item.displayTitle)

        let cellOptions = RecentlyVisitedCellOptions(title: site.title,
                                                     description: nil,
                                                     shouldHideBottomLine: hideBottomLine,
                                                     with: cornersToRound,
                                                     and: nil,
                                                     andIsFillerCell: false)

        cell.updateCell(with: cellOptions)

        viewModel?.getFavIcon(for: site) { image in
            cell.heroImage.image = image
        }

        return cell
    }

    private func configureGroupHighlightCell(_ cell: UICollectionViewCell,
                                             hideBottomLine: Bool,
                                             cornersToRound: UIRectCorner,
                                             item: HighlightItem) -> UICollectionViewCell {

        guard let cell = cell as? HistoryHighlightsCell else { return UICollectionViewCell() }

        let cellOptions = RecentlyVisitedCellOptions(title: item.displayTitle,
                                                     description: item.description,
                                                     shouldHideBottomLine: hideBottomLine,
                                                     with: cornersToRound,
                                                     and: nil,
                                                     andIsFillerCell: false)

        cell.updateCell(with: cellOptions)

        return cell

    }

    private func configureFillerCell(_ cell: UICollectionViewCell,
                                     hideBottomLine: Bool,
                                     cornersToRound: UIRectCorner) -> UICollectionViewCell {

        guard let cell = cell as? HistoryHighlightsCell else { return UICollectionViewCell() }

        let cellOptions = RecentlyVisitedCellOptions(shouldHideBottomLine: hideBottomLine,
                                                     with: cornersToRound,
                                                     andIsFillerCell: true)

        cell.updateCell(with: cellOptions)
        return cell
    }
}

extension FxHomeHistoryHighlightsCollectionCell: UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        if let highlight = viewModel?.historyItems?[safe: indexPath.row] {
            viewModel?.switchTo(highlight)
        }
    }
}
