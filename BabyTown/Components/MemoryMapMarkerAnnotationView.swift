import MapKit
import UIKit

/// Map pin used on the memories map — pink fill, white ring, white glyph / count.
final class MemoryMapMarkerAnnotationView: MKMarkerAnnotationView {

    private static let fillColor = BabyTownTheme.accentUIColor
    private static let ringWidth: CGFloat = 2.5
    private static let pillMaxWidth: CGFloat = 160
    private static let pillHorizontalPadding: CGFloat = 10
    private static let pillVerticalPadding: CGFloat = 5
    private static let pillBelowPinSpacing: CGFloat = 5
    private static let pillIconSize: CGFloat = 11
    private static let pillIconSpacing: CGFloat = 5

    private let placeNamePill = UIView()
    private let placeNameIcon = UIImageView()
    private let placeNameLabel = UILabel()

    override var annotation: MKAnnotation? {
        didSet { applyStyle() }
    }

    override init(annotation: MKAnnotation?, reuseIdentifier: String?) {
        super.init(annotation: annotation, reuseIdentifier: reuseIdentifier)
        canShowCallout = false
        displayPriority = .required
        clipsToBounds = false
        setupPlaceNamePill()
        applyStyle()
    }

    @available(*, unavailable)
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        applyWhiteRing()
        layoutPlaceNamePill()
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        placeNamePill.isHidden = true
        placeNameLabel.text = nil
        placeNameIcon.isHidden = true
    }

    private func setupPlaceNamePill() {
        placeNamePill.backgroundColor = UIColor.black.withAlphaComponent(0.88)
        placeNamePill.isHidden = true
        placeNamePill.isUserInteractionEnabled = false

        let iconConfig = UIImage.SymbolConfiguration(pointSize: Self.pillIconSize, weight: .semibold)
        placeNameIcon.image = UIImage(systemName: "mappin.circle.fill", withConfiguration: iconConfig)
        placeNameIcon.tintColor = .white
        placeNameIcon.contentMode = .scaleAspectFit
        placeNameIcon.isHidden = true

        placeNameLabel.font = .systemFont(ofSize: 11, weight: .semibold)
        placeNameLabel.textColor = .white
        placeNameLabel.textAlignment = .left
        placeNameLabel.numberOfLines = 1
        placeNameLabel.lineBreakMode = .byTruncatingTail

        placeNamePill.addSubview(placeNameIcon)
        placeNamePill.addSubview(placeNameLabel)
        addSubview(placeNamePill)
    }

    private func applyStyle() {
        markerTintColor = Self.fillColor
        glyphTintColor = .white
        titleVisibility = .hidden
        subtitleVisibility = .hidden

        if let cluster = annotation as? MemoryClusterAnnotation {
            placeNamePill.isHidden = true
            glyphImage = nil
            glyphText = "\(cluster.count)"
        } else if let memory = annotation as? MemoryMapAnnotation {
            glyphText = nil
            let config = UIImage.SymbolConfiguration(pointSize: 14, weight: .semibold)
            glyphImage = UIImage(systemName: "heart.fill", withConfiguration: config)
            updatePlaceNamePill(for: memory.section)
        } else {
            placeNamePill.isHidden = true
        }
    }

    private func updatePlaceNamePill(for section: DaySection) {
        guard let text = section.formattedPlaceName else {
            placeNamePill.isHidden = true
            placeNameLabel.text = nil
            placeNameIcon.isHidden = true
            return
        }

        placeNameLabel.text = text
        placeNameIcon.isHidden = !section.isPlaceNameUserSet
        placeNamePill.isHidden = false
        setNeedsLayout()
    }

    private func layoutPlaceNamePill() {
        guard !placeNamePill.isHidden, placeNameLabel.text != nil else { return }

        let showsIcon = !placeNameIcon.isHidden
        let iconBlock: CGFloat = showsIcon ? Self.pillIconSize + Self.pillIconSpacing : 0
        let maxLabelWidth = Self.pillMaxWidth - Self.pillHorizontalPadding * 2 - iconBlock

        let measured = placeNameLabel.sizeThatFits(
            CGSize(width: maxLabelWidth, height: .greatestFiniteMagnitude)
        )
        let labelWidth = min(measured.width, maxLabelWidth)
        let pillWidth = labelWidth + iconBlock + Self.pillHorizontalPadding * 2
        let pillHeight = max(measured.height, Self.pillIconSize) + Self.pillVerticalPadding * 2

        placeNamePill.bounds.size = CGSize(width: pillWidth, height: pillHeight)
        placeNamePill.layer.cornerRadius = pillHeight / 2

        var contentX = Self.pillHorizontalPadding
        if showsIcon {
            placeNameIcon.frame = CGRect(
                x: contentX,
                y: (pillHeight - Self.pillIconSize) / 2,
                width: Self.pillIconSize,
                height: Self.pillIconSize
            )
            contentX += iconBlock
        }

        placeNameLabel.frame = CGRect(
            x: contentX,
            y: (pillHeight - measured.height) / 2,
            width: labelWidth,
            height: measured.height
        )

        let pinBottom = markerPinBottomY()
        placeNamePill.center = CGPoint(
            x: bounds.midX,
            y: pinBottom + Self.pillBelowPinSpacing + pillHeight / 2
        )
    }

    /// Bottom edge of the circular pin glyph within this annotation view.
    private func markerPinBottomY() -> CGFloat {
        var pinBottom: CGFloat?
        for subview in subviews where subview !== placeNamePill {
            let size = min(subview.bounds.width, subview.bounds.height)
            if size >= 24, abs(subview.bounds.width - subview.bounds.height) < 2 {
                pinBottom = max(pinBottom ?? 0, subview.frame.maxY)
            }
        }
        return pinBottom ?? bounds.maxY
    }

    private func applyWhiteRing() {
        styleRingIfCircular(self)
        for subview in subviews {
            guard subview !== placeNamePill else { continue }
            styleRingIfCircular(subview)
            for nested in subview.subviews {
                styleRingIfCircular(nested)
            }
        }
    }

    private func styleRingIfCircular(_ view: UIView) {
        let size = min(view.bounds.width, view.bounds.height)
        guard size >= 24, abs(view.bounds.width - view.bounds.height) < 2 else { return }

        view.layer.borderColor = UIColor.white.cgColor
        view.layer.borderWidth = Self.ringWidth
        view.layer.cornerRadius = size / 2
        view.layer.masksToBounds = true
    }
}
