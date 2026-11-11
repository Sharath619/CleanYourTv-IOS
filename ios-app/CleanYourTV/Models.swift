import Foundation

struct TvStatus: Equatable {
    let app: String
    let model: String
    let ip: String
    let port: Int
    let screenWidth: Int
    let screenHeight: Int
    let wallpaperEnabled: Bool
    let hasWallpaper: Bool
    let hasRestWallpaper: Bool
    let restMode: String
    let wallpaperDim: Int
    let ambientGlow: Bool
    let columns: Int
    let rowsBelowDock: Int
    let idleClockMinutes: Int
    let accentColor: String
    let backgroundColor: String
    let revision: Int64

    init?(jsonObject obj: [String: Any]) {
        guard let appName = obj["app"] as? String else { return nil }
        self.app = appName
        self.model = (obj["model"] as? String).flatMap { $0.isEmpty ? nil : $0 } ?? "CleanYourTV"
        self.ip = (obj["ip"] as? String) ?? ""
        self.port = (obj["port"] as? Int) ?? 8765
        let sw = (obj["screenWidth"] as? Int) ?? 1920
        let sh = (obj["screenHeight"] as? Int) ?? 1080
        self.screenWidth = max(1280, sw)
        self.screenHeight = max(720, sh)
        self.wallpaperEnabled = (obj["wallpaperEnabled"] as? Bool) ?? true
        self.hasWallpaper = (obj["hasWallpaper"] as? Bool) ?? false
        self.hasRestWallpaper = (obj["hasRestWallpaper"] as? Bool) ?? false
        self.restMode = (obj["restMode"] as? String) ?? "sharp"
        self.wallpaperDim = (obj["wallpaperDim"] as? Int) ?? 25
        self.ambientGlow = (obj["ambientGlow"] as? Bool) ?? false
        self.columns = (obj["columns"] as? Int) ?? 5
        self.rowsBelowDock = (obj["rowsBelowDock"] as? Int) ?? 0
        self.idleClockMinutes = (obj["homeIdleClockMinutes"] as? Int) ?? 5
        self.accentColor = (obj["accentColor"] as? String) ?? "#C82829"
        self.backgroundColor = (obj["backgroundColor"] as? String) ?? "#0D0E10"
        if let revNum = obj["revision"] as? NSNumber {
            self.revision = revNum.int64Value
        } else {
            self.revision = 0
        }
    }
}

struct DiscoveredTv: Identifiable, Hashable, Sendable {
    var id: String { "\(host):\(port)" }
    let host: String
    let port: Int
    let model: String
}

struct SavedWallpaperItem: Identifiable, Hashable, Decodable, Sendable {
    var id: String { name }
    let name: String
    let size: Int64
    let modified: Int64

    enum CodingKeys: String, CodingKey {
        case name, size, modified
    }

    init(name: String, size: Int64 = 0, modified: Int64 = 0) {
        self.name = name
        self.size = size
        self.modified = modified
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.name = try c.decode(String.self, forKey: .name)
        self.size = (try? c.decodeIfPresent(Int64.self, forKey: .size)) ?? 0
        self.modified = (try? c.decodeIfPresent(Int64.self, forKey: .modified)) ?? 0
    }
}

struct ThemePreset: Identifiable, Hashable, Decodable {
    let id: String
    let title: String
    let category: String
    let asset: String
    let wallpaper: Bool
    let dim: Int
    let ambientGlow: Bool
    let accentColor: String
    let backgroundColor: String

    enum CodingKeys: String, CodingKey {
        case id, title, category, asset, wallpaper, dim, ambientGlow, accentColor, backgroundColor
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try c.decode(String.self, forKey: .id)
        self.title = try c.decode(String.self, forKey: .title)
        self.category = try c.decode(String.self, forKey: .category)
        self.asset = (try? c.decodeIfPresent(String.self, forKey: .asset)) ?? ""
        self.wallpaper = (try? c.decodeIfPresent(Bool.self, forKey: .wallpaper)) ?? true
        self.dim = (try? c.decodeIfPresent(Int.self, forKey: .dim)) ?? 20
        self.ambientGlow = (try? c.decodeIfPresent(Bool.self, forKey: .ambientGlow)) ?? false
        self.accentColor = (try? c.decodeIfPresent(String.self, forKey: .accentColor)) ?? "#C82829"
        self.backgroundColor = (try? c.decodeIfPresent(String.self, forKey: .backgroundColor)) ?? "#0D0E10"
    }
}

struct GradientPreset: Identifiable, Hashable {
    var id: String { name }
    let name: String
    let baseTop: UInt32
    let baseBottom: UInt32
    let glowColor: UInt32

    static let all: [GradientPreset] = [
        GradientPreset(name: "Aurora", baseTop: 0xFF020D0C, baseBottom: 0xFF093A34, glowColor: 0xFF1F8A7B),
        GradientPreset(name: "Indigo", baseTop: 0xFF000000, baseBottom: 0xFF0B0E22, glowColor: 0xFF5B6CFF),
        GradientPreset(name: "Burgundy", baseTop: 0xFF070203, baseBottom: 0xFF280910, glowColor: 0xFFC82829),
        GradientPreset(name: "Emerald", baseTop: 0xFF020A06, baseBottom: 0xFF0B3020, glowColor: 0xFF30D158),
        GradientPreset(name: "Cosmic", baseTop: 0xFF070412, baseBottom: 0xFF241138, glowColor: 0xFF9D50FF),
        GradientPreset(name: "Amber", baseTop: 0xFF0A0602, baseBottom: 0xFF2A1606, glowColor: 0xFFFFB340),
        GradientPreset(name: "Glacier", baseTop: 0xFF040A12, baseBottom: 0xFF0E253D, glowColor: 0xFF64D2FF),
        GradientPreset(name: "Obsidian", baseTop: 0xFF020203, baseBottom: 0xFF16171C, glowColor: 0xFF8C9BFF),
    ]
}

struct RecentEntry: Identifiable, Hashable {
    var id: String { fileURL.path }
    let fileURL: URL
    let label: String
    let modified: Date
}

enum CropTarget: String, CaseIterable, Identifiable {
    case bothSharp = "both_sharp"
    case bothBlur = "both_blur"
    case homeOnly = "home_only"
    case restOnly = "rest_only"

    var id: String { rawValue }

    var shortLabel: String {
        switch self {
        case .bothSharp: return "Home + Rest (Sharp)"
        case .bothBlur: return "Home + Blurred Rest"
        case .homeOnly: return "Home Only"
        case .restOnly: return "Rest Mode Only"
        }
    }
}

struct CropInputItem: Identifiable {
    let id = UUID()
    let data: Data
    let initialTarget: CropTarget
    let columns: Int
}

struct PreviewThemeItem: Identifiable {
    var id: String { preset.id }
    let preset: ThemePreset
}

struct PreviewRecentItem: Identifiable {
    var id: String { entry.id }
    let entry: RecentEntry
}

struct WifiInfoSummary: Equatable, Sendable {
    let wifiConnected: Bool
    let wifiIp: String
    let prefix: String
    let allPrefixes: [String]
}

