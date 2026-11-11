import SwiftUI
import UIKit

enum Obsidian {
    static let bgRoot = Color(hex: 0x000000)
    static let bgTopGlow = Color(hex: 0x0A0A12)
    static let bgNav = Color(hex: 0x08080B)
    static let surface1 = Color(hex: 0x101014)
    static let surface2 = Color(hex: 0x18181E)
    static let surface3 = Color(hex: 0x25252F)

    static let outline = Color.white.opacity(0.12)
    static let outlineSubtle = Color.white.opacity(0.08)
    static let rim = Color.white.opacity(0.24)

    static let textPrimary = Color(hex: 0xF5F5F7)
    static let textSecondary = Color(hex: 0xA1A1A6)
    static let textTertiary = Color(hex: 0x8E8E96)

    static let primaryPill = Color(hex: 0xF5F5F7)
    static let onPrimaryPill = Color(hex: 0x000000)
    static let accent = Color(hex: 0x8C9BFF)

    static let statusGreen = Color(hex: 0x30D158)
    static let statusAmber = Color(hex: 0xFFB340)
    static let statusRed = Color(hex: 0xFF6961)

    static let bgSwatches: [String] = [
        "#000000", "#0D0E10", "#1B090C", "#0D1520", "#071612", "#180B20"
    ]
    static let accentSwatches: [String] = [
        "#8C9BFF", "#C82829", "#30D158", "#FFB340", "#64D2FF", "#FF6482", "#F5F5F7"
    ]
}

enum Outfit {
    static func light(_ size: CGFloat) -> Font {
        Font.custom("Outfit-Light", size: size)
    }

    static func regular(_ size: CGFloat) -> Font {
        Font.custom("Outfit-Regular", size: size)
    }

    static func medium(_ size: CGFloat) -> Font {
        Font.custom("Outfit-Medium", size: size)
    }
}

extension Color {
    init(hex: UInt32, alpha: Double = 1.0) {
        let r = Double((hex >> 16) & 0xFF) / 255.0
        let g = Double((hex >> 8) & 0xFF) / 255.0
        let b = Double(hex & 0xFF) / 255.0
        self.init(.sRGB, red: r, green: g, blue: b, opacity: alpha)
    }

    init?(hexString: String) {
        var cleaned = hexString.trimmingCharacters(in: .whitespacesAndNewlines)
        if cleaned.hasPrefix("#") { cleaned.removeFirst() }
        guard cleaned.count == 6 || cleaned.count == 8, let val = UInt64(cleaned, radix: 16) else {
            return nil
        }
        if cleaned.count == 8 {
            let a = Double((val >> 24) & 0xFF) / 255.0
            let r = Double((val >> 16) & 0xFF) / 255.0
            let g = Double((val >> 8) & 0xFF) / 255.0
            let b = Double(val & 0xFF) / 255.0
            self.init(.sRGB, red: r, green: g, blue: b, opacity: a)
        } else {
            let r = Double((val >> 16) & 0xFF) / 255.0
            let g = Double((val >> 8) & 0xFF) / 255.0
            let b = Double(val & 0xFF) / 255.0
            self.init(.sRGB, red: r, green: g, blue: b, opacity: 1.0)
        }
    }
}

extension UIColor {
    convenience init(hex32: UInt32) {
        let a = CGFloat((hex32 >> 24) & 0xFF) / 255.0
        let r = CGFloat((hex32 >> 16) & 0xFF) / 255.0
        let g = CGFloat((hex32 >> 8) & 0xFF) / 255.0
        let b = CGFloat(hex32 & 0xFF) / 255.0
        self.init(red: r, green: g, blue: b, alpha: a)
    }
}

enum Haptics {
    static func tap() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }
}

struct ObsidianCard<Content: View>: View {
    var radius: CGFloat = 18
    var padding: CGFloat = 14
    var background: Color = Obsidian.surface1
    @ViewBuilder let content: () -> Content

    var body: some View {
        content()
            .padding(padding)
            .background(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .fill(background)
                    .overlay(
                        RoundedRectangle(cornerRadius: radius, style: .continuous)
                            .stroke(Obsidian.outline, lineWidth: 1)
                    )
            )
    }
}

struct PrimaryPillButton: ButtonStyle {
    var height: CGFloat = 46

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Outfit.medium(13.5))
            .foregroundColor(Obsidian.onPrimaryPill)
            .frame(maxWidth: .infinity)
            .frame(height: height)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Obsidian.primaryPill.opacity(configuration.isPressed ? 0.85 : 1.0))
            )
            .scaleEffect(configuration.isPressed ? 0.985 : 1.0)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

struct SecondaryPillButton: ButtonStyle {
    var height: CGFloat = 44
    var textColor: Color = Obsidian.textPrimary

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Outfit.medium(13))
            .foregroundColor(textColor)
            .frame(maxWidth: .infinity)
            .frame(height: height)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(configuration.isPressed ? Obsidian.surface3 : Obsidian.surface2)
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(Obsidian.outline, lineWidth: 1)
                    )
            )
            .scaleEffect(configuration.isPressed ? 0.985 : 1.0)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

struct SelectableChip: View {
    let title: String
    let isSelected: Bool
    var minWidth: CGFloat? = nil
    var fullWidth: Bool = false
    var height: CGFloat = 34
    let action: () -> Void

    var body: some View {
        Button {
            Haptics.tap()
            action()
        } label: {
            Text(title)
                .font(Outfit.medium(12.5))
                .lineLimit(1)
                .foregroundColor(isSelected ? Obsidian.textPrimary : Obsidian.textSecondary)
                .padding(.horizontal, fullWidth ? 4 : 14)
                .frame(minWidth: minWidth, maxWidth: fullWidth ? .infinity : nil)
                .frame(height: height)
                .background(
                    RoundedRectangle(cornerRadius: height / 2.0, style: .continuous)
                        .fill(isSelected ? Obsidian.surface3 : Obsidian.surface2)
                        .overlay(
                            RoundedRectangle(cornerRadius: height / 2.0, style: .continuous)
                                .stroke(isSelected ? Obsidian.rim : Obsidian.outline, lineWidth: 1)
                        )
                )
        }
        .buttonStyle(.plain)
    }
}

struct CleanSwitch: View {
    @Binding var isOn: Bool
    var onToggle: ((Bool) -> Void)? = nil

    var body: some View {
        Button {
            Haptics.tap()
            withAnimation(.easeOut(duration: 0.17)) {
                isOn.toggle()
            }
            onToggle?(isOn)
        } label: {
            ZStack(alignment: isOn ? .trailing : .leading) {
                Capsule(style: .continuous)
                    .fill(isOn ? Obsidian.accent : Obsidian.surface3)
                    .overlay(
                        Capsule(style: .continuous)
                            .stroke(isOn ? Color.white.opacity(0.35) : Obsidian.outline, lineWidth: 1)
                    )
                    .frame(width: 50, height: 28)

                Circle()
                    .fill(Color.white)
                    .shadow(color: .black.opacity(0.35), radius: 2, y: 1)
                    .frame(width: 22, height: 22)
                    .padding(3)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Toggle switch")
        .accessibilityValue(isOn ? "On" : "Off")
    }
}

struct SegmentTrack<Value: Hashable>: View {
    struct Option: Identifiable {
        let id: Value
        let label: String
    }

    let options: [Option]
    let selected: Value
    let onSelect: (Value) -> Void

    var body: some View {
        HStack(spacing: 3) {
            ForEach(options) { opt in
                let active = opt.id == selected
                Button {
                    Haptics.tap()
                    onSelect(opt.id)
                } label: {
                    Text(opt.label)
                        .font(Outfit.medium(12.5))
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                        .foregroundColor(active ? Obsidian.textPrimary : Obsidian.textSecondary)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(active ? Obsidian.surface3 : Color.clear)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                                        .stroke(active ? Obsidian.rim : Color.clear, lineWidth: 1)
                                )
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(3)
        .frame(height: 38)
        .background(
            RoundedRectangle(cornerRadius: 13, style: .continuous)
                .fill(Obsidian.surface2)
                .overlay(
                    RoundedRectangle(cornerRadius: 13, style: .continuous)
                        .stroke(Obsidian.outlineSubtle, lineWidth: 1)
                )
        )
    }
}

