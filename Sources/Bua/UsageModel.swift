import Foundation
import Observation

// MARK: - API types (lenient: every field optional, unknown keys ignored)

struct UsageBucket: Decodable {
    let utilization: Double?   // 0–100 percent
    let resetsAt: Date?

    enum CodingKeys: String, CodingKey {
        case utilization
        case resetsAt = "resets_at"
    }
}

struct UsageSnapshot: Decodable {
    let fiveHour: UsageBucket?
    let sevenDay: UsageBucket?
    let sevenDayOpus: UsageBucket?
    let sevenDaySonnet: UsageBucket?

    enum CodingKeys: String, CodingKey {
        case fiveHour = "five_hour"
        case sevenDay = "seven_day"
        case sevenDayOpus = "seven_day_opus"
        case sevenDaySonnet = "seven_day_sonnet"
    }
}

enum UsageFetchError: Error {
    case unauthorized
    case rateLimited
    case badResponse
}

enum UsageFetcher {
    static let endpoint = URL(string: "https://api.anthropic.com/api/oauth/usage")!

    static func fetch(token: String) async throws -> UsageSnapshot {
        var request = URLRequest(url: endpoint, timeoutInterval: 10)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("oauth-2025-04-20", forHTTPHeaderField: "anthropic-beta")
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw UsageFetchError.badResponse }
        if http.statusCode == 401 { throw UsageFetchError.unauthorized }
        if http.statusCode == 429 { throw UsageFetchError.rateLimited }
        guard http.statusCode == 200 else { throw UsageFetchError.badResponse }
        return try makeDecoder().decode(UsageSnapshot.self, from: data)
    }

    /// resets_at arrives as ISO8601 with fractional seconds; tolerate both forms.
    /// Formatters are built per call — ISO8601DateFormatter isn't Sendable.
    static func makeDecoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let s = try decoder.singleValueContainer().decode(String.self)
            let fractional = ISO8601DateFormatter()
            fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            let plain = ISO8601DateFormatter()
            plain.formatOptions = [.withInternetDateTime]
            if let date = fractional.date(from: s) ?? plain.date(from: s) { return date }
            throw DecodingError.dataCorrupted(.init(
                codingPath: decoder.codingPath,
                debugDescription: "Unrecognized date: \(s)"
            ))
        }
        return decoder
    }
}

// MARK: - Model

@MainActor
@Observable
final class UsageModel {

    enum RestReason {
        case noToken
        case tokenExpired
        case offline
        case apiChanged

        var caption: String {
            switch self {
            case .noToken: "no Claude Code credentials found"
            case .tokenExpired: "open Claude Code to wake the garden"
            case .offline: "the garden is out of reach"
            case .apiChanged: "the garden answered strangely"
            }
        }
    }

    enum State {
        case loading
        case blooming(UsageSnapshot)
        case resting(RestReason)
    }

    private(set) var state: State = .loading
    private(set) var lastUpdated: Date?

    var panelVisible = false
    var panelPinned = false

    /// Demo mode: toggled from the right-click menu; the slider scrubs the day.
    var demoMode = false {
        didSet { demoOverride = demoMode ? (liveSessionUtilization ?? 0.3) : nil }
    }
    var demoOverride: Double?   // 0…1

    /// A fresh one is picked each time the panel opens.
    var quote: Quote = Quotes.random()

    /// Called after every state change (status-bar glyph refresh).
    var onUpdate: (() -> Void)?

    private var consecutiveFailures = 0
    private var pollTask: Task<Void, Never>?

    // MARK: Derived values for the UI

    var isBlooming: Bool {
        if case .blooming = state { return true }
        return false
    }

    /// Resting visuals are suppressed while the demo slider is driving.
    var isResting: Bool {
        if case .resting = state { return demoOverride == nil }
        return false
    }

    var restReason: RestReason? {
        if case .resting(let reason) = state { return reason }
        return nil
    }

    var liveSessionUtilization: Double? {
        if case .blooming(let snap) = state, let u = snap.fiveHour?.utilization {
            return min(max(u / 100, 0), 1)
        }
        return nil
    }

    var sessionUtilization: Double {
        demoOverride ?? liveSessionUtilization ?? 0.45
    }

    /// How far in `t` the lotus eases its bloom out so the second half can curve hard.
    /// 1 = linear; higher = the flower lingers open longer. The bars/countdown stay
    /// truthful — only the petals, glyph, and journey-tint read through this curve.
    static let bloomEase = 2.2

    /// Eased closure driving the *visuals* (petals, menu-bar glyph, journey color).
    /// The flower stays open through the first half of the session, then folds
    /// faster toward the end — `sessionUtilization` itself remains the honest number.
    var visualClosure: Double {
        pow(sessionUtilization, Self.bloomEase)
    }

    var sessionResetsAt: Date? {
        if case .blooming(let snap) = state { return snap.fiveHour?.resetsAt }
        return nil
    }

    var weeklyUtilization: Double? {
        if case .blooming(let snap) = state, let u = snap.sevenDay?.utilization {
            return min(max(u / 100, 0), 1)
        }
        return nil
    }

    var weeklyResetsAt: Date? {
        if case .blooming(let snap) = state { return snap.sevenDay?.resetsAt }
        return nil
    }

    var weeklyDetail: String {
        guard case .blooming(let snap) = state else { return "" }
        var parts: [String] = []
        if let u = snap.sevenDay?.utilization { parts.append(String(format: "week %.0f%%", u)) }
        if let u = snap.sevenDayOpus?.utilization { parts.append(String(format: "opus %.0f%%", u)) }
        if let u = snap.sevenDaySonnet?.utilization { parts.append(String(format: "sonnet %.0f%%", u)) }
        if let reset = snap.sevenDay?.resetsAt {
            parts.append("resets " + reset.formatted(date: .abbreviated, time: .shortened))
        }
        return parts.joined(separator: " · ")
    }

    // MARK: Polling

    func startPolling() {
        pollTask?.cancel()
        pollTask = Task { [weak self] in
            while !Task.isCancelled {
                guard let self else { return }
                await self.refresh(force: true)
                try? await Task.sleep(for: .seconds(60))
            }
        }
    }

    /// Snapshot/preview hooks — state is otherwise private(set).
    func previewResting() {
        state = .resting(.tokenExpired)
    }

    func previewBlooming(session: Double, weekly: Double) {
        state = .blooming(UsageSnapshot(
            fiveHour: UsageBucket(
                utilization: session * 100,
                resetsAt: Date().addingTimeInterval(max(0.3, (1 - session) * 5) * 3600)
            ),
            sevenDay: UsageBucket(
                utilization: weekly * 100,
                resetsAt: Date().addingTimeInterval(19 * 3600)
            ),
            sevenDayOpus: nil,
            sevenDaySonnet: UsageBucket(utilization: 3, resetsAt: nil)
        ))
    }

    /// Panel-open refreshes are throttled (the countdown stays correct
    /// without refetching — resets_at is a fixed timestamp); the poll
    /// loop forces. Keeps the endpoint from rate-limiting us when the
    /// panel is opened many times in a row.
    func refresh(force: Bool = false) async {
        if !force, let last = lastUpdated, Date().timeIntervalSince(last) < 45 { return }
        let credentials = await Task.detached { KeychainReader.read() }.value
        guard let credentials else {
            settle(.resting(.noToken))
            return
        }
        guard !credentials.isExpired else {
            settle(.resting(.tokenExpired))
            return
        }
        do {
            let snapshot = try await UsageFetcher.fetch(token: credentials.accessToken)
            settle(.blooming(snapshot))
        } catch UsageFetchError.unauthorized {
            settle(.resting(.tokenExpired))
        } catch UsageFetchError.rateLimited {
            // We asked too often; what we have is still true. Stay calm.
        } catch is DecodingError {
            registerFailure(.apiChanged)
        } catch {
            registerFailure(.offline)
        }
    }

    private func settle(_ newState: State) {
        consecutiveFailures = 0
        state = newState
        lastUpdated = Date()
        onUpdate?()
    }

    /// The countdown stays valid without the network, so a bloom survives
    /// ~8 minutes of failed polls before the lotus rests. Without data to
    /// hold on to, rest after two.
    private func registerFailure(_ reason: RestReason) {
        consecutiveFailures += 1
        let patience = isBlooming ? 8 : 2
        if consecutiveFailures >= patience {
            state = .resting(reason)
            onUpdate?()
        }
    }
}
