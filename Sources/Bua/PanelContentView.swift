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
    @Environment(\.colorScheme) private var scheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    static let size = CGSize(width: 240, height: 310)

    var body: some View {
        let palette = Theme.palette(for: scheme)

        VStack(spacing: 10) {
            lotus
                .padding(.top, 18)
            countdown(palette)
            weeklyRow(palette)
            if model.demoMode {
                demoSlider(palette)
            }
            Spacer(minLength: 0)
        }
        .frame(width: Self.size.width, height: Self.size.height)
        .background {
            ZStack {
                VisualEffectBackground()
                palette.panelTint
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

    // MARK: Lotus + breathing

    private var lotus: some View {
        Group {
            if model.panelVisible && !reduceMotion {
                TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { context in
                    lotusBody(breath: sin(context.date.timeIntervalSinceReferenceDate / 8 * 2 * .pi))
                }
            } else {
                lotusBody(breath: 0)
            }
        }
    }

    private func lotusBody(breath: Double) -> some View {
        LotusView(t: model.sessionUtilization, resting: model.isResting, breath: breath)
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
            // Fabricate a countdown proportional to the scrubbed day
            return Self.remainingString((1 - model.sessionUtilization) * 5 * 3600)
        }
        if model.isResting { return "resting" }
        guard let resetsAt = model.sessionResetsAt else { return "·  ·  ·" }
        let remaining = resetsAt.timeIntervalSinceNow
        guard remaining > 0 else { return "in bloom" }
        return Self.remainingString(remaining)
    }

    private var secondaryLine: String {
        if model.demoOverride != nil {
            return String(format: "a day in the life · %.0f%%", model.sessionUtilization * 100)
        }
        if let reason = model.restReason { return reason.caption }
        guard let resetsAt = model.sessionResetsAt else { return "listening for the garden" }
        if resetsAt.timeIntervalSinceNow <= 0 { return "a fresh session has begun" }
        return "session · blooms again " + resetsAt.formatted(date: .omitted, time: .shortened)
    }

    private static func remainingString(_ interval: TimeInterval) -> String {
        let minutes = Int((interval / 60).rounded(.up))
        let h = minutes / 60
        let m = minutes % 60
        return h > 0 ? "\(h)h \(m)m" : "\(m)m"
    }

    // MARK: Weekly bar

    @ViewBuilder
    private func weeklyRow(_ palette: Theme.Palette) -> some View {
        if let weekly = model.weeklyUtilization {
            HStack(spacing: 8) {
                Text("week")
                    .font(.system(size: 11))
                    .foregroundStyle(palette.textSecondary)
                Capsule()
                    .fill(palette.track)
                    .frame(height: 3)
                    .overlay(alignment: .leading) {
                        GeometryReader { geo in
                            Capsule()
                                .fill(palette.textSecondary.opacity(0.85))
                                .frame(width: max(3, geo.size.width * weekly))
                        }
                    }
                Text(String(format: "%.0f%%", weekly * 100))
                    .font(.system(size: 11, design: .rounded))
                    .foregroundStyle(palette.textSecondary)
                    .monospacedDigit()
            }
            .padding(.horizontal, 28)
            .help(model.weeklyDetail)
        }
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

    // MARK: Pin

    private func pinButton(_ palette: Theme.Palette) -> some View {
        Button {
            model.panelPinned.toggle()
        } label: {
            Image(systemName: model.panelPinned ? "leaf.fill" : "leaf")
                .font(.system(size: 12))
                .foregroundStyle(model.panelPinned ? Theme.sage.color : palette.textSecondary)
        }
        .buttonStyle(.plain)
        .padding(12)
        .help(model.panelPinned ? "Unpin — closes when you click away" : "Pin — keep the lotus floating")
    }
}
