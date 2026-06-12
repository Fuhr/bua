import SwiftUI

/// Wraps NSVisualEffectView for the panel's frosted chrome.
private struct VisualEffectBackground: NSViewRepresentable {
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = .popover
        view.blendingMode = .behindWindow
        view.state = .active
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {}
}

struct PanelContentView: View {
    var model: UsageModel
    /// ImageRenderer can't draw NSVisualEffectView — snapshots use a solid chrome.
    var offscreenChrome = false
    @Environment(\.colorScheme) private var scheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    static let size = CGSize(width: 240, height: 340)

    var body: some View {
        let palette = Theme.palette(for: scheme)

        VStack(spacing: 10) {
            lotus
                .padding(.top, 14)
            countdown(palette)
            VStack(spacing: 7) {
                if model.isBlooming || model.demoOverride != nil {
                    limitRow("session", value: model.sessionUtilization, fill: sessionFill, palette)
                }
                if let weekly = model.weeklyUtilization {
                    limitRow("week", value: weekly, fill: palette.textSecondary.opacity(0.85), palette)
                        .help(model.weeklyDetail)
                }
            }
            if model.demoMode {
                demoSlider(palette)
            }
            Spacer(minLength: 4)
            quoteView(palette)
        }
        .padding(.bottom, 16)
        .frame(width: Self.size.width, height: Self.size.height)
        .background {
            if offscreenChrome {
                (scheme == .dark ? OKLCH(l: 0.16, c: 0.008, h: 80) : OKLCH(l: 0.975, c: 0.008, h: 85)).color
            } else {
                ZStack {
                    VisualEffectBackground()
                    palette.panelTint
                }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .strokeBorder(palette.border, lineWidth: 1)
        }
        .overlay(alignment: .topTrailing) {
            pinButton(palette)
        }
    }

    private var sessionFill: Color {
        (model.isResting ? ColorJourney.resting : ColorJourney.at(model.sessionUtilization))
            .color.opacity(0.9)
    }

    // MARK: Lotus + breathing

    private var lotus: some View {
        Group {
            if model.panelVisible && !reduceMotion {
                TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { context in
                    lotusBody(breathPhase: context.date.timeIntervalSinceReferenceDate / 7 * 2 * .pi)
                }
            } else {
                lotusBody(breathPhase: 0)
            }
        }
    }

    private func lotusBody(breathPhase: Double) -> some View {
        LotusView(t: model.sessionUtilization, resting: model.isResting, breathPhase: breathPhase)
            .animation(.spring(duration: 0.8), value: model.sessionUtilization)
    }

    // MARK: Countdown

    private func countdown(_ palette: Theme.Palette) -> some View {
        TimelineView(.periodic(from: .now, by: 30)) { _ in
            VStack(spacing: 3) {
                Text(primaryLine)
                    .font(.system(size: 22, weight: .medium, design: .rounded))
                    .foregroundStyle(palette.textPrimary)
                Text(secondaryLine)
                    .font(.system(size: 11))
                    .foregroundStyle(palette.textSecondary)
            }
        }
    }

    private var primaryLine: String {
        if model.demoOverride != nil {
            return Self.remainingString((1 - model.sessionUtilization) * 5 * 3600)
        }
        if model.isResting { return "resting" }
        guard let resetsAt = model.sessionResetsAt else { return "·  ·  ·" }
        let remaining = resetsAt.timeIntervalSinceNow
        guard remaining > 0 else { return "in bloom" }
        return Self.remainingString(remaining)
    }

    private var secondaryLine: String {
        if model.demoOverride != nil { return "a day in the life" }
        if let reason = model.restReason { return reason.caption }
        guard let resetsAt = model.sessionResetsAt else { return "listening for the garden" }
        if resetsAt.timeIntervalSinceNow <= 0 { return "a fresh session has begun" }
        return "resets " + resetsAt.formatted(date: .omitted, time: .shortened)
    }

    private static func remainingString(_ interval: TimeInterval) -> String {
        let minutes = Int((interval / 60).rounded(.up))
        let h = minutes / 60
        let m = minutes % 60
        return h > 0 ? "\(h)h \(m)m" : "\(m)m"
    }

    // MARK: Limit bars

    private func limitRow(_ label: String, value: Double, fill: Color, _ palette: Theme.Palette) -> some View {
        HStack(spacing: 8) {
            Text(label)
                .font(.system(size: 11))
                .foregroundStyle(palette.textSecondary)
                .frame(width: 46, alignment: .leading)
            Capsule()
                .fill(palette.track)
                .frame(height: 3)
                .overlay(alignment: .leading) {
                    GeometryReader { geo in
                        Capsule()
                            .fill(fill)
                            .frame(width: max(3, geo.size.width * value))
                    }
                }
            Text(String(format: "%.0f%%", value * 100))
                .font(.system(size: 11, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(palette.textSecondary)
                .frame(width: 34, alignment: .trailing)
        }
        .padding(.horizontal, 24)
    }

    // MARK: Demo slider (⌥ toggles)

    private func demoSlider(_ palette: Theme.Palette) -> some View {
        VStack(spacing: 2) {
            Slider(
                value: Binding(
                    get: { model.demoOverride ?? model.sessionUtilization },
                    set: { model.demoOverride = $0 }
                ),
                in: 0...1
            )
            .controlSize(.mini)
            Text("scrub the day · ⌥ to leave")
                .font(.system(size: 9))
                .foregroundStyle(palette.textSecondary)
        }
        .padding(.horizontal, 28)
    }

    // MARK: Quote

    private func quoteView(_ palette: Theme.Palette) -> some View {
        Text(model.quote)
            .font(.system(size: 11.5))
            .italic()
            .foregroundStyle(palette.textSecondary)
            .multilineTextAlignment(.center)
            .lineLimit(3)
            .minimumScaleFactor(0.9)
            .padding(.horizontal, 26)
    }

    // MARK: Pin

    private func pinButton(_ palette: Theme.Palette) -> some View {
        Button {
            model.panelPinned.toggle()
        } label: {
            Image(systemName: model.panelPinned ? "pin.fill" : "pin")
                .font(.system(size: 11))
                .foregroundStyle(model.panelPinned ? Theme.sage.color : palette.textSecondary)
        }
        .buttonStyle(.plain)
        .padding(12)
        .help(model.panelPinned ? "Unpin — closes when you click away" : "Pin — keep the lotus floating on top")
    }
}
