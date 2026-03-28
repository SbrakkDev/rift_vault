import SwiftUI

struct CardCostSummaryView: View {
    let card: RiftCard
    var fontSize: CGFloat = 22
    var iconDiameter: CGFloat = 22

    var body: some View {
        if components.isEmpty {
            Text("-")
                .font(.rune(fontSize, weight: .bold))
                .foregroundStyle(.white)
        } else {
            HStack(spacing: 8) {
                ForEach(Array(components.enumerated()), id: \.offset) { _, component in
                    switch component {
                    case let .energy(value):
                        Text("\(value)")
                            .font(.rune(fontSize, weight: .bold))
                            .foregroundStyle(.white)
                    case let .power(domain):
                        DomainCostBadge(domain: domain, diameter: iconDiameter)
                    }
                }
            }
            .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var components: [CostComponent] {
        var result: [CostComponent] = []

        if let cost = card.cost {
            result.append(.energy(cost))
        }

        if let powerCost = card.powerCost, powerCost > 0, let domain = card.domains.first {
            result.append(contentsOf: Array(repeating: .power(domain), count: powerCost))
        }

        return result
    }
}

private enum CostComponent: Hashable {
    case energy(Int)
    case power(String)
}

private struct DomainCostBadge: View {
    let domain: String
    let diameter: CGFloat

    var body: some View {
        ZStack {
            Circle()
                .fill(color)

            if let assetName {
                Image(assetName)
                    .resizable()
                    .renderingMode(.template)
                    .foregroundStyle(.white)
                    .scaledToFit()
                    .frame(width: diameter * 0.5, height: diameter * 0.5)
            }
        }
        .frame(width: diameter, height: diameter)
    }

    private var assetName: String? {
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

    private var color: Color {
        switch domain.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
        case "body":
            return Color(red: 0.93, green: 0.48, blue: 0.15)
        case "mind":
            return Color(red: 0.16, green: 0.52, blue: 0.78)
        case "chaos":
            return Color(red: 0.50, green: 0.20, blue: 0.66)
        case "calm":
            return Color(red: 0.15, green: 0.63, blue: 0.40)
        case "order":
            return Color(red: 0.82, green: 0.66, blue: 0.14)
        case "fury":
            return Color(red: 0.83, green: 0.12, blue: 0.18)
        default:
            return Color.white.opacity(0.2)
        }
    }
}
