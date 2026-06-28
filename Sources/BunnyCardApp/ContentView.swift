import SwiftUI
import AppKit

extension Notification.Name {
    static let openBunnyCardSettings = Notification.Name("openBunnyCardSettings")
}

struct PlanResponse: Decodable {
    let summary: PlanSummary
    let rows: [MediaPlanRow]
    let audioRows: [MediaPlanRow]
    let auditDir: String

    enum CodingKeys: String, CodingKey {
        case summary
        case rows
        case audioRows = "audio_rows"
        case auditDir = "audit_dir"
    }
}

struct VolumeResponse: Decodable {
    let volumes: [VolumeCandidate]
}

struct VolumeCandidate: Decodable, Identifiable {
    var id: String { path }
    let path: String
    let name: String
    let cameraScore: Int
    let hasCameraStructure: Bool
    let cameraHints: [String]
    let counts: [String: Int]
    let gibByKind: [String: Double]
    let diskTotalBytes: Int64
    let diskFreeBytes: Int64

    enum CodingKeys: String, CodingKey {
        case path
        case name
        case cameraScore = "camera_score"
        case hasCameraStructure = "has_camera_structure"
        case cameraHints = "camera_hints"
        case counts
        case gibByKind = "gib_by_kind"
        case diskTotalBytes = "disk_total_bytes"
        case diskFreeBytes = "disk_free_bytes"
    }
}

struct ProjectTag: Codable, Identifiable, Equatable {
    var id: UUID = UUID()
    var key: String
    var zh: String
    var en: String

    init(id: UUID = UUID(), key: String, zh: String, en: String) {
        self.id = id
        self.key = key
        self.zh = zh
        self.en = en
    }

    enum CodingKeys: String, CodingKey {
        case id
        case key
        case zh
        case en
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        key = try container.decodeIfPresent(String.self, forKey: .key) ?? ""
        zh = try container.decodeIfPresent(String.self, forKey: .zh) ?? ""
        en = try container.decodeIfPresent(String.self, forKey: .en) ?? key
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(key, forKey: .key)
        try container.encode(zh, forKey: .zh)
        try container.encode(en, forKey: .en)
    }
}

struct ProjectProfile: Codable, Identifiable, Equatable {
    var id: UUID = UUID()
    var name: String
    var tags: [ProjectTag]

    init(id: UUID = UUID(), name: String, tags: [ProjectTag]) {
        self.id = id
        self.name = name
        self.tags = tags
    }

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case tags
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        name = try container.decodeIfPresent(String.self, forKey: .name) ?? "RCJ2026"
        if let tagCards = try? container.decode([ProjectTag].self, forKey: .tags), !tagCards.isEmpty {
            tags = tagCards
        } else if let legacyTags = try? container.decode(String.self, forKey: .tags) {
            tags = projectTagsFromLegacyString(legacyTags)
        } else {
            tags = defaultProjectTags()
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(tags, forKey: .tags)
    }
}

func canonicalTagKey(_ value: String) -> String {
    let lower = value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    let normalized = lower.replacingOccurrences(of: "[^a-z0-9]+", with: "_", options: .regularExpression)
    return normalized.replacingOccurrences(of: "^_+|_+$", with: "", options: .regularExpression)
}

func defaultProjectTagLabel(_ key: String) -> (zh: String, en: String) {
    switch key {
    case "robocup": return ("机器人比赛", "robocup")
    case "robotics": return ("机器人调试", "robotics")
    case "drone_aerial": return ("航拍", "drone_aerial")
    case "graduation": return ("毕业典礼", "graduation")
    case "sports_field": return ("运动场", "sports_field")
    case "campus_daily": return ("校园日常", "campus_daily")
    case "classroom_talk": return ("教室闲谈", "classroom_talk")
    case "city": return ("城市", "city")
    case "event": return ("活动", "event")
    case "people": return ("人物", "people")
    case "travel_hometown": return ("旅途家乡", "travel_hometown")
    case "handheld": return ("手持", "handheld")
    case "material": return ("素材", "material")
    case "photo": return ("照片", "photo")
    default: return (key, key)
    }
}

func makeProjectTag(_ rawKey: String, zh: String? = nil, en: String? = nil) -> ProjectTag {
    let key = canonicalTagKey(rawKey)
    let defaults = defaultProjectTagLabel(key)
    return ProjectTag(key: key, zh: zh?.isEmpty == false ? zh! : defaults.zh, en: en?.isEmpty == false ? en! : defaults.en)
}

func defaultProjectTags() -> [ProjectTag] {
    [
        "robocup",
        "robotics",
        "campus_daily",
        "classroom_talk",
        "sports_field",
        "graduation",
        "event",
        "people",
        "handheld",
        "material",
    ].map { makeProjectTag($0) }
}

func projectTagsFromLegacyString(_ value: String) -> [ProjectTag] {
    let tags = value
        .components(separatedBy: CharacterSet(charactersIn: ",，;；\n"))
        .map { makeProjectTag($0) }
        .filter { !$0.key.isEmpty }
    return tags.isEmpty ? defaultProjectTags() : tags
}

struct StreamPlanEvent: Decodable {
    let event: String
    let index: Int?
    let total: Int?
    let phase: String?
    let row: MediaPlanRow?
    let summary: PlanSummary?
    let rows: [MediaPlanRow]?
    let audioRows: [MediaPlanRow]?
    let auditDir: String?
    let totalFiles: Int?
    let copyCandidates: Int?
    let audioSidecars: Int?
    let skippedFiles: Int?
    let mediaTotal: Int?
    let backupTotal: Int?
    let sidecarTotal: Int?

    enum CodingKeys: String, CodingKey {
        case event
        case index
        case total
        case phase
        case row
        case summary
        case rows
        case audioRows = "audio_rows"
        case auditDir = "audit_dir"
        case totalFiles = "total_files"
        case copyCandidates = "copy_candidates"
        case audioSidecars = "audio_sidecars"
        case skippedFiles = "skipped_files"
        case mediaTotal = "media_total"
        case backupTotal = "backup_total"
        case sidecarTotal = "sidecar_total"
    }
}

struct DiskUsage {
    let total: Int64
    let free: Int64

    var used: Int64 { max(0, total - free) }
    var fraction: Double {
        guard total > 0 else { return 0 }
        return min(1, max(0, Double(used) / Double(total)))
    }
}

func diskUsage(for path: String) -> DiskUsage? {
    guard !path.isEmpty else { return nil }
    var candidate = URL(fileURLWithPath: path).path
    let manager = FileManager.default
    while !manager.fileExists(atPath: candidate) {
        let parent = URL(fileURLWithPath: candidate).deletingLastPathComponent().path
        guard parent != candidate else { return nil }
        candidate = parent
    }
    guard let attrs = try? manager.attributesOfFileSystem(forPath: candidate),
          let total = attrs[.systemSize] as? NSNumber,
          let free = attrs[.systemFreeSize] as? NSNumber else { return nil }
    return DiskUsage(total: total.int64Value, free: free.int64Value)
}

func formatBytes(_ bytes: Int64) -> String {
    let value = Double(bytes)
    let tib = value / 1_099_511_627_776
    if tib >= 1 {
        return String(format: "%.1f TB", tib)
    }
    let gib = value / 1_073_741_824
    return String(format: "%.0f GB", gib)
}

struct OllamaModelResponse: Decodable {
    let available: Bool
    let models: [String]
    let visionModels: [String]
    let error: String

    enum CodingKeys: String, CodingKey {
        case available
        case models
        case visionModels = "vision_models"
        case error
    }
}

struct PlanSummary: Decodable {
    let auditDir: String
    let copiedOrVerified: Int
    let photos: Int
    let videos: Int
    let audioSidecars: Int
    let totalFiles: Int?
    let otherCounts: [String: Int]?
    let otherGib: [String: Double]?
    let backupRoot: String?
    let backupRoots: [String]?
    let backupFiles: Int?

    enum CodingKeys: String, CodingKey {
        case auditDir = "audit_dir"
        case copiedOrVerified = "copied_or_verified"
        case photos
        case videos
        case audioSidecars = "audio_sidecars"
        case totalFiles = "total_files"
        case otherCounts = "other_counts"
        case otherGib = "other_gib"
        case backupRoot = "backup_root"
        case backupRoots = "backup_roots"
        case backupFiles = "backup_files"
    }
}

struct MediaPlanRow: Decodable, Identifiable {
    let id = UUID()
    let sourcePath: String
    let relativePath: String
    let sourceName: String
    let kind: String
    let kindLabel: String
    let targetPath: String
    let targetFolder: String
    let targetName: String
    let sizeGib: Double
    let capturedAt: String?
    let device: String?
    let profile: String?
    let category: String?
    let categoryLabel: String?
    let tag: String?
    let tagLabel: String?
    let classifier: String?
    let description: String?
    let copyStatus: String
    let statusLabel: String
    var thumbnailPath: String?

    enum CodingKeys: String, CodingKey {
        case sourcePath = "source_path"
        case relativePath = "relative_path"
        case sourceName = "source_name"
        case kind
        case kindLabel = "kind_label"
        case targetPath = "target_path"
        case targetFolder = "target_folder"
        case targetName = "target_name"
        case sizeGib = "size_gib"
        case capturedAt = "captured_at"
        case device
        case profile
        case category
        case categoryLabel = "category_label"
        case tag
        case tagLabel = "tag_label"
        case classifier
        case description
        case copyStatus = "copy_status"
        case statusLabel = "status_label"
        case thumbnailPath = "thumbnail_path"
    }
}

enum NameLanguage: String, CaseIterable, Identifiable {
    case zh
    case en

    var id: String { rawValue }
    var title: String {
        switch self {
        case .zh: "中文"
        case .en: "English"
        }
    }
}

enum DirectoryLayout: String, CaseIterable, Identifiable {
    case monthCategory = "month_category"
    case projectTag = "project_tag"

    var id: String { rawValue }
    var title: String {
        switch self {
        case .monthCategory: "月份 / 分类"
        case .projectTag: "项目 / Tag"
        }
    }
}

enum SortField: String, CaseIterable, Identifiable {
    case capturedAt
    case kind
    case category
    case sourceName
    case targetName
    case size

    var id: String { rawValue }
    var title: String {
        switch self {
        case .capturedAt: "拍摄时间"
        case .kind: "类型"
        case .category: "分类"
        case .sourceName: "原文件"
        case .targetName: "新文件名"
        case .size: "大小"
        }
    }
}

enum RunningTaskKind {
    case preview
    case copy
}

enum OllamaDetailMode: String, CaseIterable, Identifiable {
    case concise
    case rich

    var id: String { rawValue }
    var title: String {
        switch self {
        case .concise: "简略"
        case .rich: "丰富"
        }
    }
}

struct ContentView: View {
    @AppStorage("sourcePath") private var sourcePath = "/Volumes/TF256GB_San"
    @AppStorage("videoLibrary") private var videoLibrary = "/Volumes/PS2000/MediaLibrary"
    @AppStorage("photoLibrary") private var photoLibrary = "/Volumes/StudioDisk/lightroom"
    @AppStorage("auditRoot") private var auditRoot = "/Volumes/PS2000/_DuplicateAudit"
    @AppStorage("backupLibrariesData") private var backupLibrariesData = "[\"/Volumes/PS2000/CardBackups\"]"
    @AppStorage("ollamaModel") private var ollamaModel = "llava"
    @AppStorage("ollamaDetailMode") private var ollamaDetailModeRaw = OllamaDetailMode.concise.rawValue
    @State private var ollamaModels: [String] = []
    @State private var ollamaVisionModels: [String] = []
    @AppStorage("useOllama") private var useOllama = false
    @AppStorage("useBackup") private var useBackup = false
    @AppStorage("makeThumbnails") private var makeThumbnails = true
    @AppStorage("deleteSource") private var deleteSource = false
    @AppStorage("deleteSidecars") private var deleteSidecars = true
    @AppStorage("cleanupPreviewCacheOnQuit") private var cleanupPreviewCacheOnQuit = true
    @AppStorage("language") private var languageRaw = NameLanguage.zh.rawValue
    @AppStorage("directoryLayout") private var directoryLayoutRaw = DirectoryLayout.monthCategory.rawValue
    @AppStorage("projectName") private var projectName = "RCJ2026"
    @AppStorage("projectProfilesData") private var projectProfilesData = ""
    @AppStorage("currentProjectID") private var currentProjectID = ""
    @AppStorage("useCustomName") private var useCustomName = false
    @AppStorage("nameTemplate") private var nameTemplate = "{device}_{datetime}_{profile}_{tag}_{kind}"
    @AppStorage("showInspector") private var showInspector = true
    @State private var isRunning = false
    @State private var runningTaskKind: RunningTaskKind?
    @State private var activeProcess: Process?
    @State private var didRequestStop = false
    @State private var showSettings = false
    @State private var sortField: SortField = .capturedAt
    @State private var sortAscending = true
    @State private var previewProgress = 0.0
    @State private var previewTotal = 0
    @State private var previewCurrent = 0
    @State private var resumeBaseCount = 0
    @State private var previewAppendMode = false
    @State private var importMediaTotal = 0
    @State private var importBackupTotal = 0
    @State private var importSidecarTotal = 0
    @State private var autoPreviewToken = UUID()
    @State private var streamLineBuffer = ""
    @State private var installingModel = false
    @State private var modelInstallStatus = ""
    @State private var installingFFmpeg = false
    @State private var ffmpegStatus = ""
    @State private var cacheCleanupStatus = ""
    @State private var volumeCandidates: [VolumeCandidate] = []
    @State private var selectedRowID: MediaPlanRow.ID?
    @State private var planRows: [MediaPlanRow] = []
    @State private var audioRows: [MediaPlanRow] = []
    @State private var summary: PlanSummary?
    @State private var statusMessage = "点击“生成预览”查看每个文件会复制到哪里。"
    @State private var logText = ""
    @State private var showLog = false
    @State private var showDetail = false
    @State private var selectedTagFilter: String?

    private var language: NameLanguage {
        get { NameLanguage(rawValue: languageRaw) ?? .zh }
        nonmutating set { languageRaw = newValue.rawValue }
    }

    private var directoryLayout: DirectoryLayout {
        get { DirectoryLayout(rawValue: directoryLayoutRaw) ?? .monthCategory }
        nonmutating set { directoryLayoutRaw = newValue.rawValue }
    }

    private var ollamaDetailMode: OllamaDetailMode {
        get { OllamaDetailMode(rawValue: ollamaDetailModeRaw) ?? .concise }
        nonmutating set { ollamaDetailModeRaw = newValue.rawValue }
    }

    private var languageBinding: Binding<NameLanguage> {
        Binding(get: { language }, set: { language = $0 })
    }

    private var directoryLayoutBinding: Binding<DirectoryLayout> {
        Binding(get: { directoryLayout }, set: { directoryLayout = $0 })
    }

    private var ollamaDetailBinding: Binding<OllamaDetailMode> {
        Binding(get: { ollamaDetailMode }, set: { ollamaDetailMode = $0 })
    }

    private var backupLibraries: [String] {
        get {
            guard let data = backupLibrariesData.data(using: .utf8),
                  let decoded = try? JSONDecoder().decode([String].self, from: data),
                  !decoded.isEmpty else { return ["/Volumes/PS2000/CardBackups"] }
            return decoded
        }
        nonmutating set {
            let cleaned = newValue.isEmpty ? [""] : newValue
            if let data = try? JSONEncoder().encode(cleaned),
               let text = String(data: data, encoding: .utf8) {
                backupLibrariesData = text
            }
        }
    }

    private var activeBackupLibraries: [String] {
        guard useBackup else { return [] }
        return backupLibraries
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    private var projectProfiles: [ProjectProfile] {
        get {
            if let data = projectProfilesData.data(using: .utf8),
               let decoded = try? JSONDecoder().decode([ProjectProfile].self, from: data),
               !decoded.isEmpty {
                return decoded
            }
            return [ProjectProfile(name: projectName.isEmpty ? "RCJ2026" : projectName, tags: defaultProjectTags())]
        }
        nonmutating set {
            let cleaned = newValue.isEmpty ? [ProjectProfile(name: "RCJ2026", tags: defaultProjectTags())] : newValue
            if let data = try? JSONEncoder().encode(cleaned),
               let text = String(data: data, encoding: .utf8) {
                projectProfilesData = text
                if !cleaned.contains(where: { $0.id.uuidString == currentProjectID }) {
                    currentProjectID = cleaned.first?.id.uuidString ?? ""
                }
            }
        }
    }

    private var selectedProject: ProjectProfile {
        projectProfiles.first { $0.id.uuidString == currentProjectID } ?? projectProfiles.first ?? ProjectProfile(name: "RCJ2026", tags: defaultProjectTags())
    }

    private var selectedProjectName: String {
        selectedProject.name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var selectedProjectTags: String {
        guard let data = try? JSONEncoder().encode(selectedProject.tags),
              let text = String(data: data, encoding: .utf8) else {
            return selectedProject.tags.map(\.key).joined(separator: ",")
        }
        return text
    }

    private var hasSelectedVisionModel: Bool {
        !ollamaModel.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && (ollamaVisionModels.contains(ollamaModel) || looksLikeVisionModel(ollamaModel))
    }

    private var backupEditorPaths: [Int] {
        Array(backupLibraries.indices)
    }

    private let enginePath = "/Users/davinci/Documents/GitHub/BunnyCard/src/bunnycard_core.py"

    private var selectedRow: MediaPlanRow? {
        allRows.first { $0.id == selectedRowID }
    }

    private var allRows: [MediaPlanRow] {
        planRows + audioRows
    }

    private var filteredRows: [MediaPlanRow] {
        guard let selectedTagFilter else { return allRows }
        return allRows.filter { tagDisplay($0) == selectedTagFilter }
    }

    private var sortedRows: [MediaPlanRow] {
        filteredRows.sorted { lhs, rhs in
            let result: ComparisonResult
            switch sortField {
            case .capturedAt:
                result = (lhs.capturedAt ?? "").localizedStandardCompare(rhs.capturedAt ?? "")
            case .kind:
                result = lhs.kindLabel.localizedStandardCompare(rhs.kindLabel)
            case .category:
                result = (lhs.categoryLabel ?? lhs.kindLabel).localizedStandardCompare(rhs.categoryLabel ?? rhs.kindLabel)
            case .sourceName:
                result = lhs.sourceName.localizedStandardCompare(rhs.sourceName)
            case .targetName:
                result = lhs.targetName.localizedStandardCompare(rhs.targetName)
            case .size:
                if lhs.sizeGib == rhs.sizeGib {
                    result = .orderedSame
                } else {
                    result = lhs.sizeGib < rhs.sizeGib ? .orderedAscending : .orderedDescending
                }
            }
            return sortAscending ? result == .orderedAscending : result == .orderedDescending
        }
    }

    var body: some View {
        HSplitView {
            sidebar
                .frame(minWidth: 300, idealWidth: 340, maxWidth: 390)
                .frame(maxHeight: .infinity, alignment: .top)
            HSplitView {
                mainPanel
                    .frame(minWidth: 680, minHeight: 680)
                    .frame(maxHeight: .infinity, alignment: .top)
                if showInspector {
                    inspectorPanel
                        .frame(minWidth: 280, idealWidth: 320, maxWidth: 420)
                        .frame(maxHeight: .infinity, alignment: .top)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Color(nsColor: .windowBackgroundColor))
        .confirmationDialog("确认开始复制？", isPresented: .constant(false)) {}
        .onChange(of: selectedRowID) { _ in
            ensureSelectedThumbnail()
        }
        .onChange(of: sourcePath) { _ in
            scheduleAutoPreview()
        }
        .onAppear {
            ensureCurrentProject()
            refreshVolumes()
            refreshOllamaModels()
            refreshFFmpegStatus()
            scheduleAutoPreview()
        }
        .onReceive(NotificationCenter.default.publisher(for: .openBunnyCardSettings)) { _ in
            showSettings = true
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.willTerminateNotification)) { _ in
            if cleanupPreviewCacheOnQuit {
                cleanupPreviewCache()
            }
        }
        .sheet(isPresented: $showSettings) {
            settingsSheet
                .frame(width: 560, height: 620)
        }
        .sheet(isPresented: $showLog) {
            logPanel
                .frame(width: 860, height: 520)
                .padding(16)
        }
    }

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 12) {
                appIcon
                    .frame(width: 56, height: 56)
                VStack(alignment: .leading, spacing: 3) {
                    Text("BunnyCard")
                        .font(.system(size: 26, weight: .bold))
                    Text("本地素材入库")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            Divider()

            VStack(alignment: .leading, spacing: 10) {
                Text("目标位置")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                FinderSidebarRow(title: "视频素材库", systemImage: "film.stack", path: videoLibrary, isSelected: true) {
                    chooseFolder($videoLibrary)
                }
                FinderSidebarRow(title: "照片图库", systemImage: "photo.stack", path: photoLibrary) {
                    chooseFolder($photoLibrary)
                }
                ForEach(Array(activeBackupLibraries.enumerated()), id: \.offset) { index, path in
                    FinderSidebarRow(title: "原样备份 \(index + 1)", systemImage: "externaldrive.badge.checkmark", path: path) {
                        chooseBackupFolder(index)
                    }
                }
            }

            Button {
                showSettings = true
            } label: {
                Label("设置", systemImage: "slider.horizontal.3")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)

            Divider()

            VStack(alignment: .leading, spacing: 8) {
                safetyLine(icon: "checkmark.shield", text: "先预览，不写入素材库")
                safetyLine(icon: "number", text: "复制后逐个 SHA-256 校验")
                safetyLine(icon: "doc.text.magnifyingglass", text: "审计日志保存在目标盘")
            }
            .font(.footnote)
            .foregroundStyle(.secondary)

            Spacer()
        }
        .padding(22)
        .frame(maxHeight: .infinity, alignment: .top)
    }

    private var settingsSheet: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                Text("设置")
                    .font(.title2.weight(.semibold))
                Spacer()
                Button("完成") {
                    showSettings = false
                }
                .keyboardShortcut(.defaultAction)
            }
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    GroupBox("路径") {
                        VStack(alignment: .leading, spacing: 12) {
                            pathField("源卡 / 硬盘", path: $sourcePath)
                            pathField("视频素材库", path: $videoLibrary)
                            pathField("照片图库", path: $photoLibrary)
                            pathField("审计日志目录", path: $auditRoot)
                            Toggle("同时原样备份到第二位置", isOn: $useBackup)
                                .toggleStyle(.checkbox)
                            backupListEditor
                                .disabled(!useBackup)
                        }
                        .padding(8)
                    }

                    GroupBox("命名与预览") {
                        VStack(alignment: .leading, spacing: 12) {
                            Picker("命名语言", selection: languageBinding) {
                                ForEach(NameLanguage.allCases) { item in
                                    Text(item.title).tag(item)
                                }
                            }
                            .pickerStyle(.segmented)
                            Toggle("自定义命名格式", isOn: $useCustomName)
                                .toggleStyle(.checkbox)
                            HStack {
                                Image(systemName: "curlybraces")
                                    .foregroundStyle(.secondary)
                                TextField("{device}_{datetime}_{profile}_{tag}_{kind}", text: $nameTemplate)
                                    .textFieldStyle(.roundedBorder)
                                    .disabled(!useCustomName)
                            }
                            Text("可用字段：{device} {date} {time} {datetime} {profile} {tag} {kind} {original}")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Toggle("生成缩略图预览", isOn: $makeThumbnails)
                                .toggleStyle(.checkbox)
                        }
                        .padding(8)
                    }

                    GroupBox("项目与 Tag 收录") {
                        projectListEditor
                            .padding(8)
                    }

                    GroupBox("AI 识别") {
                        VStack(alignment: .leading, spacing: 12) {
                            Toggle("使用本地 Ollama 识别画面", isOn: $useOllama)
                                .toggleStyle(.checkbox)
                            if !hasSelectedVisionModel {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("未检测到可用视觉模型；当前模型可能会导致 404。")
                                        .font(.caption)
                                        .foregroundStyle(.orange)
                                    HStack {
                                        Button {
                                            installOllamaModel("llava:latest")
                                        } label: {
                                            Label(installingModel ? "安装中..." : "一键安装 llava", systemImage: "arrow.down.circle")
                                        }
                                        .disabled(installingModel)
                                        if !modelInstallStatus.isEmpty {
                                            Text(modelInstallStatus)
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                                .lineLimit(1)
                                        }
                                    }
                                }
                            }
                            HStack {
                                Text("模型")
                                    .foregroundStyle(.secondary)
                                if ollamaModels.isEmpty {
                                    TextField("llava", text: $ollamaModel)
                                        .textFieldStyle(.roundedBorder)
                                } else {
                                    Picker("模型", selection: $ollamaModel) {
                                        ForEach(ollamaModels, id: \.self) { model in
                                            Text(model).tag(model)
                                        }
                                    }
                                }
                            }
                            .disabled(!useOllama)
                            Picker("输出", selection: ollamaDetailBinding) {
                                ForEach(OllamaDetailMode.allCases) { mode in
                                    Text(mode.title).tag(mode)
                                }
                            }
                            .pickerStyle(.segmented)
                            .disabled(!useOllama)
                        }
                        .padding(8)
                    }

                    GroupBox("依赖") {
                        VStack(alignment: .leading, spacing: 10) {
                            HStack {
                                Label(ffmpegStatus.isEmpty ? "FFmpeg 检测中" : ffmpegStatus, systemImage: ffmpegStatus.contains("已检测") ? "checkmark.circle" : "exclamationmark.triangle")
                                Spacer()
                                Button {
                                    installFFmpeg()
                                } label: {
                                    Label(installingFFmpeg ? "安装中..." : "安装 ffmpeg", systemImage: "arrow.down.circle")
                                }
                                .disabled(installingFFmpeg || ffmpegStatus.contains("已检测"))
                            }
                            Text("ffmpeg 用于视频缩略图和抽帧识别。BunnyCard 不内置 ffmpeg；若缺失，预览会继续，但视频缩略图和本地视觉识别会降级。")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding(8)
                    }

                    GroupBox("清理") {
                        VStack(alignment: .leading, spacing: 12) {
                            Toggle("复制完成后删除 LRF/XML", isOn: $deleteSidecars)
                            Toggle("校验后删除源素材", isOn: $deleteSource)
                            Divider()
                            Toggle("退出 BunnyCard 时清理预览缓存", isOn: $cleanupPreviewCacheOnQuit)
                            HStack {
                                Button {
                                    cleanupPreviewCache()
                                } label: {
                                    Label("立即清理预览缓存", systemImage: "trash")
                                }
                                if !cacheCleanupStatus.isEmpty {
                                    Text(cacheCleanupStatus)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(1)
                                }
                            }
                            Text("缓存位置：审计目录下的 bunnycard_plan_*/thumbs 和 frames。不会删除素材、CSV 或 JSON 审计文件。")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .toggleStyle(.checkbox)
                        .padding(8)
                    }
                }
            }
        }
        .padding(22)
    }

    private var mainPanel: some View {
        VStack(alignment: .leading, spacing: 9) {
            sourceDeck
            layoutDeck
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text(runningTaskKind == .copy ? "复制任务" : "导入预览")
                        .font(.title2.weight(.semibold))
                    VStack(alignment: .leading, spacing: 4) {
                        Text(statusMessage)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                        if isRunning || previewTotal > 0 {
                            HStack(spacing: 8) {
                                ProgressView(value: previewProgress)
                                    .frame(width: 180)
                                Text(previewTotal > 0 ? "\(previewCurrent)/\(previewTotal)" : "扫描中")
                                    .font(.caption.monospacedDigit())
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
                Spacer()
                previewControls
                Button {
                    confirmAndRunImport()
                } label: {
                    Label("开始复制", systemImage: "square.and.arrow.down")
                }
                .buttonStyle(.borderedProminent)
                .disabled(runningTaskKind != nil || planRows.isEmpty)
                if runningTaskKind == .copy {
                    Button(role: .destructive) {
                        cancelCurrentTask()
                    } label: {
                        Label("取消复制", systemImage: "xmark.circle")
                    }
                }
            }

            summaryStrip
            tagStrip

            HStack {
                Text("文件列表")
                    .font(.headline)
                Spacer()
                Picker("排序", selection: $sortField) {
                    ForEach(SortField.allCases) { field in
                        Text(field.title).tag(field)
                    }
                }
                .frame(width: 140)
                Button {
                    sortAscending.toggle()
                } label: {
                    Image(systemName: sortAscending ? "arrow.up" : "arrow.down")
                }
                .help(sortAscending ? "升序" : "降序")
                if !logText.isEmpty {
                    Button {
                        showLog = true
                    } label: {
                        Image(systemName: "terminal")
                    }
                    .help("显示日志")
                }
                Button {
                    showInspector.toggle()
                } label: {
                    Image(systemName: showInspector ? "sidebar.right" : "sidebar.left")
                }
                .help(showInspector ? "收起检查器" : "打开检查器")
            }

            Table(sortedRows, selection: $selectedRowID) {
                TableColumn("分类") { row in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(row.categoryLabel ?? row.kindLabel)
                            .lineLimit(1)
                        Text(row.kindLabel)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
                .width(95)

                TableColumn("原文件") { row in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(row.sourceName)
                            .lineLimit(1)
                            .truncationMode(.middle)
                        Text(row.relativePath)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                }
                .width(min: 190, ideal: 260)

                TableColumn("去向") { row in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(row.targetName)
                            .lineLimit(1)
                            .truncationMode(.middle)
                        Text(shortFolder(row.targetFolder))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                }
                .width(min: 260, ideal: 430)

                TableColumn("大小") { row in
                    Text(String(format: "%.3f GiB", row.sizeGib))
                        .monospacedDigit()
                }
                .width(82)
            }
            .frame(minHeight: 320)
            .frame(maxHeight: .infinity)
        }
        .padding(22)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var sourceDeck: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label("选择来源", systemImage: "externaldrive")
                    .font(.headline)
                Spacer()
                Button {
                    refreshVolumes()
                } label: {
                    Label("刷新", systemImage: "arrow.clockwise")
                }
                .buttonStyle(.borderless)
            }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(volumeCandidates) { volume in
                        VolumeCard(volume: volume, isSelected: sourcePath == volume.path) {
                            sourcePath = volume.path
                        }
                    }
                    Button {
                        chooseFolder($sourcePath)
                    } label: {
                        VStack(spacing: 8) {
                            Image(systemName: "folder.badge.plus")
                                .font(.title2)
                            Text("其他位置")
                                .font(.subheadline.weight(.medium))
                        }
                        .frame(width: 140, height: 104)
                    }
                    .buttonStyle(.plain)
                    .background(Color(nsColor: .controlBackgroundColor))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                .padding(.vertical, 2)
            }
        }
    }

    private var layoutDeck: some View {
            HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 8) {
                Text("落位方式")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Picker("落位方式", selection: directoryLayoutBinding) {
                    ForEach(DirectoryLayout.allCases) { item in
                        Text(item.title).tag(item)
                    }
                }
                .pickerStyle(.segmented)
                Text(directoryLayout == .projectTag ? "目标：项目 / tag / 月份 / 文件" : "目标：月份 / 分类 / 文件")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: 330)

            VStack(alignment: .leading, spacing: 8) {
                Text("项目")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                HStack {
                    Picker("项目", selection: $currentProjectID) {
                        ForEach(projectProfiles) { project in
                            Text(project.name.isEmpty ? "未命名项目" : project.name).tag(project.id.uuidString)
                        }
                    }
                    .frame(maxWidth: 190)
                    Button {
                        showSettings = true
                    } label: {
                        Image(systemName: "list.bullet.rectangle")
                    }
                    .help("编辑项目和 tag 收录")
                }
                Text(directoryLayout == .projectTag ? "目标：\(selectedProjectName) / tag / 月份" : "用于 AI tag 收录和项目/tag 模式。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: 240)

            Spacer()
        }
        .padding(10)
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private var summaryStrip: some View {
        HStack(spacing: 10) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    StatBox(title: "视频", value: "\(planRows.filter { $0.kind == "video" }.count)")
                    StatBox(title: "照片", value: "\(planRows.filter { $0.kind == "photo" }.count)")
                    StatBox(title: "音频", value: "\(audioRows.count)")
                    StatBox(title: "计划", value: "\(planRows.count)")
                    StatBox(title: "总数", value: "\(summary?.totalFiles ?? allRows.count)")
                    if let sidecarCount = summary?.otherCounts?["delete_sidecar"] {
                        StatBox(title: "LRF/XML", value: "\(sidecarCount)")
                    }
                    if let backupFiles = summary?.backupFiles {
                        StatBox(title: "备份", value: "\(backupFiles)")
                    }
                }
            }
            if !logText.isEmpty {
                Button {
                    showLog = true
                } label: {
                    Image(systemName: "terminal")
                }
                .help("显示日志")
            }
        }
    }

    private var previewControls: some View {
        HStack(spacing: 8) {
            Button {
                runPlan(restart: true)
            } label: {
                Label("重新开始", systemImage: "arrow.clockwise")
            }
            .disabled(runningTaskKind != nil)

            Button(role: .destructive) {
                stopCurrentTask()
            } label: {
                Label("暂停", systemImage: "pause.circle")
            }
            .disabled(runningTaskKind != .preview)

            Button {
                runPlan(restart: false)
            } label: {
                Label("继续", systemImage: "play.circle")
            }
            .disabled(runningTaskKind != nil || allRows.isEmpty)
        }
    }

    private var inspectorPanel: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("检查器")
                    .font(.headline)
                Spacer()
                if !logText.isEmpty {
                    Button {
                        showLog = true
                    } label: {
                        Image(systemName: "terminal")
                    }
                    .help("显示日志")
                }
                Button {
                    showInspector = false
                } label: {
                    Image(systemName: "sidebar.right")
                }
                .help("收起检查器")
            }
            if let row = selectedRow {
                thumbnailView(row)
                    .aspectRatio(16 / 9, contentMode: .fit)
                    .frame(maxWidth: .infinity)
                Text(row.targetName)
                    .font(.title3.weight(.semibold))
                    .lineLimit(2)
                    .truncationMode(.middle)
                Text("\(row.kindLabel) - \(String(format: "%.2f GiB", row.sizeGib))")
                    .foregroundStyle(.secondary)
                Divider()
                inspectorLine("分类", row.categoryLabel ?? row.kindLabel)
                inspectorLine("Tag", row.tag ?? "-")
                if let description = row.description, !description.isEmpty {
                    inspectorLine("描述", description)
                }
                inspectorLine("设备", row.device ?? "-")
                if let profile = row.profile, !profile.isEmpty {
                    inspectorLine("色彩", profile)
                }
                Divider()
                inspectorPath("来源", row.sourcePath)
                inspectorPath("目标", row.targetPath)
            } else {
                Spacer()
                VStack(spacing: 10) {
                    Image(systemName: "photo.on.rectangle")
                        .font(.system(size: 34))
                        .foregroundStyle(.secondary)
                    Text("选中一行查看缩略图和去向")
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                Spacer()
            }
        }
        .padding(18)
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.55))
        .frame(maxHeight: .infinity, alignment: .top)
    }

    private func inspectorLine(_ title: String, _ value: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value.isEmpty ? "-" : value)
                .multilineTextAlignment(.trailing)
                .lineLimit(2)
        }
        .font(.subheadline)
    }

    private func inspectorPath(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(value.isEmpty ? "-" : value)
                .font(.system(.caption, design: .monospaced))
                .lineLimit(2)
                .truncationMode(.middle)
                .textSelection(.enabled)
        }
    }

    private var tagStrip: some View {
        let tagCounts = Dictionary(grouping: allRows, by: { tagDisplay($0) })
            .mapValues { $0.count }
            .sorted { $0.value > $1.value }
        return ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                if let selectedTagFilter {
                    Button {
                        self.selectedTagFilter = nil
                    } label: {
                        TagChip(label: "全部", count: allRows.count, isSelected: false)
                    }
                    .buttonStyle(.plain)
                    Text("过滤：\(selectedTagFilter)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                ForEach(tagCounts.prefix(16), id: \.key) { item in
                    Button {
                        let newFilter = selectedTagFilter == item.key ? nil : item.key
                        selectedTagFilter = newFilter
                        let nextRows = newFilter == nil ? allRows : allRows.filter { tagDisplay($0) == newFilter }
                        selectedRowID = nextRows.first?.id
                    } label: {
                        TagChip(label: item.key, count: item.value, isSelected: selectedTagFilter == item.key)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .frame(height: tagCounts.isEmpty ? 0 : 34)
    }

    private var detailPanel: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
            if let row = selectedRow {
                Text("选中文件去向")
                    .font(.headline)
                HStack(alignment: .top, spacing: 14) {
                    thumbnailView(row)
                        .frame(width: 180, height: 108)
                    Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 8) {
                        detailRow("来源", row.sourcePath)
                        detailRow("目标文件夹", row.targetFolder)
                        detailRow("目标文件名", row.targetName)
                        detailRow("完整目标", row.targetPath)
                        detailRow("识别", "\(row.categoryLabel ?? "") / \(row.tagLabel ?? "") / \(row.classifier ?? "")")
                        detailRow("设备", row.device ?? "-")
                        if let backupRoots = summary?.backupRoots, !backupRoots.isEmpty {
                            detailRow("原样备份", backupRoots.map { $0 + "/" + row.relativePath }.joined(separator: "  |  "))
                        } else if let backupRoot = summary?.backupRoot, !backupRoot.isEmpty {
                            detailRow("原样备份", backupRoot + "/" + row.relativePath)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            } else {
                Text("未选中文件")
                    .foregroundStyle(.secondary)
            }

        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        }
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private var logPanel: some View {
        ScrollView {
            Text(logText)
                .font(.system(.caption, design: .monospaced))
                .frame(maxWidth: .infinity, alignment: .leading)
                .textSelection(.enabled)
                .padding(10)
        }
        .background(Color(nsColor: .textBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private var appIcon: some View {
        Group {
            if let url = Bundle.module.url(forResource: "bunnyCard", withExtension: "png"),
               let image = NSImage(contentsOf: url) {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFit()
            } else {
                Image(systemName: "externaldrive.badge.checkmark")
                    .font(.system(size: 42))
            }
        }
    }

    private func thumbnailView(_ row: MediaPlanRow) -> some View {
        ZStack {
            Color(nsColor: .textBackgroundColor)
            if let thumbnailPath = row.thumbnailPath,
               !thumbnailPath.isEmpty,
               let image = NSImage(contentsOfFile: thumbnailPath) {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFill()
                    .clipped()
            } else {
                VStack(spacing: 8) {
                    Image(systemName: row.kind == "video" ? "film" : "photo")
                        .font(.system(size: 30))
                    Text("无预览")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color(nsColor: .separatorColor), lineWidth: 1)
        )
    }

    private func pathField(_ title: String, path: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            HStack {
                TextField(title, text: path)
                    .textFieldStyle(.roundedBorder)
                Button {
                    chooseFolder(path)
                } label: {
                    Image(systemName: "folder")
                }
                .help("选择文件夹")
            }
        }
    }

    private var backupListEditor: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("原样备份目录")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                Button {
                    var paths = backupLibraries
                    paths.append("")
                    backupLibraries = paths
                } label: {
                    Image(systemName: "plus")
                }
                .help("添加备份目标")
            }
            ForEach(backupLibraries.indices, id: \.self) { index in
                HStack {
                    TextField("备份目录 \(index + 1)", text: backupLibraryBinding(index))
                        .textFieldStyle(.roundedBorder)
                    Button {
                        chooseBackupFolder(index)
                    } label: {
                        Image(systemName: "folder")
                    }
                    .help("选择文件夹")
                    Button {
                        removeBackupLibrary(at: index)
                    } label: {
                        Image(systemName: "minus.circle")
                    }
                    .disabled(backupLibraries.count <= 1)
                    .help("移除这个备份目标")
                }
            }
        }
    }

    private var projectListEditor: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("项目列表")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                Button {
                    var projects = projectProfiles
                    let newProject = ProjectProfile(name: "NewProject", tags: defaultProjectTags())
                    projects.append(newProject)
                    projectProfiles = projects
                    currentProjectID = newProject.id.uuidString
                } label: {
                    Image(systemName: "plus")
                }
                .help("添加项目")
            }

            ForEach(projectProfiles.indices, id: \.self) { index in
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Button {
                            currentProjectID = projectProfiles[index].id.uuidString
                        } label: {
                            Image(systemName: currentProjectID == projectProfiles[index].id.uuidString ? "checkmark.circle.fill" : "circle")
                        }
                        .buttonStyle(.plain)
                        .help("设为当前项目")
                        TextField("项目名", text: projectNameBinding(index))
                            .textFieldStyle(.roundedBorder)
                        Button {
                            removeProject(at: index)
                        } label: {
                            Image(systemName: "minus.circle")
                        }
                        .disabled(projectProfiles.count <= 1)
                        .help("移除项目")
                    }
                    projectTagCards(projectIndex: index)
                }
                .padding(8)
                .background(currentProjectID == projectProfiles[index].id.uuidString ? Color.accentColor.opacity(0.10) : Color(nsColor: .controlBackgroundColor).opacity(0.45))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
    }

    private func projectTagCards(projectIndex: Int) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Tag 收录")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                Button {
                    addProjectTag(to: projectIndex)
                } label: {
                    Label("添加 Tag", systemImage: "plus")
                }
                .controlSize(.small)
            }
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 180), spacing: 8)], alignment: .leading, spacing: 8) {
                ForEach(projectProfiles[projectIndex].tags.indices, id: \.self) { tagIndex in
                    ProjectTagCard(
                        key: projectTagKeyBinding(projectIndex, tagIndex),
                        zh: projectTagZHBinding(projectIndex, tagIndex),
                        en: projectTagENBinding(projectIndex, tagIndex)
                    ) {
                        removeProjectTag(projectIndex: projectIndex, tagIndex: tagIndex)
                    }
                }
            }
            Text("key 给模型和目录使用；中文 / English 用于显示和命名。key 保持英文 snake_case。")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(2)
        }
    }

    private func safetyLine(icon: String, text: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .frame(width: 16)
            Text(text)
        }
    }

    private func detailRow(_ title: String, _ value: String) -> some View {
        GridRow {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            ScrollView(.horizontal, showsIndicators: false) {
                Text(value.isEmpty ? "-" : value)
                    .font(.system(.body, design: .monospaced))
                    .textSelection(.enabled)
                    .lineLimit(1)
            }
        }
    }

    private func shortFolder(_ path: String) -> String {
        let components = path.split(separator: "/").map(String.init)
        guard components.count > 4 else { return path }
        return "..." + components.suffix(4).joined(separator: "/")
    }

    private func tagDisplay(_ row: MediaPlanRow) -> String {
        let value = row.tag ?? row.tagLabel ?? row.categoryLabel ?? row.kindLabel
        return value.isEmpty ? row.kindLabel : value
    }

    private func appendUnique(_ rows: [MediaPlanRow]) {
        var existing = Set(allRows.map(\.sourcePath))
        for row in rows where !existing.contains(row.sourcePath) {
            existing.insert(row.sourcePath)
            if row.kind == "audio_sidecar" {
                audioRows.append(row)
            } else {
                planRows.append(row)
            }
        }
    }

    private func looksLikeVisionModel(_ model: String) -> Bool {
        let lower = model.lowercased()
        return lower.contains("llava")
            || lower.contains("vision")
            || lower.contains("moondream")
            || lower.contains("minicpm-v")
            || lower.contains("bakllava")
    }

    private func chooseFolder(_ path: Binding<String>) {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        if panel.runModal() == .OK, let url = panel.url {
            path.wrappedValue = url.path
        }
    }

    private func chooseBackupFolder(_ index: Int) {
        guard backupLibraries.indices.contains(index) else { return }
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        if panel.runModal() == .OK, let url = panel.url {
            var paths = backupLibraries
            paths[index] = url.path
            backupLibraries = paths
        }
    }

    private func removeBackupLibrary(at index: Int) {
        guard backupLibraries.indices.contains(index), backupLibraries.count > 1 else { return }
        var paths = backupLibraries
        paths.remove(at: index)
        backupLibraries = paths
    }

    private func backupLibraryBinding(_ index: Int) -> Binding<String> {
        Binding(
            get: {
                guard backupLibraries.indices.contains(index) else { return "" }
                return backupLibraries[index]
            },
            set: { newValue in
                var paths = backupLibraries
                guard paths.indices.contains(index) else { return }
                paths[index] = newValue
                backupLibraries = paths
            }
        )
    }

    private func projectNameBinding(_ index: Int) -> Binding<String> {
        Binding(
            get: {
                guard projectProfiles.indices.contains(index) else { return "" }
                return projectProfiles[index].name
            },
            set: { newValue in
                var projects = projectProfiles
                guard projects.indices.contains(index) else { return }
                projects[index].name = newValue
                projectProfiles = projects
                if projects[index].id.uuidString == currentProjectID {
                    projectName = newValue
                }
            }
        )
    }

    private func projectTagKeyBinding(_ projectIndex: Int, _ tagIndex: Int) -> Binding<String> {
        Binding(
            get: {
                guard projectProfiles.indices.contains(projectIndex),
                      projectProfiles[projectIndex].tags.indices.contains(tagIndex) else { return "" }
                return projectProfiles[projectIndex].tags[tagIndex].key
            },
            set: { newValue in
                var projects = projectProfiles
                guard projects.indices.contains(projectIndex),
                      projects[projectIndex].tags.indices.contains(tagIndex) else { return }
                projects[projectIndex].tags[tagIndex].key = canonicalTagKey(newValue)
                projectProfiles = projects
            }
        )
    }

    private func projectTagZHBinding(_ projectIndex: Int, _ tagIndex: Int) -> Binding<String> {
        Binding(
            get: {
                guard projectProfiles.indices.contains(projectIndex),
                      projectProfiles[projectIndex].tags.indices.contains(tagIndex) else { return "" }
                return projectProfiles[projectIndex].tags[tagIndex].zh
            },
            set: { newValue in
                var projects = projectProfiles
                guard projects.indices.contains(projectIndex),
                      projects[projectIndex].tags.indices.contains(tagIndex) else { return }
                projects[projectIndex].tags[tagIndex].zh = newValue
                projectProfiles = projects
            }
        )
    }

    private func projectTagENBinding(_ projectIndex: Int, _ tagIndex: Int) -> Binding<String> {
        Binding(
            get: {
                guard projectProfiles.indices.contains(projectIndex),
                      projectProfiles[projectIndex].tags.indices.contains(tagIndex) else { return "" }
                return projectProfiles[projectIndex].tags[tagIndex].en
            },
            set: { newValue in
                var projects = projectProfiles
                guard projects.indices.contains(projectIndex),
                      projects[projectIndex].tags.indices.contains(tagIndex) else { return }
                projects[projectIndex].tags[tagIndex].en = newValue
                projectProfiles = projects
            }
        )
    }

    private func addProjectTag(to projectIndex: Int) {
        var projects = projectProfiles
        guard projects.indices.contains(projectIndex) else { return }
        projects[projectIndex].tags.append(makeProjectTag("new_tag", zh: "新标签", en: "new_tag"))
        projectProfiles = projects
    }

    private func removeProjectTag(projectIndex: Int, tagIndex: Int) {
        var projects = projectProfiles
        guard projects.indices.contains(projectIndex),
              projects[projectIndex].tags.indices.contains(tagIndex) else { return }
        projects[projectIndex].tags.remove(at: tagIndex)
        projectProfiles = projects
    }

    private func removeProject(at index: Int) {
        guard projectProfiles.indices.contains(index), projectProfiles.count > 1 else { return }
        var projects = projectProfiles
        let removedID = projects[index].id.uuidString
        projects.remove(at: index)
        projectProfiles = projects
        if currentProjectID == removedID {
            currentProjectID = projects.first?.id.uuidString ?? ""
        }
    }

    private func ensureCurrentProject() {
        if projectProfilesData.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            let initial = ProjectProfile(name: projectName.isEmpty ? "RCJ2026" : projectName, tags: defaultProjectTags())
            projectProfiles = [initial]
            currentProjectID = initial.id.uuidString
            projectName = initial.name
            return
        }
        var projects = projectProfiles
        if projects.isEmpty {
            projects = [ProjectProfile(name: projectName.isEmpty ? "RCJ2026" : projectName, tags: defaultProjectTags())]
            projectProfiles = projects
        }
        if !projects.contains(where: { $0.id.uuidString == currentProjectID }) {
            currentProjectID = projects.first?.id.uuidString ?? ""
        }
        if projectName.isEmpty {
            projectName = selectedProjectName
        }
    }

    private func makeResumeSkipFile() -> String? {
        guard !allRows.isEmpty else { return nil }
        let lines = allRows.compactMap { row -> String? in
            let payload: [String: String] = [
                "source_path": row.sourcePath,
                "target_path": row.targetPath,
                "kind": row.kind
            ]
            guard let data = try? JSONSerialization.data(withJSONObject: payload),
                  let text = String(data: data, encoding: .utf8) else { return nil }
            return text
        }
        guard !lines.isEmpty else { return nil }
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("bunnycard_resume_\(UUID().uuidString).txt")
        do {
            try lines.joined(separator: "\n").write(to: url, atomically: true, encoding: .utf8)
            return url.path
        } catch {
            logText += "\n无法创建断点列表：\(error.localizedDescription)"
            return nil
        }
    }

    private func cleanupPreviewCache() {
        let root = URL(fileURLWithPath: auditRoot)
        let manager = FileManager.default
        var removed = 0
        guard let entries = try? manager.contentsOfDirectory(
            at: root,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else {
            cacheCleanupStatus = "未找到审计目录"
            return
        }
        for planDir in entries where planDir.lastPathComponent.hasPrefix("bunnycard_plan_") {
            for child in ["thumbs", "frames"] {
                let cacheDir = planDir.appendingPathComponent(child)
                if manager.fileExists(atPath: cacheDir.path) {
                    do {
                        try manager.removeItem(at: cacheDir)
                        removed += 1
                    } catch {
                        logText += "\n清理失败：\(cacheDir.path) \(error.localizedDescription)"
                    }
                }
            }
        }
        cacheCleanupStatus = removed > 0 ? "已清理 \(removed) 个缓存目录" : "没有可清理缓存"
    }

    private func runPlan(restart: Bool = true) {
        var args = [
            "plan-card",
            "--source", sourcePath,
            "--video-library", videoLibrary,
            "--photo-library", photoLibrary,
            "--audit-root", auditRoot,
            "--language", language.rawValue,
            "--layout", directoryLayout.rawValue,
            "--project", selectedProjectName,
            "--project-tags", selectedProjectTags,
            "--stream"
        ]
        if useCustomName && !nameTemplate.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            args.append("--name-template")
            args.append(nameTemplate)
        }
        if useBackup {
            for backupLibrary in activeBackupLibraries {
            args.append("--backup-library")
                args.append(backupLibrary)
            }
        }
        if !restart, let skipList = makeResumeSkipFile() {
            args.append("--skip-source-list")
            args.append(skipList)
        }
        if makeThumbnails {
            args.append("--thumbnails")
            args.append("--thumbnail-limit")
            args.append("48")
        }
        if useOllama {
            args.append("--use-ollama")
            args.append("--ollama-model")
            args.append(ollamaModel)
            args.append("--ollama-detail")
            args.append(ollamaDetailMode.rawValue)
        }
        resumeBaseCount = restart ? 0 : allRows.count
        runEngine(args, parsePlan: true, taskKind: .preview, resetPlan: restart)
    }

    private func confirmAndRunImport() {
        let alert = NSAlert()
        alert.messageText = "开始复制这批素材？"
        alert.informativeText = deleteSource
            ? "会复制并校验素材，校验通过后删除源素材。这个选项风险较高。"
            : "会复制并校验素材。源素材会保留在卡上。"
        alert.alertStyle = deleteSource ? .warning : .informational
        alert.addButton(withTitle: "开始复制")
        alert.addButton(withTitle: "取消")
        guard alert.runModal() == .alertFirstButtonReturn else { return }
        runImport()
    }

    private func runImport() {
        var args = [
            "import-card",
            "--source", sourcePath,
            "--video-library", videoLibrary,
            "--photo-library", photoLibrary,
            "--audit-root", auditRoot,
            "--language", language.rawValue,
            "--layout", directoryLayout.rawValue,
            "--project", selectedProjectName,
            "--project-tags", selectedProjectTags,
            "--stream"
        ]
        if useCustomName && !nameTemplate.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            args.append("--name-template")
            args.append(nameTemplate)
        }
        if useBackup {
            for backupLibrary in activeBackupLibraries {
                args.append("--backup-library")
                args.append(backupLibrary)
            }
        }
        if useOllama {
            args.append("--use-ollama")
            args.append("--ollama-model")
            args.append(ollamaModel)
            args.append("--ollama-detail")
            args.append(ollamaDetailMode.rawValue)
        }
        if deleteSidecars { args.append("--delete-sidecars") }
        if deleteSource { args.append("--delete-source") }
        runEngine(args, parsePlan: false, taskKind: .copy)
    }

    private func runEngine(_ args: [String], parsePlan: Bool, taskKind: RunningTaskKind, resetPlan: Bool = true) {
        if isRunning {
            stopCurrentTask()
        }
        isRunning = true
        runningTaskKind = taskKind
        didRequestStop = false
        previewAppendMode = parsePlan && !resetPlan
        statusMessage = parsePlan ? (resetPlan ? "正在生成预览..." : "正在继续生成剩余预览...") : "正在复制并校验..."
        logText = "$ python3 \(enginePath) \(args.joined(separator: " "))\n\n"
        streamLineBuffer = ""
        if parsePlan && resetPlan {
            planRows = []
            audioRows = []
            summary = nil
            selectedRowID = nil
            selectedTagFilter = nil
            previewProgress = 0
            previewCurrent = 0
            previewTotal = 0
            resumeBaseCount = 0
        } else if parsePlan {
            previewCurrent = resumeBaseCount
            previewTotal = max(previewTotal, resumeBaseCount)
            previewProgress = previewTotal > 0 ? min(1, Double(previewCurrent) / Double(previewTotal)) : 0
        } else if taskKind == .copy {
            previewProgress = 0
            previewCurrent = 0
            previewTotal = 0
            importMediaTotal = 0
            importBackupTotal = 0
            importSidecarTotal = 0
        }

        DispatchQueue.global(qos: .userInitiated).async {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/python3")
            process.arguments = [enginePath] + args
            let stdout = Pipe()
            let stderr = Pipe()
            process.standardOutput = stdout
            process.standardError = stderr

            var stdoutData = Data()
            stdout.fileHandleForReading.readabilityHandler = { handle in
                let data = handle.availableData
                guard !data.isEmpty else { return }
                if (parsePlan || taskKind == .copy), let text = String(data: data, encoding: .utf8) {
                    DispatchQueue.main.async {
                        handleStreamChunk(text)
                    }
                } else {
                    stdoutData.append(data)
                }
            }
            stderr.fileHandleForReading.readabilityHandler = { handle in
                let data = handle.availableData
                guard !data.isEmpty, let text = String(data: data, encoding: .utf8) else { return }
                DispatchQueue.main.async {
                    logText += text
                }
            }

            do {
                try process.run()
                DispatchQueue.main.async {
                    activeProcess = process
                }
                process.waitUntilExit()
                stdout.fileHandleForReading.readabilityHandler = nil
                stderr.fileHandleForReading.readabilityHandler = nil
                let output = String(data: stdoutData, encoding: .utf8) ?? ""
                DispatchQueue.main.async {
                    activeProcess = nil
                    if parsePlan || taskKind == .copy {
                        handleStreamCompletion(exitCode: process.terminationStatus)
                    } else {
                        handleEngineResult(output: output, exitCode: process.terminationStatus, parsePlan: parsePlan)
                    }
                }
            } catch {
                DispatchQueue.main.async {
                    activeProcess = nil
                    statusMessage = "运行失败：\(error.localizedDescription)"
                    logText += "Failed to run engine: \(error.localizedDescription)"
                    isRunning = false
                    runningTaskKind = nil
                }
            }
        }
    }

    private func stopCurrentTask() {
        didRequestStop = true
        statusMessage = runningTaskKind == .copy ? "正在取消复制..." : "正在暂停预览..."
        activeProcess?.terminate()
    }

    private func cancelCurrentTask() {
        stopCurrentTask()
    }

    private func scheduleAutoPreview() {
        let token = UUID()
        autoPreviewToken = token
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
            guard autoPreviewToken == token,
                  !sourcePath.isEmpty,
                  !isRunning else { return }
            runPlan(restart: true)
        }
    }

    private func refreshVolumes() {
        DispatchQueue.global(qos: .utility).async {
            let output = runEngineForJSON(["volumes", "--camera-only"])
            guard let data = output.data(using: .utf8),
                  let decoded = try? JSONDecoder().decode(VolumeResponse.self, from: data) else { return }
            DispatchQueue.main.async {
                volumeCandidates = decoded.volumes
                if sourcePath.isEmpty, let first = decoded.volumes.first {
                    sourcePath = first.path
                }
            }
        }
    }

    private func refreshOllamaModels() {
        DispatchQueue.global(qos: .utility).async {
            let output = runEngineForJSON(["ollama-models"])
            guard let data = output.data(using: .utf8),
                  let decoded = try? JSONDecoder().decode(OllamaModelResponse.self, from: data) else { return }
            DispatchQueue.main.async {
                ollamaModels = decoded.models
                let detectedVisionModels = Array(Set(decoded.visionModels + decoded.models.filter { looksLikeVisionModel($0) })).sorted()
                ollamaVisionModels = detectedVisionModels
                if let firstVision = detectedVisionModels.first {
                    ollamaModel = firstVision
                } else if let firstModel = decoded.models.first, ollamaModel == "llava" {
                    ollamaModel = firstModel
                }
            }
        }
    }

    private func runEngineForJSON(_ args: [String]) -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/python3")
        process.arguments = [enginePath] + args
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()
        do {
            try process.run()
            process.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            return String(data: data, encoding: .utf8) ?? ""
        } catch {
            return ""
        }
    }

    private func localToolPath(_ name: String) -> String? {
        let candidates = [
            "/opt/homebrew/bin/\(name)",
            "/usr/local/bin/\(name)",
            "/usr/bin/\(name)",
            "/bin/\(name)"
        ]
        return candidates.first { FileManager.default.isExecutableFile(atPath: $0) }
    }

    private func refreshFFmpegStatus() {
        if let ffmpeg = localToolPath("ffmpeg") {
            ffmpegStatus = "已检测到 ffmpeg：\(ffmpeg)"
        } else {
            ffmpegStatus = "未检测到 ffmpeg"
        }
    }

    private func installFFmpeg() {
        guard let brew = localToolPath("brew") else {
            ffmpegStatus = "未检测到 Homebrew，请先安装 Homebrew"
            return
        }
        installingFFmpeg = true
        ffmpegStatus = "正在安装 ffmpeg..."
        logText += "\n$ \(brew) install ffmpeg\n"
        DispatchQueue.global(qos: .userInitiated).async {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: brew)
            process.arguments = ["install", "ffmpeg"]
            let pipe = Pipe()
            process.standardOutput = pipe
            process.standardError = pipe
            do {
                try process.run()
                process.waitUntilExit()
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                let output = String(data: data, encoding: .utf8) ?? ""
                DispatchQueue.main.async {
                    logText += output
                    installingFFmpeg = false
                    refreshFFmpegStatus()
                    if process.terminationStatus != 0 {
                        ffmpegStatus = "ffmpeg 安装失败，打开日志查看原因"
                    }
                }
            } catch {
                DispatchQueue.main.async {
                    installingFFmpeg = false
                    ffmpegStatus = "ffmpeg 安装失败：\(error.localizedDescription)"
                }
            }
        }
    }

    private func handleStreamChunk(_ text: String) {
        streamLineBuffer += text
        while let newline = streamLineBuffer.firstIndex(of: "\n") {
            let line = String(streamLineBuffer[..<newline])
            streamLineBuffer.removeSubrange(...newline)
            handleStreamLine(line)
        }
    }

    private func handleStreamLine(_ line: String) {
        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        logText += trimmed + "\n"
        guard let data = trimmed.data(using: .utf8),
              let event = try? JSONDecoder().decode(StreamPlanEvent.self, from: data) else { return }
        switch event.event {
        case "scan":
            let remaining = (event.copyCandidates ?? 0) + (event.audioSidecars ?? 0)
            previewTotal = resumeBaseCount + remaining
            previewCurrent = resumeBaseCount
            previewProgress = 0
            let skipped = event.skippedFiles ?? 0
            statusMessage = skipped > 0
                ? "断点继续：已跳过 \(skipped) 个文件，剩余 \(remaining) 个。"
                : "扫描完成：找到 \(event.totalFiles ?? 0) 个文件，开始生成去向。"
        case "row":
            guard let row = event.row else { return }
            if !allRows.contains(where: { $0.sourcePath == row.sourcePath }) {
                if row.kind == "audio_sidecar" {
                    audioRows.append(row)
                } else {
                    planRows.append(row)
                }
            }
            if selectedRowID == nil {
                selectedRowID = row.id
            }
            previewCurrent = resumeBaseCount + (event.index ?? 0)
            previewTotal = max(resumeBaseCount + (event.total ?? 0), previewTotal)
            previewProgress = previewTotal > 0 ? min(1, Double(previewCurrent) / Double(previewTotal)) : 0
            statusMessage = "正在生成预览：\(previewCurrent)/\(previewTotal)"
        case "summary":
            if let finalSummary = event.summary {
                summary = finalSummary
                previewCurrent = previewAppendMode
                    ? allRows.count
                    : finalSummary.copiedOrVerified + finalSummary.audioSidecars
                previewTotal = max(previewTotal, previewCurrent)
                previewProgress = previewTotal > 0 ? min(1, Double(previewCurrent) / Double(previewTotal)) : 1
                statusMessage = "预览完成：\(planRows.count) 个文件将入库。"
            }
            if let rows = event.rows {
                if previewAppendMode {
                    appendUnique(rows)
                } else {
                    planRows = rows
                }
            }
            if let audio = event.audioRows {
                if previewAppendMode {
                    appendUnique(audio)
                } else {
                    audioRows = audio
                }
            }
            if selectedRowID == nil {
                selectedRowID = planRows.first?.id ?? audioRows.first?.id
            }
            ensureSelectedThumbnail()
        case "import_scan":
            importMediaTotal = event.mediaTotal ?? 0
            importBackupTotal = event.backupTotal ?? 0
            importSidecarTotal = event.sidecarTotal ?? 0
            previewTotal = event.total ?? (importMediaTotal + importBackupTotal + importSidecarTotal)
            previewCurrent = 0
            previewProgress = 0
            statusMessage = "准备复制：共 \(previewTotal) 个步骤。"
        case "import_row":
            let phase = event.phase ?? "copy"
            let index = event.index ?? 0
            let total = event.total ?? 0
            let base: Int
            let label: String
            switch phase {
            case "backup":
                base = importMediaTotal
                label = "正在原样备份"
            case "delete_source":
                base = importMediaTotal + importBackupTotal + importSidecarTotal
                label = "正在删除源素材"
                previewTotal = max(previewTotal, base + total)
            case "delete_sidecar":
                base = importMediaTotal + importBackupTotal
                label = "正在清理 LRF/XML"
            default:
                base = 0
                label = "正在复制并校验"
            }
            previewCurrent = base + index
            previewTotal = max(previewTotal, base + total)
            previewProgress = previewTotal > 0 ? min(1, Double(previewCurrent) / Double(previewTotal)) : 0
            statusMessage = "\(label)：\(previewCurrent)/\(previewTotal)"
        case "import_summary":
            if let finalSummary = event.summary {
                summary = finalSummary
            }
            previewCurrent = max(previewCurrent, previewTotal)
            previewProgress = previewTotal > 0 ? 1 : previewProgress
            statusMessage = "复制任务完成。建议查看审计目录确认日志。"
        default:
            break
        }
    }

    private func handleStreamCompletion(exitCode: Int32) {
        if !streamLineBuffer.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            handleStreamLine(streamLineBuffer)
            streamLineBuffer = ""
        }
        logText += "\nExit code: \(exitCode)"
        defer {
            isRunning = false
            runningTaskKind = nil
        }

        if didRequestStop {
            statusMessage = runningTaskKind == .copy ? "复制任务已取消。" : "预览已暂停。可以继续预览或调整设置。"
            return
        }

        guard exitCode == 0 else {
            statusMessage = runningTaskKind == .copy ? "复制失败，打开日志查看原因。" : "预览失败，打开日志查看原因。"
            showLog = true
            return
        }

        if runningTaskKind == .copy {
            if !statusMessage.contains("完成") {
                statusMessage = "复制任务完成。建议查看审计目录确认日志。"
            }
            previewProgress = previewTotal > 0 ? 1 : previewProgress
            DispatchQueue.main.async {
                runPlan(restart: true)
            }
            return
        }

        if summary == nil {
            statusMessage = allRows.isEmpty ? "预览完成，但没有发现可入库素材。" : "预览完成：\(planRows.count) 个文件将入库。"
        }
        previewProgress = previewTotal > 0 ? 1 : previewProgress
    }

    private func installOllamaModel(_ model: String) {
        installingModel = true
        modelInstallStatus = "正在拉取 \(model)"
        logText += "\n$ ollama pull \(model)\n"
        DispatchQueue.global(qos: .userInitiated).async {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
            process.arguments = ["ollama", "pull", model]
            let pipe = Pipe()
            process.standardOutput = pipe
            process.standardError = pipe
            do {
                try process.run()
                process.waitUntilExit()
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                let output = String(data: data, encoding: .utf8) ?? ""
                DispatchQueue.main.async {
                    logText += output
                    installingModel = false
                    if process.terminationStatus == 0 {
                        markOllamaModelInstalled(model)
                    } else {
                        modelInstallStatus = "安装失败"
                        refreshOllamaModels()
                    }
                }
            } catch {
                DispatchQueue.main.async {
                    installingModel = false
                    modelInstallStatus = "安装失败：\(error.localizedDescription)"
                }
            }
        }
    }

    private func handleEngineResult(output: String, exitCode: Int32, parsePlan: Bool) {
        logText += output
        logText += "\nExit code: \(exitCode)"
        defer {
            isRunning = false
            runningTaskKind = nil
        }

        if didRequestStop {
            statusMessage = "任务已取消。"
            return
        }

        guard exitCode == 0 else {
            statusMessage = "任务失败，打开日志查看原因。"
            showLog = true
            return
        }

        if parsePlan {
            guard let data = output.data(using: .utf8),
                  let decoded = try? JSONDecoder().decode(PlanResponse.self, from: data) else {
                statusMessage = "预览解析失败，打开日志查看原始输出。"
                showLog = true
                return
            }
            summary = decoded.summary
            planRows = decoded.rows
            audioRows = decoded.audioRows
            selectedRowID = decoded.rows.first?.id ?? decoded.audioRows.first?.id
            statusMessage = "预览完成：\(decoded.summary.copiedOrVerified) 个文件将入库。"
            ensureSelectedThumbnail()
        } else {
            statusMessage = "复制任务完成。建议查看审计目录确认日志。"
            runPlan(restart: true)
        }
    }

    private func ensureSelectedThumbnail() {
        guard makeThumbnails,
              let row = selectedRow,
              row.kind == "video" || row.kind == "photo",
              (row.thumbnailPath ?? "").isEmpty,
              let auditDir = summary?.auditDir else { return }
        generateThumbnail(for: row, auditDir: auditDir)
    }

    private func generateThumbnail(for row: MediaPlanRow, auditDir: String) {
        DispatchQueue.global(qos: .utility).async {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/python3")
            process.arguments = [
                enginePath,
                "thumbnail",
                "--path", row.sourcePath,
                "--audit-dir", auditDir
            ]
            let pipe = Pipe()
            process.standardOutput = pipe
            process.standardError = Pipe()
            do {
                try process.run()
                process.waitUntilExit()
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                guard process.terminationStatus == 0,
                      let json = try? JSONSerialization.jsonObject(with: data) as? [String: String],
                      let thumbnailPath = json["thumbnail_path"],
                      !thumbnailPath.isEmpty else { return }
                DispatchQueue.main.async {
                    updateThumbnail(rowID: row.id, thumbnailPath: thumbnailPath)
                }
            } catch {
                return
            }
        }
    }

    private func updateThumbnail(rowID: MediaPlanRow.ID, thumbnailPath: String) {
        if let index = planRows.firstIndex(where: { $0.id == rowID }) {
            planRows[index].thumbnailPath = thumbnailPath
            return
        }
        if let index = audioRows.firstIndex(where: { $0.id == rowID }) {
            audioRows[index].thumbnailPath = thumbnailPath
        }
    }

    private func markOllamaModelInstalled(_ model: String) {
        modelInstallStatus = "安装完成"
        ollamaModel = model
        if !ollamaModels.contains(model) {
            ollamaModels.append(model)
            ollamaModels.sort()
        }
        if looksLikeVisionModel(model), !ollamaVisionModels.contains(model) {
            ollamaVisionModels.append(model)
            ollamaVisionModels.sort()
        }
        refreshOllamaModels()
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            refreshOllamaModels()
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 4.0) {
            refreshOllamaModels()
        }
    }
}

struct StatBox: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.title3.weight(.semibold))
                .monospacedDigit()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

struct StatusPill: View {
    let text: String
    let status: String

    var body: some View {
        Text(text)
            .font(.caption.weight(.medium))
            .lineLimit(1)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(color.opacity(0.15))
            .foregroundStyle(color)
            .clipShape(Capsule())
    }

    private var color: Color {
        switch status {
        case "already_verified", "verified":
            return .green
        case "hash_mismatch", "orphan_audio_sidecar":
            return .red
        default:
            return .blue
        }
    }
}

struct UsageBar: View {
    let usage: DiskUsage?
    var showsLabels = true

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color(nsColor: .separatorColor).opacity(0.35))
                    RoundedRectangle(cornerRadius: 3)
                        .fill(barColor)
                        .frame(width: proxy.size.width * CGFloat(usage?.fraction ?? 0))
                }
            }
            .frame(height: 6)
            if showsLabels, let usage {
                HStack {
                    Text("已用 \(formatBytes(usage.used))")
                    Spacer()
                    Text("剩余 \(formatBytes(usage.free))")
                }
                .font(.caption2)
                .foregroundStyle(.secondary)
            }
        }
    }

    private var barColor: Color {
        guard let fraction = usage?.fraction else { return .secondary }
        if fraction > 0.9 { return .red }
        if fraction > 0.75 { return .orange }
        return .accentColor
    }
}

struct FinderSidebarRow: View {
    let title: String
    let systemImage: String
    let path: String
    var isSelected = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(alignment: .top, spacing: 9) {
                Image(systemName: systemImage)
                    .font(.system(size: 15, weight: .medium))
                    .frame(width: 20, height: 22)
                    .foregroundStyle(isSelected ? .primary : .secondary)
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(1)
                    Text(path)
                        .font(.system(.caption2, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                    UsageBar(usage: diskUsage(for: path), showsLabels: false)
                    if let usage = diskUsage(for: path) {
                        HStack {
                            Text(formatBytes(usage.used))
                            Spacer()
                            Text(formatBytes(usage.free))
                        }
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    }
                }
                Image(systemName: "folder")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 7)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(isSelected ? Color.accentColor.opacity(0.16) : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: 7))
        }
        .buttonStyle(.plain)
    }
}

struct ProjectTagCard: View {
    @Binding var key: String
    @Binding var zh: String
    @Binding var en: String
    let remove: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: "tag")
                    .foregroundStyle(.secondary)
                TextField("key", text: $key)
                    .font(.system(.caption, design: .monospaced))
                    .textFieldStyle(.plain)
                    .lineLimit(1)
                Button(action: remove) {
                    Image(systemName: "minus.circle")
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .help("删除 tag")
            }
            Divider()
            HStack(spacing: 6) {
                Text("中")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .frame(width: 18)
                TextField("中文名", text: $zh)
                    .textFieldStyle(.plain)
                    .lineLimit(1)
            }
            HStack(spacing: 6) {
                Text("EN")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .frame(width: 18)
                TextField("English", text: $en)
                    .textFieldStyle(.plain)
                    .lineLimit(1)
            }
        }
        .padding(9)
        .background(Color(nsColor: .textBackgroundColor).opacity(0.55))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color(nsColor: .separatorColor), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

struct TargetLocationCard: View {
    let title: String
    let systemImage: String
    let path: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    Image(systemName: systemImage)
                        .frame(width: 18)
                    Text(title)
                        .font(.subheadline.weight(.semibold))
                    Spacer()
                    Image(systemName: "folder")
                        .foregroundStyle(.secondary)
                }
                Text(path)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .truncationMode(.middle)
                UsageBar(usage: diskUsage(for: path))
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(nsColor: .controlBackgroundColor))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color(nsColor: .separatorColor), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
    }
}

struct VolumeCard: View {
    let volume: VolumeCandidate
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Image(systemName: iconName)
                        .font(.body)
                    Spacer()
                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                    }
                }
                Text(volume.name)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                    .truncationMode(.middle)
                HStack(spacing: 8) {
                    MiniStat(label: "视频", value: volume.counts["video"] ?? 0)
                    MiniStat(label: "照片", value: volume.counts["photo"] ?? 0)
                }
                Text(volume.cameraHints.joined(separator: " / "))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                UsageBar(usage: DiskUsage(total: volume.diskTotalBytes, free: volume.diskFreeBytes), showsLabels: false)
            }
            .padding(9)
            .frame(width: 176, height: 104)
            .background(isSelected ? Color.accentColor.opacity(0.13) : Color(nsColor: .controlBackgroundColor))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(isSelected ? Color.accentColor : Color(nsColor: .separatorColor), lineWidth: isSelected ? 2 : 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
    }

    private var iconName: String {
        volume.cameraScore > 0 ? "camera" : "externaldrive"
    }
}

struct MiniStat: View {
    let label: String
    let value: Int

    var body: some View {
        Text("\(label) \(value)")
            .font(.caption2.weight(.medium))
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(Color(nsColor: .textBackgroundColor))
            .clipShape(Capsule())
    }
}

struct TagChip: View {
    let label: String
    let count: Int
    var isSelected = false

    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
            Text(label)
                .lineLimit(1)
            Text("\(count)")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
        }
        .font(.caption)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(isSelected ? color.opacity(0.28) : color.opacity(0.12))
        .overlay(
            Capsule()
                .stroke(isSelected ? color : .clear, lineWidth: 1)
        )
        .clipShape(Capsule())
    }

    private var color: Color {
        switch label {
        case "航拍", "Aerial":
            return .blue
        case "手持素材", "Handheld_Material":
            return .orange
        case "RoboCup":
            return .green
        case "照片", "Photo":
            return .purple
        default:
            return .gray
        }
    }
}
