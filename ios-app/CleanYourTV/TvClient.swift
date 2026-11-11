import Foundation
import Network
import Darwin

enum TvClientError: LocalizedError {
    case message(String)

    var errorDescription: String? {
        switch self {
        case .message(let msg): return msg
        }
    }
}

private final class OnceGate: @unchecked Sendable {
    private let lock = NSLock()
    private var triggered = false

    func tryEnter() -> Bool {
        lock.lock()
        defer { lock.unlock() }
        if triggered { return false }
        triggered = true
        return true
    }
}

private actor DiscoveryAccumulator {
    private var seenHosts = Set<String>()
    private var found: [DiscoveredTv] = []

    func shouldProbe(_ host: String) -> Bool {
        seenHosts.insert(host).inserted
    }

    func appendIfNew(_ tv: DiscoveredTv) {
        if !found.contains(where: { $0.host == tv.host && $0.port == tv.port }) {
            found.append(tv)
        }
    }

    func results() -> [DiscoveredTv] {
        found
    }
}

final class TvClient: @unchecked Sendable {
    static let defaultPort = 8765
    private static let defaultHost = "192.168.29.51"
    private static let keyHost = "tv_host"
    private static let keyPort = "tv_port"

    private let defaults = UserDefaults.standard
    private let session: URLSession
    private let errorLock = NSLock()
    private var _lastError: String = ""

    var lastError: String {
        get {
            errorLock.lock()
            defer { errorLock.unlock() }
            return _lastError
        }
        set {
            errorLock.lock()
            _lastError = newValue
            errorLock.unlock()
        }
    }

    init() {
        let cfg = URLSessionConfiguration.ephemeral
        cfg.waitsForConnectivity = false
        cfg.timeoutIntervalForRequest = 6.0
        cfg.timeoutIntervalForResource = 25.0
        cfg.requestCachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        self.session = URLSession(configuration: cfg)
    }

    var host: String {
        let h = defaults.string(forKey: Self.keyHost) ?? ""
        return h.isEmpty ? Self.defaultHost : h
    }

    var port: Int {
        let p = defaults.integer(forKey: Self.keyPort)
        return p > 0 ? p : Self.defaultPort
    }

    var baseUrl: String {
        "http://\(host):\(port)"
    }

    func setEndpoint(host: String, port: Int) {
        let parsed = Self.parseEndpointInput(host, fallbackPort: port > 0 ? port : Self.defaultPort)
        guard !parsed.host.isEmpty else { return }
        defaults.set(parsed.host, forKey: Self.keyHost)
        defaults.set(parsed.port, forKey: Self.keyPort)
    }

    static func parseEndpointInput(_ raw: String, fallbackPort: Int = defaultPort) -> (host: String, port: Int) {
        var s = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if s.hasPrefix("http://") {
            s = String(s.dropFirst(7))
        } else if s.hasPrefix("https://") {
            s = String(s.dropFirst(8))
        }
        if let slash = s.firstIndex(of: "/") {
            s = String(s[..<slash])
        }
        s = s.trimmingCharacters(in: .whitespacesAndNewlines)
        var port = fallbackPort > 0 ? fallbackPort : defaultPort
        if let colon = s.lastIndex(of: ":"), colon < s.index(before: s.endIndex) {
            let portStr = String(s[s.index(after: colon)...]).trimmingCharacters(in: .whitespacesAndNewlines)
            if let parsed = Int(portStr), parsed > 0, parsed <= 65535 {
                port = parsed
                s = String(s[..<colon]).trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }
        return (s, port)
    }

    static func inspectWifi() -> WifiInfoSummary {
        var ifaddr: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifaddr) == 0, let firstAddr = ifaddr else {
            return WifiInfoSummary(wifiConnected: false, wifiIp: "", prefix: "", allPrefixes: [])
        }
        defer { freeifaddrs(ifaddr) }

        var preferredIps: [String] = []
        var otherLanIps: [String] = []

        var ptr: UnsafeMutablePointer<ifaddrs>? = firstAddr
        while let addr = ptr?.pointee {
            defer { ptr = addr.ifa_next }
            guard let sa = addr.ifa_addr, sa.pointee.sa_family == UInt8(AF_INET) else { continue }
            let flags = Int32(addr.ifa_flags)
            guard (flags & IFF_UP) != 0, (flags & IFF_LOOPBACK) == 0 else { continue }

            let name = String(cString: addr.ifa_name).lowercased()
            if name.hasPrefix("pdp_ip") || name.hasPrefix("utun") || name.hasPrefix("ipsec") || name.hasPrefix("lo") {
                continue
            }

            var hostBuf = [CChar](repeating: 0, count: Int(NI_MAXHOST))
            let len = socklen_t(sa.pointee.sa_len)
            guard getnameinfo(sa, len, &hostBuf, socklen_t(hostBuf.count), nil, 0, NI_NUMERICHOST) == 0 else {
                continue
            }
            let ip = String(cString: hostBuf)
            guard !ip.isEmpty, ip != "0.0.0.0" else { continue }

            if name == "en0" || name.hasPrefix("en") || name.hasPrefix("bridge") {
                preferredIps.append(ip)
            } else {
                otherLanIps.append(ip)
            }
        }

        let allIps = preferredIps + otherLanIps
        let primaryIp = allIps.first ?? ""
        var seen = Set<String>()
        var prefixes: [String] = []
        for ip in allIps {
            let p = ipv4Prefix(ip)
            if !p.isEmpty && seen.insert(p).inserted {
                prefixes.append(p)
            }
        }
        return WifiInfoSummary(
            wifiConnected: !primaryIp.isEmpty,
            wifiIp: primaryIp,
            prefix: prefixes.first ?? "",
            allPrefixes: prefixes
        )
    }

    private static func ipv4Prefix(_ ip: String) -> String {
        guard let lastDot = ip.lastIndex(of: ".") else { return "" }
        return String(ip[...lastDot])
    }

    func fetchStatus() async throws -> TvStatus {
        try await fetchStatus(host: host, port: port, timeout: 3.5)
    }

    func fetchStatus(host: String, port: Int, timeout: TimeInterval = 3.5) async throws -> TvStatus {
        let ep = Self.parseEndpointInput(host, fallbackPort: port)
        guard !ep.host.isEmpty else {
            lastError = "No TV IP address entered"
            throw TvClientError.message(lastError)
        }
        guard let url = URL(string: "http://\(ep.host):\(ep.port)/api/status") else {
            lastError = "Invalid TV address \(ep.host):\(ep.port)"
            throw TvClientError.message(lastError)
        }
        do {
            let data = try await getData(url: url, timeout: timeout)
            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let status = TvStatus(jsonObject: json) else {
                lastError = "Device at \(ep.host):\(ep.port) is not CleanYourTV"
                throw TvClientError.message(lastError)
            }
            lastError = ""
            return status
        } catch {
            lastError = Self.formatConnectError(error, host: ep.host, port: ep.port)
            throw TvClientError.message(lastError)
        }
    }

    static func formatConnectError(_ err: Error, host: String, port: Int) -> String {
        let nsErr = err as NSError
        if nsErr.domain == NSURLErrorDomain {
            switch nsErr.code {
            case NSURLErrorTimedOut:
                return "Timed out reaching \(host):\(port) — check TV Wi-Fi & CleanYourTV"
            case NSURLErrorCannotConnectToHost:
                return "Refused by \(host):\(port) — open CleanYourTV on TV"
            case NSURLErrorNetworkConnectionLost, NSURLErrorCannotFindHost, NSURLErrorNotConnectedToInternet:
                return "Unreachable \(host) — verify iPhone & TV share the same Wi-Fi and Local Network permission is enabled"
            default:
                break
            }
        }
        let desc = err.localizedDescription
        return desc.isEmpty ? "Unable to reach \(host):\(port)" : desc
    }

    func fetchPreviewData(restMode: Bool) async throws -> Data? {
        let path = restMode ? "/api/rest-wallpaper" : "/api/wallpaper"
        guard let url = URL(string: baseUrl + path) else { return nil }
        let (data, resp) = try await rawGet(url: url, timeout: 4.5)
        if resp.statusCode == 404 { return nil }
        guard (200..<300).contains(resp.statusCode) else {
            throw TvClientError.message("HTTP \(resp.statusCode)")
        }
        return data.isEmpty ? nil : data
    }

    func fetchSavedWallpapers() async throws -> [SavedWallpaperItem] {
        guard let url = URL(string: baseUrl + "/api/wallpapers") else { return [] }
        let data = try await getData(url: url, timeout: 4.5)
        return try JSONDecoder().decode([SavedWallpaperItem].self, from: data)
    }

    func fetchSavedThumbnailData(name: String) async throws -> Data {
        let encoded = Self.encodePathSegment(name)
        guard let url = URL(string: baseUrl + "/api/wallpapers/\(encoded)") else {
            throw TvClientError.message("Invalid wallpaper name")
        }
        return try await getData(url: url, timeout: 5.5)
    }

    func uploadHomeWallpaper(
        jpegData: Data,
        saveName: String? = nil,
        restMode: String? = "sharp",
        dimPercent: Int? = nil,
        ambientGlow: Bool? = nil,
        accentColor: String? = nil,
        backgroundColor: String? = nil
    ) async throws {
        var params: [String] = []
        if let saveName, !saveName.isEmpty {
            params.append("saveName=\(Self.encodeQuery(saveName))")
        }
        if let restMode {
            params.append("restMode=\(Self.encodeQuery(restMode))")
        }
        if let dimPercent {
            params.append("dim=\(dimPercent)")
        }
        if let ambientGlow {
            params.append("ambientGlow=\(ambientGlow ? "true" : "false")")
        }
        if let accentColor {
            params.append("accentColor=\(Self.encodeQuery(accentColor))")
        }
        if let backgroundColor {
            params.append("backgroundColor=\(Self.encodeQuery(backgroundColor))")
        }
        let q = params.isEmpty ? "" : "?" + params.joined(separator: "&")
        guard let url = URL(string: baseUrl + "/api/wallpaper" + q) else {
            throw TvClientError.message("Invalid TV URL")
        }
        try await postData(url: url, contentType: "image/jpeg", body: jpegData, timeout: 22.0)
    }

    func uploadRestWallpaper(jpegData: Data) async throws {
        guard let url = URL(string: baseUrl + "/api/rest-wallpaper") else {
            throw TvClientError.message("Invalid TV URL")
        }
        try await postData(url: url, contentType: "image/jpeg", body: jpegData, timeout: 22.0)
    }

    func setRestSharp() async throws {
        guard let url = URL(string: baseUrl + "/api/rest-wallpaper?mode=sharp") else {
            throw TvClientError.message("Invalid TV URL")
        }
        try await postData(url: url, contentType: "application/json", body: Data(), timeout: 8.0)
    }

    func selectSavedWallpaper(name: String, restMode: String = "sharp") async throws {
        let path = "/api/select-wallpaper?name=\(Self.encodeQuery(name))&restMode=\(Self.encodeQuery(restMode))"
        guard let url = URL(string: baseUrl + path) else {
            throw TvClientError.message("Invalid TV URL")
        }
        try await postData(url: url, contentType: "application/json", body: Data(), timeout: 8.0)
    }

    func deleteSavedWallpaper(name: String) async throws {
        let encoded = Self.encodePathSegment(name)
        guard let url = URL(string: baseUrl + "/api/wallpapers/\(encoded)") else {
            throw TvClientError.message("Invalid TV URL")
        }
        var req = URLRequest(url: url)
        req.httpMethod = "DELETE"
        req.timeoutInterval = 4.5
        req.cachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        let (_, resp) = try await session.data(for: req)
        if let http = resp as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            throw TvClientError.message("HTTP \(http.statusCode)")
        }
    }

    func updateConfig(_ patch: [String: Any]) async throws {
        guard let url = URL(string: baseUrl + "/api/config") else {
            throw TvClientError.message("Invalid TV URL")
        }
        let body = try JSONSerialization.data(withJSONObject: patch)
        try await postData(url: url, contentType: "application/json; charset=utf-8", body: body, timeout: 8.0)
    }

    func previewRestOnTv() async throws {
        guard let url = URL(string: baseUrl + "/api/preview-rest") else {
            throw TvClientError.message("Invalid TV URL")
        }
        try await postData(url: url, contentType: "application/json", body: Data(), timeout: 6.0)
    }

    func wakeHomeOnTv() async throws {
        guard let url = URL(string: baseUrl + "/api/wake-home") else {
            throw TvClientError.message("Invalid TV URL")
        }
        try await postData(url: url, contentType: "application/json", body: Data(), timeout: 6.0)
    }

    /// Discovers CleanYourTV launchers on local Wi-Fi using Bonjour (`_cleanyourtv._tcp`) + bounded TCP port 8765 scan.
    func discoverTvs() async -> [DiscoveredTv] {
        let acc = DiscoveryAccumulator()
        let wifi = Self.inspectWifi()
        let savedHost = self.host

        async let bonjourTask: Void = browseBonjour(into: acc, durationSeconds: 2.2)

        var targets: [String] = []
        if !savedHost.isEmpty && savedHost != wifi.wifiIp {
            targets.append(savedHost)
        }
        for prefix in wifi.allPrefixes.prefix(2) {
            for i in 1...254 {
                let candidate = "\(prefix)\(i)"
                if candidate != wifi.wifiIp && !targets.contains(candidate) {
                    targets.append(candidate)
                }
            }
        }

        await withTaskGroup(of: Void.self) { group in
            let maxConcurrency = 48
            var index = 0
            while index < targets.count {
                if index >= maxConcurrency {
                    await group.next()
                }
                let ip = targets[index]
                index += 1
                group.addTask {
                    guard await Self.tcpPortOpen(host: ip, port: Self.defaultPort, timeout: 0.65) else {
                        return
                    }
                    guard await acc.shouldProbe(ip) else { return }
                    if let status = try? await self.fetchStatus(host: ip, port: Self.defaultPort, timeout: 2.0) {
                        await acc.appendIfNew(DiscoveredTv(host: ip, port: Self.defaultPort, model: status.model))
                    }
                }
            }
            for await _ in group {}
        }

        _ = await bonjourTask
        return await acc.results()
    }

    private func browseBonjour(into acc: DiscoveryAccumulator, durationSeconds: TimeInterval) async {
        let queue = DispatchQueue(label: "com.gathin.cleanyourtv.bonjour")
        let browser = NWBrowser(for: .bonjour(type: "_cleanyourtv._tcp", domain: nil), using: .tcp)

        browser.browseResultsChangedHandler = { [weak self] results, _ in
            guard let self else { return }
            for res in results {
                Task {
                    if let ep = await Self.resolveServiceEndpoint(res.endpoint, timeout: 1.5),
                       await acc.shouldProbe(ep.host),
                       let st = try? await self.fetchStatus(host: ep.host, port: ep.port, timeout: 2.0) {
                        await acc.appendIfNew(DiscoveredTv(host: ep.host, port: ep.port, model: st.model))
                    }
                }
            }
        }

        browser.start(queue: queue)
        let ns = UInt64(max(0.5, durationSeconds) * 1_000_000_000)
        try? await Task.sleep(nanoseconds: ns)
        browser.cancel()
    }

    private static func resolveServiceEndpoint(_ endpoint: NWEndpoint, timeout: TimeInterval) async -> (host: String, port: Int)? {
        await withCheckedContinuation { continuation in
            let gate = OnceGate()
            let queue = DispatchQueue(label: "com.gathin.cleanyourtv.resolve")
            let conn = NWConnection(to: endpoint, using: .tcp)

            conn.stateUpdateHandler = { state in
                switch state {
                case .ready:
                    if let remote = conn.currentPath?.remoteEndpoint,
                       case .hostPort(let host, let nwPort) = remote,
                       case .ipv4(let ipv4) = host {
                        let bytes = [UInt8](ipv4.rawValue)
                        if bytes.count == 4 {
                            let ip = "\(bytes[0]).\(bytes[1]).\(bytes[2]).\(bytes[3])"
                            let p = Int(nwPort.rawValue)
                            if gate.tryEnter() {
                                conn.cancel()
                                continuation.resume(returning: (ip, p > 0 ? p : defaultPort))
                            }
                            return
                        }
                    }
                    if gate.tryEnter() {
                        conn.cancel()
                        continuation.resume(returning: nil)
                    }
                case .failed, .cancelled:
                    if gate.tryEnter() {
                        continuation.resume(returning: nil)
                    }
                default:
                    break
                }
            }

            conn.start(queue: queue)
            queue.asyncAfter(deadline: .now() + timeout) {
                if gate.tryEnter() {
                    conn.cancel()
                    continuation.resume(returning: nil)
                }
            }
        }
    }

    private static func tcpPortOpen(host: String, port: Int, timeout: TimeInterval) async -> Bool {
        guard let nwPort = NWEndpoint.Port(rawValue: UInt16(max(1, min(65535, port)))) else {
            return false
        }
        return await withCheckedContinuation { continuation in
            let gate = OnceGate()
            let queue = DispatchQueue.global(qos: .utility)
            let conn = NWConnection(
                host: NWEndpoint.Host(host),
                port: nwPort,
                using: .tcp
            )

            conn.stateUpdateHandler = { state in
                switch state {
                case .ready:
                    if gate.tryEnter() {
                        conn.cancel()
                        continuation.resume(returning: true)
                    }
                case .failed, .cancelled:
                    if gate.tryEnter() {
                        continuation.resume(returning: false)
                    }
                default:
                    break
                }
            }

            conn.start(queue: queue)
            queue.asyncAfter(deadline: .now() + timeout) {
                if gate.tryEnter() {
                    conn.cancel()
                    continuation.resume(returning: false)
                }
            }
        }
    }

    private func rawGet(url: URL, timeout: TimeInterval) async throws -> (Data, HTTPURLResponse) {
        var req = URLRequest(url: url)
        req.httpMethod = "GET"
        req.timeoutInterval = timeout
        req.cachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        let (data, resp) = try await session.data(for: req)
        guard let http = resp as? HTTPURLResponse else {
            throw TvClientError.message("Invalid HTTP response")
        }
        return (data, http)
    }

    private func getData(url: URL, timeout: TimeInterval) async throws -> Data {
        let (data, http) = try await rawGet(url: url, timeout: timeout)
        guard (200..<300).contains(http.statusCode) else {
            if let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let msg = obj["error"] as? String {
                throw TvClientError.message(msg)
            }
            throw TvClientError.message("HTTP \(http.statusCode)")
        }
        return data
    }

    private func postData(url: URL, contentType: String, body: Data, timeout: TimeInterval) async throws {
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.timeoutInterval = timeout
        req.cachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        req.setValue(contentType, forHTTPHeaderField: "Content-Type")
        req.httpBody = body
        let (data, resp) = try await session.data(for: req)
        guard let http = resp as? HTTPURLResponse else {
            throw TvClientError.message("Invalid HTTP response")
        }
        guard (200..<300).contains(http.statusCode) else {
            if let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let msg = obj["error"] as? String {
                throw TvClientError.message(msg)
            }
            throw TvClientError.message("HTTP \(http.statusCode)")
        }
    }

    private static func encodeQuery(_ value: String) -> String {
        var allowed = CharacterSet.urlQueryAllowed
        allowed.remove(charactersIn: "&+=?#")
        return value.addingPercentEncoding(withAllowedCharacters: allowed) ?? value
    }

    private static func encodePathSegment(_ value: String) -> String {
        var allowed = CharacterSet.urlPathAllowed
        allowed.remove(charactersIn: "/")
        return value.addingPercentEncoding(withAllowedCharacters: allowed) ?? value
    }
}
