import SwiftUI

struct TvConnectSheet: View {
    @EnvironmentObject private var vm: AppViewModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL

    let focusIp: Bool
    let prefound: [DiscoveredTv]

    @State private var ipText: String = ""
    @State private var scanning: Bool = false
    @State private var scanStateMessage: String = "Auto-discover TVs on port 8765"
    @State private var discovered: [DiscoveredTv] = []
    @State private var wifiInfo: WifiInfoSummary = TvClient.inspectWifi()
    @FocusState private var ipFieldFocused: Bool

    var body: some View {
        ZStack {
            Obsidian.bgRoot.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    HStack {
                        Text("Connect to TV")
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

                    // Connection Status & Diagnostics Card
                    ObsidianCard(radius: 16, padding: 14) {
                        VStack(alignment: .leading, spacing: 5) {
                            HStack(spacing: 8) {
                                Circle()
                                    .fill(vm.connected ? Obsidian.statusGreen : Obsidian.statusAmber)
                                    .frame(width: 9, height: 9)
                                Text(statusHeadline)
                                    .font(Outfit.medium(14))
                                    .foregroundColor(Obsidian.textPrimary)
                            }

                            Text(statusDetails)
                                .font(Outfit.regular(12.5))
                                .foregroundColor(Obsidian.textSecondary)

                            Text(wifiDiagnostic)
                                .font(Outfit.regular(11.5))
                                .foregroundColor(wifiInfo.wifiConnected ? Obsidian.textTertiary : Obsidian.statusAmber)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    // Direct IP Input
                    VStack(alignment: .leading, spacing: 6) {
                        Text("TV IP ADDRESS")
                            .font(Outfit.medium(11))
                            .foregroundColor(Obsidian.textTertiary)
                            .tracking(0.6)

                        HStack(spacing: 8) {
                            TextField("192.168.29.51", text: $ipText)
                                .font(Outfit.regular(14.5))
                                .foregroundColor(Obsidian.textPrimary)
                                .keyboardType(.URL)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                                .submitLabel(.go)
                                .focused($ipFieldFocused)
                                .onSubmit { connectTypedIp() }
                                .padding(.horizontal, 14)
                                .frame(height: 46)
                                .background(
                                    RoundedRectangle(cornerRadius: 13, style: .continuous)
                                        .fill(Obsidian.surface2)
                                        .overlay(RoundedRectangle(cornerRadius: 13, style: .continuous).stroke(Obsidian.outline, lineWidth: 1))
                                )

                            Button {
                                Haptics.tap()
                                connectTypedIp()
                            } label: {
                                Text("Connect")
                                    .font(Outfit.medium(13.5))
                                    .foregroundColor(Obsidian.onPrimaryPill)
                                    .padding(.horizontal, 18)
                                    .frame(height: 46)
                                    .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Obsidian.primaryPill))
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    // Scan Wi-Fi Button Card
                    Button {
                        Haptics.tap()
                        runSheetScan()
                    } label: {
                        HStack(spacing: 12) {
                            if scanning {
                                ProgressView()
                                    .tint(Obsidian.accent)
                                    .frame(width: 20, height: 20)
                            } else {
                                Image(systemName: "magnifyingglass")
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(Obsidian.textPrimary)
                                    .frame(width: 20, height: 20)
                            }

                            VStack(alignment: .leading, spacing: 2) {
                                Text("Scan Wi-Fi for CleanYourTV")
                                    .font(Outfit.medium(13.5))
                                    .foregroundColor(Obsidian.textPrimary)
                                Text(scanStateMessage)
                                    .font(Outfit.regular(11.5))
                                    .foregroundColor(Obsidian.textSecondary)
                            }

                            Spacer()

                            Text(scanning ? "Scanning" : "Scan")
                                .font(Outfit.medium(13))
                                .foregroundColor(Obsidian.accent)
                        }
                        .padding(14)
                        .background(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(Obsidian.surface2)
                                .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Obsidian.outline, lineWidth: 1))
                        )
                    }
                    .buttonStyle(.plain)
                    .disabled(scanning)

                    // Live Discovered TVs
                    if !discovered.isEmpty {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("FOUND ON WI-FI — TAP TO CONNECT")
                                .font(Outfit.medium(11))
                                .foregroundColor(Obsidian.accent)
                                .tracking(0.6)

                            ForEach(discovered) { tv in
                                Button {
                                    Haptics.tap()
                                    vm.client.setEndpoint(host: tv.host, port: tv.port)
                                    dismiss()
                                    Task { await vm.connectAndSync(autoScanOnFail: false) }
                                } label: {
                                    HStack {
                                        Text("\(tv.model) · \(tv.host):\(tv.port)")
                                            .font(Outfit.medium(13))
                                            .foregroundColor(Obsidian.textPrimary)
                                        Spacer()
                                        Text("Connect ›")
                                            .font(Outfit.medium(12.5))
                                            .foregroundColor(Obsidian.accent)
                                    }
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 12)
                                    .background(
                                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                                            .fill(Obsidian.surface2)
                                            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(Obsidian.outline, lineWidth: 1))
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }

                    // Footer Quick Actions
                    HStack(spacing: 8) {
                        Button("Retry Saved") {
                            Haptics.tap()
                            dismiss()
                            Task { await vm.connectAndSync(autoScanOnFail: false) }
                        }
                        .buttonStyle(SecondaryPillButton(height: 42))

                        Button("Web Studio ↗") {
                            Haptics.tap()
                            dismiss()
                            if let url = URL(string: vm.baseUrl) {
                                openURL(url)
                            }
                        }
                        .buttonStyle(SecondaryPillButton(height: 42))
                    }

                    Text("Saved endpoint: \(vm.savedHost):\(vm.savedPort)")
                        .font(Outfit.regular(11))
                        .foregroundColor(Obsidian.textTertiary)
                        .frame(maxWidth: .infinity, alignment: .center)
                }
                .padding(20)
            }
            .scrollIndicators(.hidden)
        }
        .preferredColorScheme(.dark)
        .onAppear {
            ipText = vm.savedHost
            wifiInfo = TvClient.inspectWifi()
            discovered = prefound
            if !prefound.isEmpty {
                scanStateMessage = "Found \(prefound.count) TV(s) — tap one below"
            }
            if focusIp {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                    ipFieldFocused = true
                }
            }
        }
    }

    private var statusHeadline: String {
        if vm.connected, let st = vm.status {
            return "\(st.model) · Connected"
        }
        return "TV · Offline"
    }

    private var statusDetails: String {
        if vm.connected, let st = vm.status {
            return "Reachable at \(vm.savedHost):\(vm.savedPort) (\(st.screenWidth)×\(st.screenHeight))"
        }
        if !vm.lastErrorMessage.isEmpty {
            return vm.lastErrorMessage
        }
        return "Turn on your TV and open CleanYourTV home screen, then connect below."
    }

    private var wifiDiagnostic: String {
        if wifiInfo.wifiConnected {
            let ipShow = wifiInfo.wifiIp.isEmpty ? "\(wifiInfo.prefix)*" : wifiInfo.wifiIp
            return "iPhone Wi-Fi IP: \(ipShow)"
        }
        return "Warning: iPhone Wi-Fi appears disconnected (mobile data cannot reach TV)"
    }

    private func connectTypedIp() {
        let parsed = TvClient.parseEndpointInput(ipText, fallbackPort: TvClient.defaultPort)
        guard !parsed.host.isEmpty else {
            vm.showToast("Enter the TV IP address")
            return
        }
        vm.client.setEndpoint(host: parsed.host, port: parsed.port)
        dismiss()
        Task { await vm.connectAndSync(autoScanOnFail: false) }
    }

    private func runSheetScan() {
        scanning = true
        scanStateMessage = "Scanning Wi-Fi subnet & Bonjour..."
        Task {
            let found = await vm.client.discoverTvs()
            let w = TvClient.inspectWifi()
            self.wifiInfo = w
            self.scanning = false
            if found.isEmpty {
                self.scanStateMessage = w.wifiConnected
                    ? "No TV replied on \(w.prefix.isEmpty ? "Wi-Fi" : "\(w.prefix)*") — verify TV IP above"
                    : "iPhone Wi-Fi is off — turn on Wi-Fi first"
                self.discovered = []
            } else if found.count == 1 && prefound.isEmpty {
                let tv = found[0]
                self.scanStateMessage = "Found \(tv.model) at \(tv.host)"
                vm.client.setEndpoint(host: tv.host, port: tv.port)
                vm.showToast("Connected to \(tv.model)")
                dismiss()
                await vm.connectAndSync(autoScanOnFail: false)
            } else {
                self.scanStateMessage = "Found \(found.count) TV(s) — tap one below"
                self.discovered = found
            }
        }
    }
}

