import SwiftUI

struct ControlsTabView: View {
    @EnvironmentObject private var vm: AppViewModel
    @Environment(\.openURL) private var openURL

    private let dimPresets = [0, 15, 25, 45, 65]
    private let colOptions = [4, 5, 6, 7].map { SegmentTrack<Int>.Option(id: $0, label: "\($0)") }
    private let rowOptions = [0, 1, 2, 3].map { SegmentTrack<Int>.Option(id: $0, label: $0 == 0 ? "None" : "\($0)") }
    private let idleOptions = [0, 1, 2, 5, 15, 30].map { SegmentTrack<Int>.Option(id: $0, label: $0 == 0 ? "Off" : "\($0)m") }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("TV Look")
                        .font(Outfit.light(26))
                        .foregroundColor(Obsidian.textPrimary)
                    Text("Brightness, ambient colors & grid density")
                        .font(Outfit.regular(13))
                        .foregroundColor(Obsidian.textSecondary)
                }

                // Wallpaper & Brightness
                ObsidianCard(radius: 18, padding: 14) {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("WALLPAPER & BRIGHTNESS")
                            .font(Outfit.medium(11))
                            .foregroundColor(Obsidian.textTertiary)
                            .tracking(0.6)

                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Show Wallpaper")
                                    .font(Outfit.medium(14))
                                    .foregroundColor(Obsidian.textPrimary)
                                Text("Turn off for Pure OLED Black home screen")
                                    .font(Outfit.regular(12))
                                    .foregroundColor(Obsidian.textSecondary)
                            }
                            Spacer(minLength: 10)
                            CleanSwitch(isOn: $vm.wallpaperEnabled) { next in
                                vm.pushConfigPatch(["wallpaper": next], refreshPreview: true)
                            }
                        }

                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text("Wallpaper Dim")
                                    .font(Outfit.medium(13.5))
                                    .foregroundColor(Obsidian.textPrimary)
                                Spacer()
                                Text("\(Int(vm.dimPercent.rounded()))%")
                                    .font(Outfit.medium(13.5))
                                    .foregroundColor(Obsidian.accent)
                            }

                            Slider(
                                value: $vm.dimPercent,
                                in: 0...85,
                                step: 1,
                                onEditingChanged: { editing in
                                    if !editing {
                                        vm.pushConfigPatch(["wallpaper_dim": Int(vm.dimPercent.rounded())])
                                    }
                                }
                            )
                            .tint(Obsidian.accent)

                            HStack(spacing: 6) {
                                ForEach(dimPresets, id: \.self) { val in
                                    SelectableChip(
                                        title: "\(val)%",
                                        isSelected: Int(vm.dimPercent.rounded()) == val,
                                        fullWidth: true,
                                        height: 34
                                    ) {
                                        vm.dimPercent = Double(val)
                                        vm.pushConfigPatch(["wallpaper_dim": val])
                                    }
                                }
                            }
                        }
                    }
                }

                // Ambience & Colors
                ObsidianCard(radius: 18, padding: 14) {
                    VStack(alignment: .leading, spacing: 14) {
                        Text("AMBIENCE & COLORS")
                            .font(Outfit.medium(11))
                            .foregroundColor(Obsidian.textTertiary)
                            .tracking(0.6)

                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("App Ambient Glow")
                                    .font(Outfit.medium(14))
                                    .foregroundColor(Obsidian.textPrimary)
                                Text("Subtle glow tinted to focused app")
                                    .font(Outfit.regular(12))
                                    .foregroundColor(Obsidian.textSecondary)
                            }
                            Spacer(minLength: 10)
                            CleanSwitch(isOn: $vm.ambientGlow) { next in
                                vm.pushConfigPatch(["ambient_glow": next])
                            }
                        }

                        VStack(alignment: .leading, spacing: 8) {
                            Text("Background Color")
                                .font(Outfit.medium(13))
                                .foregroundColor(Obsidian.textPrimary)
                            swatchRow(
                                hexes: Obsidian.bgSwatches,
                                selectedHex: vm.status?.backgroundColor ?? "",
                                configKey: "background_color"
                            )
                        }

                        VStack(alignment: .leading, spacing: 8) {
                            Text("Highlight Accent")
                                .font(Outfit.medium(13))
                                .foregroundColor(Obsidian.textPrimary)
                            swatchRow(
                                hexes: Obsidian.accentSwatches,
                                selectedHex: vm.status?.accentColor ?? "",
                                configKey: "accent_color"
                            )
                        }
                    }
                }

                // TV Layout
                ObsidianCard(radius: 18, padding: 14) {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("TV LAYOUT")
                            .font(Outfit.medium(11))
                            .foregroundColor(Obsidian.textTertiary)
                            .tracking(0.6)

                        VStack(alignment: .leading, spacing: 6) {
                            Text("Apps per Row")
                                .font(Outfit.medium(13))
                                .foregroundColor(Obsidian.textPrimary)
                            SegmentTrack(
                                options: colOptions,
                                selected: vm.status?.columns ?? 5
                            ) { c in
                                vm.pushConfigPatch(["columns": c])
                            }
                        }

                        VStack(alignment: .leading, spacing: 6) {
                            Text("Extra Rows Below Dock")
                                .font(Outfit.medium(13))
                                .foregroundColor(Obsidian.textPrimary)
                            SegmentTrack(
                                options: rowOptions,
                                selected: vm.status?.rowsBelowDock ?? 0
                            ) { r in
                                vm.pushConfigPatch(["rows_below_dock": r])
                            }
                        }

                        VStack(alignment: .leading, spacing: 6) {
                            Text("Idle Clock Timeout")
                                .font(Outfit.medium(13))
                                .foregroundColor(Obsidian.textPrimary)
                            SegmentTrack(
                                options: idleOptions,
                                selected: vm.status?.idleClockMinutes ?? 5
                            ) { mins in
                                vm.pushConfigPatch(["home_idle_clock_minutes": mins])
                            }
                        }
                    }
                }

                // Connection & Web Studio
                ObsidianCard(radius: 18, padding: 14) {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("CONNECTION & WEB STUDIO")
                            .font(Outfit.medium(11))
                            .foregroundColor(Obsidian.textTertiary)
                            .tracking(0.6)

                        Button {
                            Haptics.tap()
                            vm.focusIpInConnectSheet = false
                            vm.showConnectSheet = true
                        } label: {
                            settingsActionRow(
                                title: "TV Endpoint & Wi-Fi",
                                subtitle: "\(vm.savedHost):\(vm.savedPort)",
                                badge: "Change"
                            )
                        }
                        .buttonStyle(.plain)

                        Button {
                            Haptics.tap()
                            if let url = URL(string: vm.baseUrl) {
                                openURL(url)
                            }
                        } label: {
                            settingsActionRow(
                                title: "Open Web Studio in Safari",
                                subtitle: vm.baseUrl,
                                badge: "Open ↗"
                            )
                        }
                        .buttonStyle(.plain)

                        Button {
                            Haptics.tap()
                            vm.showOflSheet = true
                        } label: {
                            settingsActionRow(
                                title: "Typography & Open-Source Notice",
                                subtitle: "Outfit Font — SIL OFL 1.1",
                                badge: "View"
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 4)
            .padding(.bottom, 20)
        }
        .scrollIndicators(.hidden)
    }

    private func swatchRow(hexes: [String], selectedHex: String, configKey: String) -> some View {
        HStack(spacing: 0) {
            ForEach(hexes, id: \.self) { hex in
                let isSelected = !selectedHex.isEmpty && selectedHex.caseInsensitiveCompare(hex) == .orderedSame
                Button {
                    Haptics.tap()
                    vm.pushConfigPatch([configKey: hex])
                } label: {
                    Circle()
                        .fill(Color(hexString: hex) ?? .black)
                        .frame(width: 28, height: 28)
                        .overlay(
                            Circle()
                                .stroke(isSelected ? Obsidian.textPrimary : Color.white.opacity(0.22),
                                        lineWidth: isSelected ? 2.5 : 1)
                        )
                        .frame(maxWidth: .infinity)
                        .frame(height: 38)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func settingsActionRow(title: String, subtitle: String, badge: String) -> some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(Outfit.medium(13.5))
                    .foregroundColor(Obsidian.textPrimary)
                Text(subtitle)
                    .font(Outfit.regular(11.5))
                    .foregroundColor(Obsidian.textSecondary)
                    .lineLimit(1)
            }
            Spacer()
            Text(badge)
                .font(Outfit.medium(12))
                .foregroundColor(Obsidian.accent)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(
                    Capsule(style: .continuous)
                        .fill(Obsidian.surface2)
                        .overlay(Capsule(style: .continuous).stroke(Obsidian.outline, lineWidth: 1))
                )
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 13, style: .continuous)
                .fill(Obsidian.surface2)
                .overlay(RoundedRectangle(cornerRadius: 13, style: .continuous).stroke(Obsidian.outlineSubtle, lineWidth: 1))
        )
    }
}
