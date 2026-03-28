import SwiftUI

private enum CompanionDeckPickerTarget: String, Identifiable {
    case topPlayer
    case bottomPlayer

    var id: String { rawValue }

    var isLeftPlayer: Bool {
        self == .topPlayer
    }

    var title: String {
        switch self {
        case .topPlayer:
            return "Deck player alto"
        case .bottomPlayer:
            return "Deck player basso"
        }
    }
}

struct CompanionView: View {
    @EnvironmentObject private var store: RuneShelfStore

    @State private var pickerTarget: CompanionDeckPickerTarget?
    @State private var d20Result: Int?

    var body: some View {
        ZStack {
            VaultBackground()

            TimelineView(.periodic(from: .now, by: 1)) { context in
                let elapsedSeconds = store.scoreboard.currentElapsedSeconds(referenceDate: context.date)
                let topTheme = CompanionDeckTheme(
                    legend: store.companionDeckLegend(for: store.scoreboard.leftDeckReference),
                    fallbackPrimary: Color(red: 0.08, green: 0.29, blue: 0.44),
                    fallbackSecondary: Color(red: 0.10, green: 0.18, blue: 0.31),
                    fallbackAccent: VaultPalette.highlight
                )
                let bottomTheme = CompanionDeckTheme(
                    legend: store.companionDeckLegend(for: store.scoreboard.rightDeckReference),
                    fallbackPrimary: Color(red: 0.42, green: 0.21, blue: 0.10),
                    fallbackSecondary: Color(red: 0.19, green: 0.10, blue: 0.12),
                    fallbackAccent: VaultPalette.accent
                )

                VStack(spacing: 16) {
                    CompanionPlayerPane(
                        score: store.scoreboard.leftScore,
                        accent: topTheme.accent,
                        surfaceTop: topTheme.primary,
                        surfaceBottom: topTheme.secondary,
                        elapsedSeconds: elapsedSeconds,
                        isTimerRunning: store.scoreboard.isTimerRunning,
                        outcome: playerOutcome(isLeftPlayer: true),
                        deckName: store.companionDeckName(for: store.scoreboard.leftDeckReference),
                        deckOwner: store.companionDeckOwnerLabel(for: store.scoreboard.leftDeckReference),
                        legend: store.companionDeckLegend(for: store.scoreboard.leftDeckReference),
                        onToggleTimer: {
                            store.toggleMatchTimer()
                        },
                        onAdjust: { delta in
                            store.adjustScore(left: delta)
                        },
                        onSelectDeck: {
                            pickerTarget = .topPlayer
                        }
                    )
                    .rotationEffect(.degrees(180))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                    companionCenterControls
                        .frame(height: 134)

                    CompanionPlayerPane(
                        score: store.scoreboard.rightScore,
                        accent: bottomTheme.accent,
                        surfaceTop: bottomTheme.primary,
                        surfaceBottom: bottomTheme.secondary,
                        elapsedSeconds: elapsedSeconds,
                        isTimerRunning: store.scoreboard.isTimerRunning,
                        outcome: playerOutcome(isLeftPlayer: false),
                        deckName: store.companionDeckName(for: store.scoreboard.rightDeckReference),
                        deckOwner: store.companionDeckOwnerLabel(for: store.scoreboard.rightDeckReference),
                        legend: store.companionDeckLegend(for: store.scoreboard.rightDeckReference),
                        onToggleTimer: {
                            store.toggleMatchTimer()
                        },
                        onAdjust: { delta in
                            store.adjustScore(right: delta)
                        },
                        onSelectDeck: {
                            pickerTarget = .bottomPlayer
                        }
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 14)
            }

            if let d20Result {
                CompanionD20Overlay(result: d20Result) {
                    dismissD20Overlay()
                }
                .transition(.opacity.combined(with: .scale(scale: 0.96)))
                .zIndex(10)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await store.refreshFriendsIfNeeded()
            await store.refreshFriendDecksIfNeeded()
        }
        .sheet(item: $pickerTarget) { target in
            CompanionDeckPickerSheet(
                title: target.title,
                selectedReference: target.isLeftPlayer ? store.scoreboard.leftDeckReference : store.scoreboard.rightDeckReference,
                onClear: {
                    store.setCompanionDeck(nil, forLeftPlayer: target.isLeftPlayer)
                    pickerTarget = nil
                },
                onSelectLocal: { deck in
                    store.setCompanionDeck(store.localDeckReference(for: deck.id), forLeftPlayer: target.isLeftPlayer)
                    pickerTarget = nil
                },
                onSelectRemote: { deck in
                    store.setCompanionDeck(store.remoteDeckReference(for: deck), forLeftPlayer: target.isLeftPlayer)
                    pickerTarget = nil
                }
            )
            .environmentObject(store)
        }
    }

    private var companionCenterControls: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Text("Match")
                    .font(.runeStyle(.caption, weight: .black))
                    .foregroundStyle(.white.opacity(0.72))

                Spacer(minLength: 0)

                Button {
                    showD20Roll()
                } label: {
                    Image(systemName: "die.face.5.fill")
                        .font(.runeStyle(.caption, weight: .black))
                        .frame(width: 28, height: 28)
                }
                .buttonStyle(.plain)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color.black.opacity(0.16))
                )
                .foregroundStyle(.white)

                Button {
                    store.saveMatchRecord(opponentName: "")
                } label: {
                    Image(systemName: "square.and.arrow.down")
                        .font(.runeStyle(.caption, weight: .black))
                        .frame(width: 28, height: 28)
                }
                .buttonStyle(.plain)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color.black.opacity(0.16))
                )
                .foregroundStyle(VaultPalette.highlight)

                Button {
                    store.toggleForcedDraw()
                } label: {
                    Text("X")
                        .font(.runeStyle(.caption, weight: .black))
                        .frame(width: 28, height: 28)
                }
                .buttonStyle(.plain)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(
                            store.scoreboard.forcedOutcome == .draw
                                ? VaultPalette.highlight
                                : Color.black.opacity(0.16)
                        )
                )
                .foregroundStyle(
                    store.scoreboard.forcedOutcome == .draw
                        ? VaultPalette.backgroundBottom
                        : .white
                )

                Button {
                    store.resetScoreboard()
                } label: {
                    Image(systemName: "arrow.counterclockwise")
                        .font(.runeStyle(.caption, weight: .black))
                        .frame(width: 28, height: 28)
                }
                .buttonStyle(.plain)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color.black.opacity(0.16))
                )
                .foregroundStyle(.white)

            }

            HStack(spacing: 10) {
                roundsControl(
                    rounds: store.scoreboard.leftRounds,
                    accent: VaultPalette.highlight,
                    onDecrease: { store.adjustRounds(left: -1) },
                    onIncrease: { store.adjustRounds(left: 1) }
                )

                Text("BO3")
                    .font(.runeStyle(.caption, weight: .black))
                    .foregroundStyle(.white.opacity(0.6))
                    .frame(width: 40)

                roundsControl(
                    rounds: store.scoreboard.rightRounds,
                    accent: VaultPalette.accent,
                    onDecrease: { store.adjustRounds(right: -1) },
                    onIncrease: { store.adjustRounds(right: 1) }
                )
            }

            HStack(spacing: 10) {
                companionResetButton(
                    title: "Reset punti",
                    systemImage: "number.square",
                    action: { store.resetMatchScores() }
                )

                companionResetButton(
                    title: "Reset timer",
                    systemImage: "timer",
                    action: { store.resetMatchTimer() }
                )
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(VaultPalette.panelSoft.opacity(0.92))
        )
    }

    private func roundsControl(
        rounds: Int,
        accent: Color,
        onDecrease: @escaping () -> Void,
        onIncrease: @escaping () -> Void
    ) -> some View {
        HStack(spacing: 10) {
            roundButton(systemName: "minus", disabled: rounds == 0, action: onDecrease)

            HStack(spacing: 6) {
                ForEach(0..<2, id: \.self) { index in
                    Circle()
                        .fill(index < rounds ? accent : Color.white.opacity(0.12))
                        .frame(width: 12, height: 12)
                }
            }
            .frame(maxWidth: .infinity)

            roundButton(systemName: "plus", disabled: rounds == 2, action: onIncrease)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.black.opacity(0.14))
        )
    }

    private func roundButton(systemName: String, disabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.runeStyle(.caption, weight: .black))
                .frame(width: 28, height: 28)
        }
        .buttonStyle(.plain)
        .foregroundStyle(disabled ? .white.opacity(0.28) : .white)
        .disabled(disabled)
    }

    private func companionResetButton(
        title: String,
        systemImage: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: systemImage)
                    .font(.runeStyle(.caption, weight: .black))
                Text(title)
                    .font(.runeStyle(.caption, weight: .black))
                    .lineLimit(1)
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
        }
        .buttonStyle(.plain)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.black.opacity(0.14))
        )
    }

    private func playerOutcome(isLeftPlayer: Bool) -> CompanionPlayerOutcome {
        if store.scoreboard.forcedOutcome == .draw {
            return .neutral
        }

        let playerScore = isLeftPlayer ? store.scoreboard.leftScore : store.scoreboard.rightScore
        let opponentScore = isLeftPlayer ? store.scoreboard.rightScore : store.scoreboard.leftScore

        if playerScore >= 8 && playerScore > opponentScore {
            return .winner
        }

        if playerScore == 10 {
            return .extended
        }

        if playerScore >= 8 {
            return .matchPoint
        }

        return .neutral
    }

    private func showD20Roll() {
        withAnimation(.spring(response: 0.32, dampingFraction: 0.82)) {
            d20Result = Int.random(in: 1...20)
        }
    }

    private func dismissD20Overlay() {
        withAnimation(.easeOut(duration: 0.18)) {
            d20Result = nil
        }
    }
}

private enum CompanionPlayerOutcome {
    case neutral
    case matchPoint
    case winner
    case extended

    var label: String? {
        switch self {
        case .neutral:
            return nil
        case .matchPoint:
            return "8+"
        case .winner:
            return "Vinta"
        case .extended:
            return "10"
        }
    }
}

private struct CompanionD20Overlay: View {
    let result: Int
    let onDismiss: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.46)
                .ignoresSafeArea()

            VStack(spacing: 18) {
                ZStack {
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [
                                    VaultPalette.highlight.opacity(0.34),
                                    Color.clear
                                ],
                                center: .center,
                                startRadius: 12,
                                endRadius: 148
                            )
                        )
                        .frame(width: 240, height: 240)

                    CompanionD20Crystal()
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color(red: 0.13, green: 0.19, blue: 0.31),
                                    Color(red: 0.05, green: 0.08, blue: 0.16)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 188, height: 212)
                        .overlay {
                            CompanionD20Crystal()
                                .stroke(VaultPalette.highlight.opacity(0.84), lineWidth: 2.5)
                        }
                        .overlay {
                            CompanionD20FacetLines()
                                .stroke(Color.white.opacity(0.16), lineWidth: 1)
                                .padding(22)
                        }
                        .shadow(color: VaultPalette.highlight.opacity(0.42), radius: 28, y: 12)
                        .overlay {
                            VStack(spacing: 8) {
                                Text("D20")
                                    .font(.runeStyle(.caption, weight: .black))
                                    .tracking(3)
                                    .foregroundStyle(VaultPalette.highlight.opacity(0.88))

                                Text("\(result)")
                                    .font(.rune(72, weight: .black))
                                    .monospacedDigit()
                                    .foregroundStyle(.white)
                            }
                        }
                }

                Text("Tocca per chiudere")
                    .font(.runeStyle(.caption, weight: .bold))
                    .foregroundStyle(.white.opacity(0.72))
            }
            .padding(24)
        }
        .contentShape(Rectangle())
        .onTapGesture(perform: onDismiss)
    }
}

private struct CompanionD20Crystal: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let top = CGPoint(x: rect.midX, y: rect.minY)
        let upperRight = CGPoint(x: rect.maxX, y: rect.minY + rect.height * 0.28)
        let lowerRight = CGPoint(x: rect.maxX * 0.88, y: rect.maxY - rect.height * 0.18)
        let bottom = CGPoint(x: rect.midX, y: rect.maxY)
        let lowerLeft = CGPoint(x: rect.minX + rect.width * 0.12, y: rect.maxY - rect.height * 0.18)
        let upperLeft = CGPoint(x: rect.minX, y: rect.minY + rect.height * 0.28)

        path.move(to: top)
        path.addLines([upperRight, lowerRight, bottom, lowerLeft, upperLeft, top])
        path.closeSubpath()
        return path
    }
}

private struct CompanionD20FacetLines: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let center = CGPoint(x: rect.midX, y: rect.midY)

        let top = CGPoint(x: rect.midX, y: rect.minY)
        let upperRight = CGPoint(x: rect.maxX, y: rect.minY + rect.height * 0.28)
        let lowerRight = CGPoint(x: rect.maxX * 0.88, y: rect.maxY - rect.height * 0.18)
        let bottom = CGPoint(x: rect.midX, y: rect.maxY)
        let lowerLeft = CGPoint(x: rect.minX + rect.width * 0.12, y: rect.maxY - rect.height * 0.18)
        let upperLeft = CGPoint(x: rect.minX, y: rect.minY + rect.height * 0.28)

        path.move(to: top)
        path.addLine(to: center)
        path.move(to: upperRight)
        path.addLine(to: center)
        path.move(to: lowerRight)
        path.addLine(to: center)
        path.move(to: bottom)
        path.addLine(to: center)
        path.move(to: lowerLeft)
        path.addLine(to: center)
        path.move(to: upperLeft)
        path.addLine(to: center)

        path.move(to: CGPoint(x: rect.minX + rect.width * 0.2, y: rect.minY + rect.height * 0.42))
        path.addLine(to: CGPoint(x: rect.maxX - rect.width * 0.2, y: rect.minY + rect.height * 0.42))

        path.move(to: CGPoint(x: rect.minX + rect.width * 0.24, y: rect.maxY - rect.height * 0.28))
        path.addLine(to: CGPoint(x: rect.maxX - rect.width * 0.24, y: rect.maxY - rect.height * 0.28))

        return path
    }
}

private struct CompanionDeckTheme {
    let primary: Color
    let secondary: Color
    let accent: Color

    init(
        legend: RiftCard?,
        fallbackPrimary: Color,
        fallbackSecondary: Color,
        fallbackAccent: Color
    ) {
        let palette = (legend?.domains ?? [])
            .compactMap(CompanionDomainPalette.init(domain:))

        if let first = palette.first {
            primary = first.primary
            accent = first.accent

            if let second = palette.dropFirst().first {
                secondary = second.primary
            } else {
                secondary = first.secondary
            }
        } else {
            primary = fallbackPrimary
            secondary = fallbackSecondary
            accent = fallbackAccent
        }
    }
}

private struct CompanionDomainPalette {
    let primary: Color
    let secondary: Color
    let accent: Color

    init?(domain: String) {
        switch domain.lowercased() {
        case "body":
            primary = Color(red: 0.88, green: 0.42, blue: 0.12)
            secondary = Color(red: 0.49, green: 0.18, blue: 0.06)
            accent = Color(red: 1.00, green: 0.73, blue: 0.32)
        case "chaos":
            primary = Color(red: 0.46, green: 0.16, blue: 0.63)
            secondary = Color(red: 0.20, green: 0.06, blue: 0.32)
            accent = Color(red: 0.80, green: 0.48, blue: 0.95)
        case "mind":
            primary = Color(red: 0.10, green: 0.44, blue: 0.86)
            secondary = Color(red: 0.05, green: 0.20, blue: 0.47)
            accent = Color(red: 0.47, green: 0.84, blue: 1.00)
        case "calm":
            primary = Color(red: 0.10, green: 0.63, blue: 0.30)
            secondary = Color(red: 0.05, green: 0.29, blue: 0.14)
            accent = Color(red: 0.56, green: 0.93, blue: 0.58)
        case "fury":
            primary = Color(red: 0.82, green: 0.16, blue: 0.08)
            secondary = Color(red: 0.39, green: 0.07, blue: 0.05)
            accent = Color(red: 1.00, green: 0.42, blue: 0.24)
        case "order":
            primary = Color(red: 0.82, green: 0.63, blue: 0.12)
            secondary = Color(red: 0.38, green: 0.27, blue: 0.06)
            accent = Color(red: 1.00, green: 0.88, blue: 0.30)
        case "death":
            primary = Color(red: 0.58, green: 0.10, blue: 0.16)
            secondary = Color(red: 0.22, green: 0.04, blue: 0.08)
            accent = Color(red: 0.94, green: 0.30, blue: 0.42)
        default:
            return nil
        }
    }
}

private struct CompanionPlayerPane: View {
    let score: Int
    let accent: Color
    let surfaceTop: Color
    let surfaceBottom: Color
    let elapsedSeconds: Int
    let isTimerRunning: Bool
    let outcome: CompanionPlayerOutcome
    let deckName: String?
    let deckOwner: String?
    let legend: RiftCard?
    let onToggleTimer: () -> Void
    let onAdjust: (Int) -> Void
    let onSelectDeck: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            HStack {
                deckArea
                    .frame(maxWidth: 220, alignment: .leading)
                Spacer(minLength: 0)
            }

            HStack(spacing: 0) {
                edgeTapZone(symbol: "minus", disabled: score == 0) {
                    onAdjust(-1)
                }

                VStack(spacing: 16) {
                    ZStack(alignment: .topTrailing) {
                        Text("\(score)")
                            .font(.rune(92, weight: .black))
                            .monospacedDigit()
                            .foregroundStyle(scoreColor)
                            .minimumScaleFactor(0.65)
                            .frame(maxWidth: .infinity)

                        if let outcomeLabel = outcome.label {
                            Text(outcomeLabel)
                                .font(.runeStyle(.caption, weight: .black))
                                .padding(.horizontal, 10)
                                .padding(.vertical, 7)
                                .background(
                                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                                        .fill(accent.opacity(0.92))
                                )
                                .foregroundStyle(VaultPalette.backgroundBottom)
                                .offset(x: 14, y: -8)
                        }
                    }

                    scoreScale

                    timerArea
                }
                .frame(maxWidth: .infinity)

                edgeTapZone(symbol: "plus", disabled: score == 10) {
                    onAdjust(1)
                }
            }

            Spacer(minLength: 0)
        }
        .padding(14)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [surfaceTop, surfaceBottom],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .stroke(accent.opacity(0.42), lineWidth: 1.5)
                )
        )
    }

    @ViewBuilder
    private var timerArea: some View {
        if isTimerRunning {
            HStack(spacing: 10) {
                timerBadge
                    .frame(width: 148)
                    .layoutPriority(1)

                Button(action: onToggleTimer) {
                    Image(systemName: "pause.fill")
                        .font(.runeStyle(.subheadline, weight: .black))
                        .frame(width: 44, height: 44)
                        .foregroundStyle(VaultPalette.backgroundBottom)
                }
                .buttonStyle(.plain)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(accent)
                )
            }
            .frame(width: 202, height: 52)
        } else {
            Button(action: onToggleTimer) {
                HStack(spacing: 8) {
                    Image(systemName: "play.fill")
                        .font(.runeStyle(.subheadline, weight: .black))
                    Text(elapsedSeconds > 0 ? "Riprendi timer" : "Avvia timer")
                        .font(.runeStyle(.headline, weight: .black))
                }
                .foregroundStyle(VaultPalette.backgroundBottom)
                .frame(maxWidth: .infinity)
                .frame(height: 52)
            }
            .buttonStyle(.plain)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(accent)
            )
            .frame(width: 202, height: 52)
        }
    }

    private var deckArea: some View {
        Button(action: onSelectDeck) {
            HStack(spacing: 12) {
                Group {
                    if let legend {
                        CardArtView(card: legend, width: 26, height: 36, cornerRadius: 4)
                    } else {
                        RoundedRectangle(cornerRadius: 5, style: .continuous)
                            .fill(Color.black.opacity(0.22))
                            .overlay {
                                Image(systemName: "square.stack.3d.down.right.fill")
                                    .font(.runeStyle(.caption2, weight: .black))
                                    .foregroundStyle(.white.opacity(0.60))
                            }
                    }
                }
                .frame(width: 26, height: 36)

                VStack(alignment: .leading, spacing: 3) {
                    Text(deckName ?? "Seleziona mazzo")
                        .font(.runeStyle(.caption, weight: .black))
                        .foregroundStyle(.white)
                        .lineLimit(1)

                    Text(deckOwner ?? "Tuoi deck e deck amici")
                        .font(.runeStyle(.caption2, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.68))
                        .lineLimit(1)
                }

                Spacer()

                Image(systemName: "chevron.down")
                    .font(.runeStyle(.caption, weight: .black))
                    .foregroundStyle(accent)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.black.opacity(0.18))
            )
        }
        .buttonStyle(.plain)
    }

    private var timerBadge: some View {
        HStack(spacing: 8) {
            Image(systemName: "timer")
                .font(.runeStyle(.subheadline, weight: .bold))
            Text(companionFormattedTime(elapsedSeconds))
                .font(.system(size: 24, weight: .bold, design: .monospaced))
                .monospacedDigit()
                .minimumScaleFactor(0.82)
                .lineLimit(1)
        }
        .foregroundStyle(.white.opacity(0.86))
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.black.opacity(0.18))
        )
    }

    private var scoreScale: some View {
        HStack(spacing: 4) {
            ForEach(0..<11, id: \.self) { index in
                Rectangle()
                    .fill(index <= score ? accent : Color.white.opacity(0.10))
                    .frame(height: 6)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
    }

    private var scoreColor: Color {
        switch outcome {
        case .winner:
            return VaultPalette.success
        case .matchPoint, .extended:
            return accent
        case .neutral:
            return .white
        }
    }

    private func edgeTapZone(symbol: String, disabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 38, weight: .black))
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .buttonStyle(.plain)
        .foregroundStyle(disabled ? .white.opacity(0.32) : .white)
        .contentShape(Rectangle())
        .frame(width: 72)
        .disabled(disabled)
    }
}

private struct CompanionDeckPickerSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var store: RuneShelfStore

    let title: String
    let selectedReference: DeckReference?
    let onClear: () -> Void
    let onSelectLocal: (Deck) -> Void
    let onSelectRemote: (VaultCommunityDeck) -> Void

    var body: some View {
        NavigationStack {
            ZStack {
                VaultBackground()

                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        VaultPanel {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Selezione corrente")
                                        .font(.runeStyle(.headline, weight: .black))
                                        .foregroundStyle(.white)
                                    Text(store.companionDeckName(for: selectedReference) ?? "Nessun mazzo selezionato")
                                        .font(.runeStyle(.subheadline, weight: .semibold))
                                        .foregroundStyle(.white.opacity(0.72))
                                }

                                Spacer()

                                Button("Rimuovi") {
                                    onClear()
                                    dismiss()
                                }
                                .font(.runeStyle(.caption, weight: .black))
                                .foregroundStyle(VaultPalette.highlight)
                            }
                        }

                        VaultPanel {
                            SectionHeader("I tuoi mazzi", eyebrow: "local")

                            LazyVStack(spacing: 10) {
                                ForEach(store.decks) { deck in
                                    CompanionDeckPickerRow(
                                        title: deck.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Nuovo mazzo" : deck.name,
                                        subtitle: deck.visibility.label,
                                        legend: deck.legendCardID.flatMap(store.card(for:)),
                                        isSelected: selectedReference?.source == .local && selectedReference?.deckID == deck.id
                                    ) {
                                        onSelectLocal(deck)
                                        dismiss()
                                    }
                                }
                            }
                        }

                        ForEach(store.companionFriendDeckGroups, id: \.owner.id) { group in
                            VaultPanel {
                                SectionHeader(group.owner.normalizedUsername ?? "Amico", eyebrow: "friend")

                                LazyVStack(spacing: 10) {
                                    ForEach(group.decks) { deck in
                                        CompanionDeckPickerRow(
                                            title: deck.resolvedName,
                                            subtitle: deck.visibility.label,
                                            legend: deck.legendCardID.flatMap(store.card(for:)),
                                            isSelected: selectedReference?.source == .remote && selectedReference?.deckID == deck.id && selectedReference?.ownerUserID == deck.userID
                                        ) {
                                            onSelectRemote(deck)
                                            dismiss()
                                        }
                                    }
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                    .padding(.bottom, 40)
                }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Chiudi") {
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}

private struct CompanionDeckPickerRow: View {
    let title: String
    let subtitle: String
    let legend: RiftCard?
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Group {
                    if let legend {
                        CardArtView(card: legend, width: 42, height: 58, cornerRadius: 5)
                    } else {
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(Color.black.opacity(0.18))
                            .overlay {
                                Image(systemName: "square.stack.3d.down.right.fill")
                                    .font(.runeStyle(.caption, weight: .black))
                                    .foregroundStyle(.white.opacity(0.60))
                            }
                    }
                }
                .frame(width: 42, height: 58)

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.runeStyle(.subheadline, weight: .bold))
                        .foregroundStyle(.white)
                        .lineLimit(2)

                    Text(subtitle)
                        .font(.runeStyle(.caption, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.68))
                }

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.runeStyle(.headline, weight: .black))
                        .foregroundStyle(VaultPalette.highlight)
                }
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(VaultPalette.panel.opacity(isSelected ? 0.92 : 0.72))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(isSelected ? VaultPalette.highlight.opacity(0.45) : Color.white.opacity(0.04), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
    }
}

private func companionFormattedTime(_ elapsedSeconds: Int) -> String {
    let hours = elapsedSeconds / 3600
    let minutes = (elapsedSeconds % 3600) / 60
    let seconds = elapsedSeconds % 60

    if hours > 0 {
        return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
    }

    return String(format: "%02d:%02d", minutes, seconds)
}
