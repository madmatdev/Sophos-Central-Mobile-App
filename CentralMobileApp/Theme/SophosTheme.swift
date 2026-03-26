import SwiftUI

// MARK: - Sophos Brand Design System
// Colors sourced from sophos.com brand guidelines
// Primary Blue: #005BC8 (Pantone 300 C)
// Font: Figtree (weights 400 & 600)

enum SophosTheme {

    // MARK: - Colors

    enum Colors {
        // Brand primaries
        static let sophosBlue        = Color(hex: "#005BC8")
        static let sophosBlueBright  = Color(hex: "#1A75FF")
        static let sophosBlueDeep    = Color(hex: "#003D8F")

        // Backgrounds
        static let backgroundPrimary = Color(hex: "#0A1628")
        static let backgroundCard    = Color(hex: "#102040")
        static let backgroundCard2   = Color(hex: "#1A2E4A")
        static let backgroundOverlay = Color(hex: "#0D1E38")

        // Status
        static let statusHealthy     = Color(hex: "#00B341")
        static let statusWarning     = Color(hex: "#FF8C00")
        static let statusCritical    = Color(hex: "#E53935")
        static let statusInfo        = Color(hex: "#2196F3")
        static let statusUnknown     = Color(hex: "#607D8B")

        // Severity
        static let severityHigh      = Color(hex: "#E53935")
        static let severityMedium    = Color(hex: "#FF8C00")
        static let severityLow       = Color(hex: "#FDD835")
        static let severityInfo      = Color(hex: "#42A5F5")

        // Text
        static let textPrimary       = Color(hex: "#FFFFFF")
        static let textSecondary     = Color(hex: "#8BA4BE")
        static let textTertiary      = Color(hex: "#4A6080")
        static let textOnBlue        = Color(hex: "#FFFFFF")

        // UI
        static let divider           = Color(hex: "#1E3A5A")
        static let inputBackground   = Color(hex: "#0D1E38")
        static let inputBorder       = Color(hex: "#1E3A5A")
        static let tabBar            = Color(hex: "#071020")
        static let navigationBar     = Color(hex: "#071020")
        static let badge             = Color(hex: "#E53935")
    }

    // MARK: - Typography

    enum Typography {
        static func largeTitle(_ weight: Font.Weight = .semibold) -> Font {
            .custom("Figtree", size: 34, relativeTo: .largeTitle).weight(weight)
        }
        static func title(_ weight: Font.Weight = .semibold) -> Font {
            .custom("Figtree", size: 28, relativeTo: .title).weight(weight)
        }
        static func title2(_ weight: Font.Weight = .semibold) -> Font {
            .custom("Figtree", size: 22, relativeTo: .title2).weight(weight)
        }
        static func title3(_ weight: Font.Weight = .semibold) -> Font {
            .custom("Figtree", size: 20, relativeTo: .title3).weight(weight)
        }
        static func headline(_ weight: Font.Weight = .semibold) -> Font {
            .custom("Figtree", size: 17, relativeTo: .headline).weight(weight)
        }
        static func body(_ weight: Font.Weight = .regular) -> Font {
            .custom("Figtree", size: 17, relativeTo: .body).weight(weight)
        }
        static func callout(_ weight: Font.Weight = .regular) -> Font {
            .custom("Figtree", size: 16, relativeTo: .callout).weight(weight)
        }
        static func subheadline(_ weight: Font.Weight = .regular) -> Font {
            .custom("Figtree", size: 15, relativeTo: .subheadline).weight(weight)
        }
        static func footnote(_ weight: Font.Weight = .regular) -> Font {
            .custom("Figtree", size: 13, relativeTo: .footnote).weight(weight)
        }
        static func caption(_ weight: Font.Weight = .regular) -> Font {
            .custom("Figtree", size: 12, relativeTo: .caption).weight(weight)
        }
        static func caption2(_ weight: Font.Weight = .regular) -> Font {
            .custom("Figtree", size: 11, relativeTo: .caption2).weight(weight)
        }
    }

    // MARK: - Spacing

    enum Spacing {
        static let xxs: CGFloat  = 4
        static let xs: CGFloat   = 8
        static let sm: CGFloat   = 12
        static let md: CGFloat   = 16
        static let lg: CGFloat   = 24
        static let xl: CGFloat   = 32
        static let xxl: CGFloat  = 48
    }

    // MARK: - Corner Radius

    enum Radius {
        static let sm: CGFloat   = 8
        static let md: CGFloat   = 12
        static let lg: CGFloat   = 16
        static let xl: CGFloat   = 24
        static let pill: CGFloat = 100
    }

    // MARK: - Shadows

    static let cardShadow = ShadowStyle(
        color: Color.black.opacity(0.4),
        radius: 12,
        x: 0,
        y: 4
    )
}

// MARK: - Severity helpers

extension SophosTheme.Colors {
    static func severityColor(_ severity: String) -> Color {
        switch severity.lowercased() {
        case "high":   return severityHigh
        case "medium": return severityMedium
        case "low":    return severityLow
        default:       return severityInfo
        }
    }

    static func healthColor(_ status: String) -> Color {
        switch status.lowercased() {
        case "good":    return statusHealthy
        case "fair", "suspicious": return statusWarning
        case "bad", "compromised": return statusCritical
        default:        return statusUnknown
        }
    }
}

// MARK: - Shadow Style

struct ShadowStyle {
    let color: Color
    let radius: CGFloat
    let x: CGFloat
    let y: CGFloat
}

// MARK: - Color from hex

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3:
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6:
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

// MARK: - View modifiers

struct SophosCardModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(SophosTheme.Colors.backgroundCard)
            .clipShape(RoundedRectangle(cornerRadius: SophosTheme.Radius.md))
            .shadow(
                color: Color.black.opacity(0.4),
                radius: 12, x: 0, y: 4
            )
    }
}

struct SophosSectionHeaderModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(SophosTheme.Typography.caption(.semibold))
            .foregroundColor(SophosTheme.Colors.textSecondary)
            .textCase(.uppercase)
            .tracking(0.8)
    }
}

extension View {
    func sophosCard() -> some View {
        modifier(SophosCardModifier())
    }

    func sophosSectionHeader() -> some View {
        modifier(SophosSectionHeaderModifier())
    }
}

// MARK: - Sophos Logo SVG as SwiftUI shape

struct SophosShieldShape: Shape {
    func path(in rect: CGRect) -> Path {
        // Shield icon from official Sophos SVG
        // Original viewBox: 0 0 24 20 (shield portion only)
        var path = Path()
        let scaleX = rect.width / 24
        let scaleY = rect.height / 20

        func pt(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
            CGPoint(x: x * scaleX + rect.minX, y: y * scaleY + rect.minY)
        }

        // Outer shield
        path.move(to: pt(1.38, 1.34))
        path.addLine(to: pt(1.38, 10.05))
        path.addCurve(to: pt(3.47, 13.60), control1: pt(1.38, 11.52), control2: pt(2.18, 12.88))
        path.addLine(to: pt(12.56, 18.63))
        path.addLine(to: pt(12.62, 18.66))
        path.addLine(to: pt(21.74, 13.60))
        path.addCurve(to: pt(23.84, 10.05), control1: pt(23.04, 12.88), control2: pt(23.84, 11.53))
        path.addLine(to: pt(23.84, 1.34))
        path.closeSubpath()

        // Inner stripe 1
        path.move(to: pt(15.99, 11.65))
        path.addCurve(to: pt(13.79, 12.23), control1: pt(15.32, 12.03), control2: pt(14.56, 12.23))
        path.addLine(to: pt(5.36, 12.20))
        path.addLine(to: pt(10.09, 9.57))
        path.addCurve(to: pt(11.58, 9.18), control1: pt(10.54, 9.32), control2: pt(11.06, 9.18))
        path.addLine(to: pt(20.49, 9.16))
        path.addLine(to: pt(16.00, 11.66))
        path.closeSubpath()

        // Inner stripe 2
        path.move(to: pt(15.87, 7.35))
        path.addCurve(to: pt(14.38, 7.74), control1: pt(15.41, 7.61), control2: pt(14.90, 7.74))
        path.addLine(to: pt(5.46, 7.77))
        path.addLine(to: pt(9.95, 5.27))
        path.addCurve(to: pt(12.17, 4.70), control1: pt(10.63, 4.89), control2: pt(11.39, 4.70))
        path.addLine(to: pt(20.59, 4.72))
        path.addLine(to: pt(15.87, 7.35))
        path.closeSubpath()

        return path
    }
}

struct SophosLogoView: View {
    var height: CGFloat = 32
    var showWordmark: Bool = true

    var body: some View {
        HStack(spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 6)
                    .fill(SophosTheme.Colors.sophosBlue)
                    .frame(width: height * 1.3, height: height)
                SophosShieldShape()
                    .fill(Color.white)
                    .frame(width: height * 1.1, height: height * 0.9)
            }
            if showWordmark {
                Text("SOPHOS")
                    .font(.custom("Figtree", size: height * 0.55))
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .tracking(2)
            }
        }
    }
}
