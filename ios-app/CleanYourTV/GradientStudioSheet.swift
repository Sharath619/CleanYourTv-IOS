import SwiftUI

struct GradientStudioSheet: View {
    @EnvironmentObject private var vm: AppViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var selectedPreset: GradientPreset = GradientPreset.all[0]
    @State private var glowPercent: Double = 78
    @State private var vignettePercent: Double = 55
    @State private var topLeftGlow: Bool = true

    var body: some View {
        ZStack {
            Obsidian.bgRoot.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    HStack {
                        Text("Ambient Gradient Studio")
                            .font(Outfit.medium(20))
                            .foregroundColor(Obsidian.textPrimary)
                        Spacer()
                        Button {
                            Haptics.tap()
                            dismiss()
                        } label: {
                            Image(systemName: "xmark")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(Obsidian.textSecondary)
                                .frame(width: 32, height: 32)
                                .background(
                                    Circle()
                                        .fill(Obsidian.surface2)
                                        .overlay(Circle().stroke(Obsidian.outline, lineWidth: 1))
                                )
                        }
                        .buttonStyle(.plain)
                    }

                    // Live 16:9 gradient preview
                    ZStack {
                        Image(uiImage: renderedPreview)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                        TvGuideOverlayView(restMode: false, columns: vm.status?.columns ?? 5)
                    }
                    .aspectRatio(16.0 / 9.0, contentMode: .fit)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(Obsidian.outline, lineWidth: 1)
                    )

                    HStack {
                        Text("MOOD")
                            .font(Outfit.medium(11))
                            .foregroundColor(Obsidian.textTertiary)
                            .tracking(0.6)
                        Spacer()
                        SelectableChip(
                            title: topLeftGlow ? "Glow: Top-Left ⇄" : "Glow: Top-Right ⇄",
                            isSelected: true,
                            height: 30
                        ) {
                            topLeftGlow.toggle()
                        }
                    }

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(GradientPreset.all) { preset in
                                SelectableChip(
                                    title: preset.name,
                                    isSelected: selectedPreset.id == preset.id,
                                    height: 34
                                ) {
                                    selectedPreset = preset
                                }
                            }
                        }
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text("Glow Intensity")
                                .font(Outfit.medium(13))
                                .foregroundColor(Obsidian.textPrimary)
                            Spacer()
                            Text("\(Int(glowPercent))%")
                                .font(Outfit.medium(12.5))
                                .foregroundColor(Obsidian.accent)
                        }
                        Slider(value: $glowPercent, in: 0...100, step: 1)
                            .tint(Obsidian.accent)
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text("Edge Vignette")
                                .font(Outfit.medium(13))
                                .foregroundColor(Obsidian.textPrimary)
                            Spacer()
                            Text("\(Int(vignettePercent))%")
                                .font(Outfit.medium(12.5))
                                .foregroundColor(Obsidian.accent)
                        }
                        Slider(value: $vignettePercent, in: 0...100, step: 1)
                            .tint(Obsidian.accent)
                    }

                    VStack(spacing: 8) {
                        Button("Set on TV (Home + Rest Sharp)") {
                            Haptics.tap()
                            dismiss()
                            vm.applyGradient(
                                preset: selectedPreset,
                                glowStrength: Float(glowPercent / 100.0),
                                vignetteStrength: Float(vignettePercent / 100.0),
                                topLeft: topLeftGlow,
                                restOnly: false
                            )
                        }
                        .buttonStyle(PrimaryPillButton(height: 46))

                        Button("Set Rest Mode Only") {
                            Haptics.tap()
                            dismiss()
                            vm.applyGradient(
                                preset: selectedPreset,
                                glowStrength: Float(glowPercent / 100.0),
                                vignetteStrength: Float(vignettePercent / 100.0),
                                topLeft: topLeftGlow,
                                restOnly: true
                            )
                        }
                        .buttonStyle(SecondaryPillButton(height: 44, textColor: Obsidian.textSecondary))
                    }
                    .padding(.top, 4)
                }
                .padding(20)
            }
            .scrollIndicators(.hidden)
        }
        .preferredColorScheme(.dark)
    }

    private var renderedPreview: UIImage {
        GradientRenderer.render(
            width: 640,
            height: 360,
            preset: selectedPreset,
            glowStrength: Float(glowPercent / 100.0),
            vignetteStrength: Float(vignettePercent / 100.0),
            topLeftGlow: topLeftGlow
        )
    }
}
