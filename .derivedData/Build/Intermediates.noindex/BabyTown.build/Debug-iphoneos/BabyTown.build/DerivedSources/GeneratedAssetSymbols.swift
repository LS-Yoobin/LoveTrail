import Foundation
#if canImport(AppKit)
import AppKit
#endif
#if canImport(UIKit)
import UIKit
#endif
#if canImport(SwiftUI)
import SwiftUI
#endif
#if canImport(DeveloperToolsSupport)
import DeveloperToolsSupport
#endif

#if SWIFT_PACKAGE
private let resourceBundle = Foundation.Bundle.module
#else
private class ResourceBundleClass {}
private let resourceBundle = Foundation.Bundle(for: ResourceBundleClass.self)
#endif

// MARK: - Color Symbols -

@available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, *)
extension DeveloperToolsSupport.ColorResource {

}

// MARK: - Image Symbols -

@available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, *)
extension DeveloperToolsSupport.ImageResource {

    /// The "AppIconImage" asset catalog image resource.
    static let appIcon = DeveloperToolsSupport.ImageResource(name: "AppIconImage", bundle: resourceBundle)

    /// The "BabyTownFullIcon" asset catalog image resource.
    static let babyTownFullIcon = DeveloperToolsSupport.ImageResource(name: "BabyTownFullIcon", bundle: resourceBundle)

    /// The "BabyTownLogo" asset catalog image resource.
    static let babyTownLogo = DeveloperToolsSupport.ImageResource(name: "BabyTownLogo", bundle: resourceBundle)

    /// The "First Page Cat" asset catalog image resource.
    static let firstPageCat = DeveloperToolsSupport.ImageResource(name: "First Page Cat", bundle: resourceBundle)

    /// The "cat_variant_1" asset catalog image resource.
    static let catVariant1 = DeveloperToolsSupport.ImageResource(name: "cat_variant_1", bundle: resourceBundle)

    /// The "cat_variant_2" asset catalog image resource.
    static let catVariant2 = DeveloperToolsSupport.ImageResource(name: "cat_variant_2", bundle: resourceBundle)

    /// The "cat_variant_3" asset catalog image resource.
    static let catVariant3 = DeveloperToolsSupport.ImageResource(name: "cat_variant_3", bundle: resourceBundle)

    /// The "cat_variant_4" asset catalog image resource.
    static let catVariant4 = DeveloperToolsSupport.ImageResource(name: "cat_variant_4", bundle: resourceBundle)

    /// The "cat_variant_5" asset catalog image resource.
    static let catVariant5 = DeveloperToolsSupport.ImageResource(name: "cat_variant_5", bundle: resourceBundle)

    /// The "profile_calico_sit" asset catalog image resource.
    static let profileCalicoSit = DeveloperToolsSupport.ImageResource(name: "profile_calico_sit", bundle: resourceBundle)

    /// The "profile_cowcat_sit" asset catalog image resource.
    static let profileCowcatSit = DeveloperToolsSupport.ImageResource(name: "profile_cowcat_sit", bundle: resourceBundle)

    /// The "prop_cat_tree" asset catalog image resource.
    static let propCatTree = DeveloperToolsSupport.ImageResource(name: "prop_cat_tree", bundle: resourceBundle)

    /// The "prop_food_bowl" asset catalog image resource.
    static let propFoodBowl = DeveloperToolsSupport.ImageResource(name: "prop_food_bowl", bundle: resourceBundle)

    /// The "prop_litter_box" asset catalog image resource.
    static let propLitterBox = DeveloperToolsSupport.ImageResource(name: "prop_litter_box", bundle: resourceBundle)

    /// The "prop_water_bowl" asset catalog image resource.
    static let propWaterBowl = DeveloperToolsSupport.ImageResource(name: "prop_water_bowl", bundle: resourceBundle)

}

// MARK: - Color Symbol Extensions -

#if canImport(AppKit)
@available(macOS 14.0, *)
@available(macCatalyst, unavailable)
extension AppKit.NSColor {

}
#endif

#if canImport(UIKit)
@available(iOS 17.0, tvOS 17.0, *)
@available(watchOS, unavailable)
extension UIKit.UIColor {

}
#endif

#if canImport(SwiftUI)
@available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, *)
extension SwiftUI.Color {

}

@available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, *)
extension SwiftUI.ShapeStyle where Self == SwiftUI.Color {

}
#endif

// MARK: - Image Symbol Extensions -

#if canImport(AppKit)
@available(macOS 14.0, *)
@available(macCatalyst, unavailable)
extension AppKit.NSImage {

    /// The "AppIconImage" asset catalog image.
    static var appIcon: AppKit.NSImage {
#if !targetEnvironment(macCatalyst)
        .init(resource: .appIcon)
#else
        .init()
#endif
    }

    /// The "BabyTownFullIcon" asset catalog image.
    static var babyTownFullIcon: AppKit.NSImage {
#if !targetEnvironment(macCatalyst)
        .init(resource: .babyTownFullIcon)
#else
        .init()
#endif
    }

    /// The "BabyTownLogo" asset catalog image.
    static var babyTownLogo: AppKit.NSImage {
#if !targetEnvironment(macCatalyst)
        .init(resource: .babyTownLogo)
#else
        .init()
#endif
    }

    /// The "First Page Cat" asset catalog image.
    static var firstPageCat: AppKit.NSImage {
#if !targetEnvironment(macCatalyst)
        .init(resource: .firstPageCat)
#else
        .init()
#endif
    }

    /// The "cat_variant_1" asset catalog image.
    static var catVariant1: AppKit.NSImage {
#if !targetEnvironment(macCatalyst)
        .init(resource: .catVariant1)
#else
        .init()
#endif
    }

    /// The "cat_variant_2" asset catalog image.
    static var catVariant2: AppKit.NSImage {
#if !targetEnvironment(macCatalyst)
        .init(resource: .catVariant2)
#else
        .init()
#endif
    }

    /// The "cat_variant_3" asset catalog image.
    static var catVariant3: AppKit.NSImage {
#if !targetEnvironment(macCatalyst)
        .init(resource: .catVariant3)
#else
        .init()
#endif
    }

    /// The "cat_variant_4" asset catalog image.
    static var catVariant4: AppKit.NSImage {
#if !targetEnvironment(macCatalyst)
        .init(resource: .catVariant4)
#else
        .init()
#endif
    }

    /// The "cat_variant_5" asset catalog image.
    static var catVariant5: AppKit.NSImage {
#if !targetEnvironment(macCatalyst)
        .init(resource: .catVariant5)
#else
        .init()
#endif
    }

    /// The "profile_calico_sit" asset catalog image.
    static var profileCalicoSit: AppKit.NSImage {
#if !targetEnvironment(macCatalyst)
        .init(resource: .profileCalicoSit)
#else
        .init()
#endif
    }

    /// The "profile_cowcat_sit" asset catalog image.
    static var profileCowcatSit: AppKit.NSImage {
#if !targetEnvironment(macCatalyst)
        .init(resource: .profileCowcatSit)
#else
        .init()
#endif
    }

    /// The "prop_cat_tree" asset catalog image.
    static var propCatTree: AppKit.NSImage {
#if !targetEnvironment(macCatalyst)
        .init(resource: .propCatTree)
#else
        .init()
#endif
    }

    /// The "prop_food_bowl" asset catalog image.
    static var propFoodBowl: AppKit.NSImage {
#if !targetEnvironment(macCatalyst)
        .init(resource: .propFoodBowl)
#else
        .init()
#endif
    }

    /// The "prop_litter_box" asset catalog image.
    static var propLitterBox: AppKit.NSImage {
#if !targetEnvironment(macCatalyst)
        .init(resource: .propLitterBox)
#else
        .init()
#endif
    }

    /// The "prop_water_bowl" asset catalog image.
    static var propWaterBowl: AppKit.NSImage {
#if !targetEnvironment(macCatalyst)
        .init(resource: .propWaterBowl)
#else
        .init()
#endif
    }

}
#endif

#if canImport(UIKit)
@available(iOS 17.0, tvOS 17.0, *)
@available(watchOS, unavailable)
extension UIKit.UIImage {

    /// The "AppIconImage" asset catalog image.
    static var appIcon: UIKit.UIImage {
#if !os(watchOS)
        .init(resource: .appIcon)
#else
        .init()
#endif
    }

    /// The "BabyTownFullIcon" asset catalog image.
    static var babyTownFullIcon: UIKit.UIImage {
#if !os(watchOS)
        .init(resource: .babyTownFullIcon)
#else
        .init()
#endif
    }

    /// The "BabyTownLogo" asset catalog image.
    static var babyTownLogo: UIKit.UIImage {
#if !os(watchOS)
        .init(resource: .babyTownLogo)
#else
        .init()
#endif
    }

    /// The "First Page Cat" asset catalog image.
    static var firstPageCat: UIKit.UIImage {
#if !os(watchOS)
        .init(resource: .firstPageCat)
#else
        .init()
#endif
    }

    /// The "cat_variant_1" asset catalog image.
    static var catVariant1: UIKit.UIImage {
#if !os(watchOS)
        .init(resource: .catVariant1)
#else
        .init()
#endif
    }

    /// The "cat_variant_2" asset catalog image.
    static var catVariant2: UIKit.UIImage {
#if !os(watchOS)
        .init(resource: .catVariant2)
#else
        .init()
#endif
    }

    /// The "cat_variant_3" asset catalog image.
    static var catVariant3: UIKit.UIImage {
#if !os(watchOS)
        .init(resource: .catVariant3)
#else
        .init()
#endif
    }

    /// The "cat_variant_4" asset catalog image.
    static var catVariant4: UIKit.UIImage {
#if !os(watchOS)
        .init(resource: .catVariant4)
#else
        .init()
#endif
    }

    /// The "cat_variant_5" asset catalog image.
    static var catVariant5: UIKit.UIImage {
#if !os(watchOS)
        .init(resource: .catVariant5)
#else
        .init()
#endif
    }

    /// The "profile_calico_sit" asset catalog image.
    static var profileCalicoSit: UIKit.UIImage {
#if !os(watchOS)
        .init(resource: .profileCalicoSit)
#else
        .init()
#endif
    }

    /// The "profile_cowcat_sit" asset catalog image.
    static var profileCowcatSit: UIKit.UIImage {
#if !os(watchOS)
        .init(resource: .profileCowcatSit)
#else
        .init()
#endif
    }

    /// The "prop_cat_tree" asset catalog image.
    static var propCatTree: UIKit.UIImage {
#if !os(watchOS)
        .init(resource: .propCatTree)
#else
        .init()
#endif
    }

    /// The "prop_food_bowl" asset catalog image.
    static var propFoodBowl: UIKit.UIImage {
#if !os(watchOS)
        .init(resource: .propFoodBowl)
#else
        .init()
#endif
    }

    /// The "prop_litter_box" asset catalog image.
    static var propLitterBox: UIKit.UIImage {
#if !os(watchOS)
        .init(resource: .propLitterBox)
#else
        .init()
#endif
    }

    /// The "prop_water_bowl" asset catalog image.
    static var propWaterBowl: UIKit.UIImage {
#if !os(watchOS)
        .init(resource: .propWaterBowl)
#else
        .init()
#endif
    }

}
#endif

// MARK: - Thinnable Asset Support -

@available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, *)
@available(watchOS, unavailable)
extension DeveloperToolsSupport.ColorResource {

    private init?(thinnableName: Swift.String, bundle: Foundation.Bundle) {
#if canImport(AppKit) && os(macOS)
        if AppKit.NSColor(named: NSColor.Name(thinnableName), bundle: bundle) != nil {
            self.init(name: thinnableName, bundle: bundle)
        } else {
            return nil
        }
#elseif canImport(UIKit) && !os(watchOS)
        if UIKit.UIColor(named: thinnableName, in: bundle, compatibleWith: nil) != nil {
            self.init(name: thinnableName, bundle: bundle)
        } else {
            return nil
        }
#else
        return nil
#endif
    }

}

#if canImport(UIKit)
@available(iOS 17.0, tvOS 17.0, *)
@available(watchOS, unavailable)
extension UIKit.UIColor {

    private convenience init?(thinnableResource: DeveloperToolsSupport.ColorResource?) {
#if !os(watchOS)
        if let resource = thinnableResource {
            self.init(resource: resource)
        } else {
            return nil
        }
#else
        return nil
#endif
    }

}
#endif

#if canImport(SwiftUI)
@available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, *)
extension SwiftUI.Color {

    private init?(thinnableResource: DeveloperToolsSupport.ColorResource?) {
        if let resource = thinnableResource {
            self.init(resource)
        } else {
            return nil
        }
    }

}

@available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, *)
extension SwiftUI.ShapeStyle where Self == SwiftUI.Color {

    private init?(thinnableResource: DeveloperToolsSupport.ColorResource?) {
        if let resource = thinnableResource {
            self.init(resource)
        } else {
            return nil
        }
    }

}
#endif

@available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, *)
@available(watchOS, unavailable)
extension DeveloperToolsSupport.ImageResource {

    private init?(thinnableName: Swift.String, bundle: Foundation.Bundle) {
#if canImport(AppKit) && os(macOS)
        if bundle.image(forResource: NSImage.Name(thinnableName)) != nil {
            self.init(name: thinnableName, bundle: bundle)
        } else {
            return nil
        }
#elseif canImport(UIKit) && !os(watchOS)
        if UIKit.UIImage(named: thinnableName, in: bundle, compatibleWith: nil) != nil {
            self.init(name: thinnableName, bundle: bundle)
        } else {
            return nil
        }
#else
        return nil
#endif
    }

}

#if canImport(AppKit)
@available(macOS 14.0, *)
@available(macCatalyst, unavailable)
extension AppKit.NSImage {

    private convenience init?(thinnableResource: DeveloperToolsSupport.ImageResource?) {
#if !targetEnvironment(macCatalyst)
        if let resource = thinnableResource {
            self.init(resource: resource)
        } else {
            return nil
        }
#else
        return nil
#endif
    }

}
#endif

#if canImport(UIKit)
@available(iOS 17.0, tvOS 17.0, *)
@available(watchOS, unavailable)
extension UIKit.UIImage {

    private convenience init?(thinnableResource: DeveloperToolsSupport.ImageResource?) {
#if !os(watchOS)
        if let resource = thinnableResource {
            self.init(resource: resource)
        } else {
            return nil
        }
#else
        return nil
#endif
    }

}
#endif

