import Foundation
import CoreText

/// Registers the bundled Outfit and Barlow Condensed fonts at launch, so no Info.plist
/// entry is needed. Both are under the SIL Open Font License (see Fonts/OFL-*.txt).
enum FontRegistry {
    static func registerBundledFonts() {
        let urls = Bundle.main.urls(forResourcesWithExtension: "ttf", subdirectory: nil) ?? []
        for url in urls {
            CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
        }
    }
}
