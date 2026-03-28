import SwiftUI
import UIKit

struct CardEffectRichTextView: UIViewRepresentable {
    let text: String
    var fontSize: CGFloat = 17
    var textColor: UIColor = .white

    func makeUIView(context: Context) -> UITextView {
        let textView = UITextView()
        textView.backgroundColor = .clear
        textView.isEditable = false
        textView.isSelectable = false
        textView.isScrollEnabled = false
        textView.textContainerInset = .zero
        textView.textContainer.lineFragmentPadding = 0
        textView.adjustsFontForContentSizeCategory = false
        return textView
    }

    func updateUIView(_ uiView: UITextView, context: Context) {
        uiView.attributedText = makeAttributedEffectText()
    }

    func sizeThatFits(_ proposal: ProposedViewSize, uiView: UITextView, context: Context) -> CGSize? {
        let width = proposal.width ?? uiView.bounds.width
        guard width > 0 else { return nil }
        let fitted = uiView.sizeThatFits(CGSize(width: width, height: .greatestFiniteMagnitude))
        return CGSize(width: width, height: fitted.height)
    }

    private func makeAttributedEffectText() -> NSAttributedString {
        let font = UIFont(name: "Sora-Regular", size: fontSize) ?? .systemFont(ofSize: fontSize, weight: .medium)
        let badgeDiameter = max(14, fontSize * 0.92)
        let symbolSide = max(13, fontSize * 0.84)
        let paragraph = NSMutableParagraphStyle()
        paragraph.lineSpacing = 2
        paragraph.lineBreakMode = .byWordWrapping

        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: textColor,
            .paragraphStyle: paragraph
        ]

        let result = NSMutableAttributedString()
        let pattern = #":rb_([a-zA-Z0-9_]+):"#
        let regex = try? NSRegularExpression(pattern: pattern)
        let nsText = text as NSString
        let fullRange = NSRange(location: 0, length: nsText.length)
        var currentLocation = 0

        regex?.enumerateMatches(in: text, options: [], range: fullRange) { match, _, _ in
            guard let match else { return }

            let prefixRange = NSRange(location: currentLocation, length: match.range.location - currentLocation)
            if prefixRange.length > 0 {
                result.append(NSAttributedString(string: nsText.substring(with: prefixRange), attributes: attributes))
            }

            let tokenValue = nsText.substring(with: match.range(at: 1)).lowercased()
            let attachment = NSTextAttachment()
            if let replacement = Self.imageForToken(tokenValue, badgeDiameter: badgeDiameter, symbolSide: symbolSide) {
                attachment.image = replacement.image
                attachment.bounds = CGRect(
                    x: 0,
                    y: replacement.yOffset,
                    width: replacement.size.width,
                    height: replacement.size.height
                )
                result.append(NSAttributedString(attachment: attachment))
            } else {
                result.append(NSAttributedString(string: nsText.substring(with: match.range), attributes: attributes))
            }

            currentLocation = match.range.location + match.range.length
        }

        if currentLocation < nsText.length {
            let suffixRange = NSRange(location: currentLocation, length: nsText.length - currentLocation)
            result.append(NSAttributedString(string: nsText.substring(with: suffixRange), attributes: attributes))
        }

        return result
    }

    private static func imageForToken(
        _ tokenValue: String,
        badgeDiameter: CGFloat,
        symbolSide: CGFloat
    ) -> (image: UIImage, size: CGSize, yOffset: CGFloat)? {
        if tokenValue.hasPrefix("energy_") || tokenValue.hasPrefix("rune_") {
            let suffix = String(tokenValue.split(separator: "_").last ?? "")
            if suffix.allSatisfy(\.isNumber) {
                return (
                    energyBadgeImage(number: suffix, diameter: badgeDiameter),
                    CGSize(width: badgeDiameter, height: badgeDiameter),
                    -2
                )
            }

            if domainAssetName(for: suffix) != nil {
                return (
                    domainBadgeImage(domain: suffix, diameter: badgeDiameter),
                    CGSize(width: badgeDiameter, height: badgeDiameter),
                    -2
                )
            }

            if suffix == "might" {
                return imageAttachment(assetName: "Might", side: symbolSide, yOffset: -1)
            }

            if suffix == "tap" {
                return imageAttachment(assetName: "Tap", side: symbolSide, yOffset: -1)
            }
        }

        if tokenValue == "might" {
            return imageAttachment(assetName: "Might", side: symbolSide, yOffset: -1)
        }

        if tokenValue == "tap" {
            return imageAttachment(assetName: "Tap", side: symbolSide, yOffset: -1)
        }

        return nil
    }

    private static func imageAttachment(assetName: String, side: CGFloat, yOffset: CGFloat) -> (image: UIImage, size: CGSize, yOffset: CGFloat)? {
        guard let image = UIImage(named: assetName) else { return nil }
        return (image, CGSize(width: side, height: side), yOffset)
    }

    private static func energyBadgeImage(number: String, diameter: CGFloat) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: diameter, height: diameter))
        return renderer.image { context in
            let rect = CGRect(origin: .zero, size: CGSize(width: diameter, height: diameter))
            UIColor.white.setFill()
            context.cgContext.fillEllipse(in: rect)

            let font = UIFont(name: "Sora-Regular", size: diameter * 0.46) ?? .systemFont(ofSize: diameter * 0.46, weight: .bold)
            let attributes: [NSAttributedString.Key: Any] = [
                .font: font,
                .foregroundColor: UIColor.black
            ]
            let text = NSAttributedString(string: number, attributes: attributes)
            let textSize = text.size()
            let textRect = CGRect(
                x: (diameter - textSize.width) / 2,
                y: (diameter - textSize.height) / 2,
                width: textSize.width,
                height: textSize.height
            )
            text.draw(in: textRect)
        }
    }

    private static func domainBadgeImage(domain: String, diameter: CGFloat) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: diameter, height: diameter))
        return renderer.image { context in
            let rect = CGRect(origin: .zero, size: CGSize(width: diameter, height: diameter))
            domainUIColor(for: domain).setFill()
            context.cgContext.fillEllipse(in: rect)

            guard let assetName = domainAssetName(for: domain),
                  let baseImage = UIImage(named: assetName)?.withTintColor(.white, renderingMode: .alwaysOriginal) else {
                return
            }

            let iconSide = diameter * 0.48
            let iconRect = CGRect(
                x: (diameter - iconSide) / 2,
                y: (diameter - iconSide) / 2,
                width: iconSide,
                height: iconSide
            )
            baseImage.draw(in: iconRect)
        }
    }

    private static func domainAssetName(for domain: String) -> String? {
        switch domain.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
        case "fury": return "Fury"
        case "calm": return "Calm"
        case "order": return "Order"
        case "chaos": return "Chaos"
        case "mind": return "Mind"
        case "body": return "Body"
        default: return nil
        }
    }

    private static func domainUIColor(for domain: String) -> UIColor {
        switch domain.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
        case "body":
            return UIColor(red: 0.93, green: 0.48, blue: 0.15, alpha: 1)
        case "mind":
            return UIColor(red: 0.16, green: 0.52, blue: 0.78, alpha: 1)
        case "chaos":
            return UIColor(red: 0.50, green: 0.20, blue: 0.66, alpha: 1)
        case "calm":
            return UIColor(red: 0.15, green: 0.63, blue: 0.40, alpha: 1)
        case "order":
            return UIColor(red: 0.82, green: 0.66, blue: 0.14, alpha: 1)
        case "fury":
            return UIColor(red: 0.83, green: 0.12, blue: 0.18, alpha: 1)
        default:
            return UIColor(white: 0.3, alpha: 1)
        }
    }
}
