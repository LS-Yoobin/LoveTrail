import MapKit
import UIKit

/// Annotation view for an individual memory pin: a circular photo thumbnail in a
/// white-ringed accent circle, with the place-name pill below. Clusters use the
/// existing `MemoryMapMarkerAnnotationView` count marker instead.
final class MemoryPhotoMarkerView: MKAnnotationView {

    private static let circleDiameter: CGFloat = 46
    private static let imageDiameter: CGFloat = 40
    private static let ringWidth: CGFloat = 2
    private static let fillColor = UIColor(red: 1.0, green: 0.4, blue: 0.5, alpha: 1.0)
    private static let pillMaxWidth: CGFloat = 148
    private static let pillHorizontalPadding: CGFloat = 10
    private static let pillVerticalPadding: CGFloat = 5
    private static let pillBelowSpacing: CGFloat = 4

    private let circleView = UIView()
    private let imageView = UIImageView()
    private let glyphView = UIImageView()
    private let placeNamePill = UIView()
    private let placeNameLabel = UILabel()

    override var annotation: MKAnnotation? {
        didSet { applyContent() }
    }

    override init(annotation: MKAnnotation?, reuseIdentifier: String?) {
        super.init(annotation: annotation, reuseIdentifier: reuseIdentifier)
        clusteringIdentifier = "memoryCluster"
        displayPriority = .required
        clipsToBounds = false
        canShowCallout = false
        setupViews()
        applyContent()
    }

    @available(*, unavailable)
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupViews() {
        let d = Self.circleDiameter
        frame = CGRect(x: 0, y: 0, width: d, height: d)
        centerOffset = CGPoint(x: 0, y: -d / 2)

        circleView.frame = CGRect(x: 0, y: 0, width: d, height: d)
        circleView.backgroundColor = Self.fillColor
        circleView.layer.cornerRadius = d / 2
        circleView.layer.borderColor = UIColor.white.cgColor
        circleView.layer.borderWidth = Self.ringWidth
        circleView.layer.masksToBounds = true

        let img = Self.imageDiameter
        imageView.frame = CGRect(x: (d - img) / 2, y: (d - img) / 2, width: img, height: img)
        imageView.contentMode = .scaleAspectFill
        imageView.layer.cornerRadius = img / 2
        imageView.layer.masksToBounds = true

        glyphView.frame = circleView.bounds
        glyphView.image = UIImage(
            systemName: "heart.fill",
            withConfiguration: UIImage.SymbolConfiguration(pointSize: 16, weight: .semibold)
        )
        glyphView.tintColor = .white
        glyphView.contentMode = .center

        circleView.addSubview(glyphView)
        circleView.addSubview(imageView)
        addSubview(circleView)

        placeNamePill.backgroundColor = UIColor.black.withAlphaComponent(0.88)
        placeNamePill.isHidden = true
        placeNamePill.isUserInteractionEnabled = false

        placeNameLabel.font = .systemFont(ofSize: 11, weight: .semibold)
        placeNameLabel.textColor = .white
        placeNameLabel.textAlignment = .center
        placeNameLabel.numberOfLines = 1
        placeNameLabel.lineBreakMode = .byTruncatingTail

        placeNamePill.addSubview(placeNameLabel)
        addSubview(placeNamePill)
    }

    private func applyContent() {
        guard let memory = annotation as? MemoryMapAnnotation else {
            imageView.image = nil
            imageView.isHidden = true
            glyphView.isHidden = false
            placeNamePill.isHidden = true
            return
        }

        if let thumbnail = memory.section.moments.first?.thumbnail {
            imageView.image = thumbnail
            imageView.isHidden = false
            glyphView.isHidden = true
        } else {
            imageView.image = nil
            imageView.isHidden = true
            glyphView.isHidden = false
        }

        let text = memory.section.placeDisplay
        placeNameLabel.text = text
        placeNamePill.isHidden = text.isEmpty
        setNeedsLayout()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        layoutPlaceNamePill()
    }

    private func layoutPlaceNamePill() {
        guard !placeNamePill.isHidden, placeNameLabel.text != nil else { return }

        let maxLabelWidth = Self.pillMaxWidth - Self.pillHorizontalPadding * 2
        let measured = placeNameLabel.sizeThatFits(
            CGSize(width: maxLabelWidth, height: .greatestFiniteMagnitude)
        )
        let labelWidth = min(measured.width, maxLabelWidth)
        let pillWidth = labelWidth + Self.pillHorizontalPadding * 2
        let pillHeight = measured.height + Self.pillVerticalPadding * 2

        placeNamePill.bounds.size = CGSize(width: pillWidth, height: pillHeight)
        placeNamePill.layer.cornerRadius = pillHeight / 2

        placeNameLabel.frame = CGRect(
            x: Self.pillHorizontalPadding,
            y: Self.pillVerticalPadding,
            width: labelWidth,
            height: measured.height
        )

        placeNamePill.center = CGPoint(
            x: circleView.frame.midX,
            y: circleView.frame.maxY + Self.pillBelowSpacing + pillHeight / 2
        )
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        imageView.image = nil
        placeNamePill.isHidden = true
        placeNameLabel.text = nil
    }
}
