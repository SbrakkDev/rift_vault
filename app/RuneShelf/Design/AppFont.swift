import SwiftUI

private enum RuneFontFamily {
    static func name(for weight: Font.Weight) -> String {
        // Sora is bundled here as a variable font file whose registered
        // PostScript name resolves to Sora-Regular.
        "Sora-Regular"
    }
}

extension Font {
    static func rune(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        let fontName = RuneFontFamily.name(for: weight)
        return .custom(fontName, size: size)
    }

    static func rune(_ size: CGFloat, weight: Font.Weight = .regular, relativeTo textStyle: Font.TextStyle) -> Font {
        let fontName = RuneFontFamily.name(for: weight)
        return .custom(fontName, size: size, relativeTo: textStyle)
    }

    static func runeStyle(_ textStyle: Font.TextStyle, weight: Font.Weight = .regular) -> Font {
        switch textStyle {
        case .largeTitle:
            return .rune(34, weight: weight, relativeTo: .largeTitle)
        case .title:
            return .rune(28, weight: weight, relativeTo: .title)
        case .title2:
            return .rune(22, weight: weight, relativeTo: .title2)
        case .title3:
            return .rune(20, weight: weight, relativeTo: .title3)
        case .headline:
            return .rune(17, weight: weight, relativeTo: .headline)
        case .subheadline:
            return .rune(15, weight: weight, relativeTo: .subheadline)
        case .callout:
            return .rune(16, weight: weight, relativeTo: .callout)
        case .caption:
            return .rune(12, weight: weight, relativeTo: .caption)
        case .caption2:
            return .rune(11, weight: weight, relativeTo: .caption2)
        case .footnote:
            return .rune(13, weight: weight, relativeTo: .footnote)
        default:
            return .rune(17, weight: weight, relativeTo: .body)
        }
    }
}
