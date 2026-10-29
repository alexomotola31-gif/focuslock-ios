import SwiftUI
import UIKit

enum ThemeMode: String, CaseIterable, Identifiable {
    case system, light, dark
    var id: String { rawValue }
    var title: String { rawValue.capitalized }
    var scheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }
}

enum AccentChoice: String, CaseIterable, Identifiable {
    case gold, violet, blue, green
    var id: String { rawValue }
    var title: String { rawValue.capitalized }
    var color: Color {
        switch self {
        case .gold: return Color(red: 201 / 255, green: 169 / 255, blue: 110 / 255)
        case .violet: return Color(red: 0.55, green: 0.48, blue: 0.95)
        case .blue: return Color(red: 0.30, green: 0.58, blue: 0.98)
        case .green: return Color(red: 0.30, green: 0.80, blue: 0.60)
        }
    }
}

enum TextSizeChoice: String, CaseIterable, Identifiable {
    case small, normal, large
    var id: String { rawValue }
    var title: String { rawValue.capitalized }
    var size: DynamicTypeSize {
        switch self {
        case .small: return .small
        case .normal: return .large
        case .large: return .xxxLarge
        }
    }
}

final class ThemeStore: ObservableObject {
    @Published var mode: ThemeMode { didSet { UserDefaults.standard.set(mode.rawValue, forKey: "fl.mode") } }
    @Published var accentChoice: AccentChoice { didSet { UserDefaults.standard.set(accentChoice.rawValue, forKey: "fl.accent") } }
    @Published var textSize: TextSizeChoice { didSet { UserDefaults.standard.set(textSize.rawValue, forKey: "fl.textSize") } }

    var accent: Color { accentChoice.color }

    init() {
        let d = UserDefaults.standard
        mode = ThemeMode(rawValue: d.string(forKey: "fl.mode") ?? "") ?? .dark
        accentChoice = AccentChoice(rawValue: d.string(forKey: "fl.accent") ?? "") ?? .gold
        textSize = TextSizeChoice(rawValue: d.string(forKey: "fl.textSize") ?? "") ?? .normal
    }

    func reset() {
        mode = .dark
        accentChoice = .gold
        textSize = .normal
    }
}

private func dynamic(_ dark: UIColor, _ light: UIColor) -> Color {
    Color(UIColor { $0.userInterfaceStyle == .dark ? dark : light })
}

extension Color {
    static let flBackground = dynamic(
        UIColor(red: 0.035, green: 0.05, blue: 0.09, alpha: 1),
        UIColor(red: 0.95, green: 0.96, blue: 0.98, alpha: 1))
    static let flCard = dynamic(
        UIColor(red: 0.07, green: 0.09, blue: 0.15, alpha: 1),
        UIColor.white)
    static let flText = dynamic(
        UIColor.white,
        UIColor(red: 0.05, green: 0.08, blue: 0.15, alpha: 1))
    static let flMuted = dynamic(
        UIColor(red: 0.66, green: 0.72, blue: 0.80, alpha: 1),
        UIColor(red: 0.35, green: 0.40, blue: 0.50, alpha: 1))
    static let flInk = Color(red: 0.02, green: 0.03, blue: 0.06)
}

struct FLCard<Content: View>: View {
    private let content: () -> Content
    init(@ViewBuilder content: @escaping () -> Content) { self.content = content }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) { content() }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 18).fill(Color.flCard))
    }
}

struct HeadingStyle: ViewModifier {
    @EnvironmentObject var theme: ThemeStore
    func body(content: Content) -> some View {
        content.font(.system(.headline, design: .serif)).foregroundColor(theme.accent)
    }
}

extension View {
    func flHeading() -> some View { modifier(HeadingStyle()) }
    func flBody() -> some View { font(.footnote).foregroundColor(Color.flMuted) }
}

struct AccentButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        AccentButtonBody(configuration: configuration)
    }
}

private struct AccentButtonBody: View {
    let configuration: ButtonStyleConfiguration
    @EnvironmentObject var theme: ThemeStore
    @Environment(\.isEnabled) private var isEnabled

    var body: some View {
        configuration.label
            .font(.system(.subheadline, design: .serif).bold())
            .foregroundColor(Color.flInk)
            .padding(.horizontal, 18)
            .padding(.vertical, 11)
            .background(Capsule().fill(theme.accent.opacity(configuration.isPressed ? 0.65 : 1.0)))
            .opacity(isEnabled ? 1.0 : 0.4)
    }
}

struct ProgressRing: View {
    var progress: Double
    var title: String
    var subtitle: String
    @EnvironmentObject var theme: ThemeStore

    var body: some View {
        ZStack {
            Circle().stroke(Color.flMuted.opacity(0.25), lineWidth: 10)
            Circle()
                .trim(from: 0, to: CGFloat(min(max(progress, 0), 1)))
                .stroke(theme.accent, style: StrokeStyle(lineWidth: 10, lineCap: .round))
                .rotationEffect(.degrees(-90))
            VStack(spacing: 2) {
                Text(title)
                    .font(.system(.title2, design: .serif).bold())
                    .foregroundColor(Color.flText)
                Text(subtitle).font(.caption2).foregroundColor(Color.flMuted)
            }
        }
        .frame(width: 120, height: 120)
    }
}

func formatClock(_ interval: TimeInterval) -> String {
    let total = max(0, Int(interval))
    return String(format: "%02d:%02d:%02d", total / 3600, (total % 3600) / 60, total % 60)
}

func formatMinutes(_ minutes: Int) -> String {
    if minutes >= 60 {
        let h = minutes / 60, m = minutes % 60
        return m == 0 ? "\(h)h" : "\(h)h \(m)m"
    }
    return "\(minutes)m"
}

func clockString(minuteOfDay: Int) -> String {
    let date = Calendar.current.date(
        bySettingHour: minuteOfDay / 60, minute: minuteOfDay % 60, second: 0, of: Date()
    ) ?? Date()
    return date.formatted(date: .omitted, time: .shortened)
}
