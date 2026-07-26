import Foundation

/// Lightweight in-app strings. Language is an explicit product preference
/// (`AppPreferences.appLanguage`), independent of macOS locale.
enum L10n {
    /// Current UI language from UserDefaults (same source as Settings).
    static var language: AppLanguage {
        AppLanguage.resolve(
            stored: UserDefaults.standard.string(forKey: AppConstants.DefaultsKey.appLanguage)
        )
    }

    static func settings(_ language: AppLanguage) -> SettingsStrings {
        SettingsStrings(language: language)
    }

    static var settings: SettingsStrings { settings(language) }

    static func workbench(_ language: AppLanguage) -> WorkbenchStrings {
        WorkbenchStrings(language: language)
    }

    static var workbench: WorkbenchStrings { workbench(language) }

    /// Localized message for pin / favorites capacity errors.
    static func pinError(_ error: PinError, language: AppLanguage = language) -> String {
        workbench(language).pinError(error)
    }
}

// MARK: - Shared bilingual helper

private protocol L10nBundle {
    var language: AppLanguage { get }
}

private extension L10nBundle {
    func t(en: String, zh: String) -> String {
        language == .chinese ? zh : en
    }
}

// MARK: - Settings

struct SettingsStrings: L10nBundle {
    let language: AppLanguage

    var windowTitle: String {
        t(en: "\(AppConstants.displayName) Settings", zh: "\(AppConstants.displayName) 设置")
    }

    // MARK: Appearance

    var appearanceSection: String { t(en: "Appearance", zh: "外观") }
    var appearanceFooter: String {
        t(en: "Changes the clipboard workbench only.", zh: "仅改变剪贴板工作台的外观。")
    }
    var selectedThemeA11y: String { t(en: "Selected", zh: "已选择") }

    func workbenchThemeName(_ theme: WorkbenchTheme) -> String {
        switch theme {
        case .systemGlass: return t(en: "Default", zh: "默认")
        case .warmPaper: return t(en: "Warm Paper", zh: "暖纸")
        case .mossGarden: return t(en: "Moss Garden", zh: "苔庭")
        case .graphite: return t(en: "Graphite", zh: "石墨")
        case .mistBlue: return t(en: "Mist Blue", zh: "雾蓝")
        case .roseAsh: return t(en: "Rose Ash", zh: "樱灰")
        }
    }

    // MARK: History

    var historySection: String { t(en: "History", zh: "历史记录") }
    var maxItemsTitle: String { t(en: "Maximum history items", zh: "历史最多保留") }
    var maxItemsFooter: String {
        t(en: "Oldest unpinned items are removed when the limit is reached. Favorites are never auto-removed.",
          zh: "超出后自动删除最旧的未收藏记录；收藏不会被自动清理。")
    }
    var maxFavoritesTitle: String { t(en: "Maximum favorites", zh: "收藏上限") }
    var maxFavoritesFooter: String {
        t(en: "How many cards you can pin. Default is \(AppConstants.defaultMaxFavoriteCount).",
          zh: "可钉住的收藏数量，默认 \(AppConstants.defaultMaxFavoriteCount) 条。")
    }
    var clearHistoryTitle: String { t(en: "Clear history", zh: "清空历史") }
    var clearHistoryFooter: String {
        t(en: "Deletes unpinned history. Favorites are kept.",
          zh: "删除未收藏的历史记录，收藏会保留。")
    }
    var clearHistoryButton: String { t(en: "Clear…", zh: "清空…") }
    var clearConfirmTitle: String {
        t(en: "Clear clipboard history?", zh: "清空剪贴板历史？")
    }
    var clearConfirmAction: String { t(en: "Clear History", zh: "清空历史") }
    var clearConfirmCancel: String { t(en: "Cancel", zh: "取消") }
    var clearConfirmMessage: String {
        t(en: "Unpinned items are deleted permanently. Your favorites stay.",
          zh: "将永久删除未收藏的条目，收藏的内容会保留。")
    }

    // MARK: Privacy

    var privacySection: String { t(en: "Privacy", zh: "隐私") }
    var ignoredAppsTitle: String { t(en: "Ignored apps", zh: "忽略的应用") }
    var ignoredAppsFooter: String {
        t(en: "Clipboard content from these apps is not recorded. Add apps yourself — nothing is ignored by default.",
          zh: "这些应用的剪贴内容不会被记录。需自行添加，默认不忽略任何应用。")
    }
    var ignoredAppsEmpty: String { t(en: "No ignored apps", zh: "暂无忽略的应用") }
    var addAppButton: String { t(en: "Add App…", zh: "添加应用…") }
    var runningAppsSection: String { t(en: "Running apps", zh: "正在运行") }
    var historyAppsSection: String { t(en: "Seen in history", zh: "历史中出现过") }
    var noRunningApps: String { t(en: "No other apps running", zh: "暂无其他正在运行的应用") }
    var noHistoryApps: String { t(en: "No apps in history yet", zh: "历史中尚无应用来源") }
    var enterBundleIdButton: String { t(en: "Enter Bundle ID", zh: "输入 Bundle ID") }
    var hideBundleIdButton: String { t(en: "Hide Bundle ID", zh: "收起 Bundle ID") }
    var bundleIdPrompt: String {
        t(en: "Bundle ID, e.g. com.example.app",
          zh: "输入 Bundle ID，例如 com.example.app")
    }
    var addButton: String { t(en: "Add", zh: "添加") }
    var removeHelp: String { t(en: "Remove", zh: "移除") }
    var cannotIgnoreSelf: String {
        t(en: "\(AppConstants.displayName) cannot ignore itself.",
          zh: "无法将 \(AppConstants.displayName) 自身加入忽略列表。")
    }
    var alreadyIgnored: String {
        t(en: "That app is already ignored.",
          zh: "该应用已在忽略列表中。")
    }

    func addedIgnore(_ name: String) -> String {
        t(en: "Ignored “\(name)”", zh: "已忽略“\(name)”")
    }

    // MARK: System

    var systemSection: String { t(en: "System", zh: "系统") }
    var languageTitle: String { t(en: "Language", zh: "语言") }
    var languageFooter: String {
        t(en: "Applies to Settings, the clipboard workbench, menus, and status messages.",
          zh: "应用于设置、剪贴板工作台、菜单和状态提示。")
    }
    var launchAtLoginTitle: String { t(en: "Launch at login", zh: "登录时启动") }
    var launchAtLoginFooter: String {
        t(en: "Start \(AppConstants.displayName) in the menu bar when you log in.",
          zh: "开机后在菜单栏自动运行 \(AppConstants.displayName)")
    }
    var accessibilityTitle: String { t(en: "Accessibility", zh: "辅助功能权限") }
    var accessibilityOpen: String { t(en: "Open Settings…", zh: "打开设置…") }

    func accessibilityDetail(trusted: Bool) -> String {
        if trusted {
            return t(en: "Enabled. Auto-paste into the frontmost app is available.",
                     zh: "已开启，可自动粘贴到前台应用。")
        }
        return t(en: "Not enabled. Paste degrades to copy-only — press ⌘V yourself.",
                 zh: "未开启。粘贴将降级为仅复制到剪贴板，需手动 ⌘V。")
    }

    var hotkeyTitle: String { t(en: "Keyboard shortcut", zh: "快捷键") }
    var hotkeyFooter: String {
        t(en: "Opens and closes the clipboard workbench. Include ⌘, ⌃, or ⌥.",
          zh: "用于打开/关闭剪贴板工作台。须包含 ⌘、⌃ 或 ⌥。")
    }
    var hotkeyRecordPrompt: String {
        t(en: "Press new shortcut…", zh: "按下新的快捷键…")
    }
    var hotkeyClickToRecord: String {
        t(en: "Click to record", zh: "点击录制")
    }
    var hotkeyReset: String { t(en: "Reset", zh: "重置") }
    var hotkeyRegisterFailed: String {
        t(en: "Could not register that shortcut. Try another combination.",
          zh: "无法注册该快捷键，请换一组组合键。")
    }
    var hotkeyNeedModifier: String {
        t(en: "Include Command, Control, or Option.",
          zh: "请包含 Command、Control 或 Option。")
    }

    // MARK: About

    var aboutSection: String { t(en: "About", zh: "关于") }
    var aboutTagline: String {
        t(en: "Local clipboard history · no cloud upload",
          zh: "本地剪贴板历史 · 不上传云端")
    }
    var dataDirectory: String { t(en: "Data directory", zh: "数据目录") }

    var quitTitle: String {
        t(en: "Quit \(AppConstants.displayName)", zh: "退出 \(AppConstants.displayName)")
    }
    var quitFooter: String {
        t(en: "Leave the menu bar and stop clipboard monitoring.",
          zh: "退出后菜单栏图标消失，并停止监听剪贴板。")
    }
    var quitButton: String {
        t(en: "Quit", zh: "退出")
    }
}

// MARK: - Workbench (history panel + status toasts + card menus + status item)

struct WorkbenchStrings: L10nBundle {
    let language: AppLanguage

    // MARK: Search & filters

    var searchPlaceholder: String {
        t(en: "Search history…", zh: "搜索历史…")
    }
    var filterHelp: String {
        t(en: "Filter clipboard history", zh: "筛选剪贴板历史")
    }
    var clearSearchHelp: String {
        t(en: "Clear search", zh: "清除搜索")
    }
    var matchingItemsHelp: String {
        t(en: "Matching items", zh: "匹配条数")
    }
    var itemsInHistoryHelp: String {
        t(en: "Items in history", zh: "历史条数")
    }
    var favoritesFilterOnHelp: String {
        t(en: "Showing favorites only — click for all", zh: "仅显示收藏 — 点击查看全部")
    }
    var favoritesFilterOffHelp: String {
        t(en: "Show favorites only", zh: "仅显示收藏")
    }
    var favoritesFilterOnA11y: String {
        t(en: "Favorites filter on", zh: "已开启收藏筛选")
    }
    var favoritesFilterOffA11y: String {
        t(en: "Favorites filter off", zh: "未开启收藏筛选")
    }
    var allApps: String { t(en: "All Apps", zh: "全部应用") }
    var apps: String { t(en: "Apps", zh: "应用") }
    var filterByAppHelp: String {
        t(en: "Filter by source app", zh: "按来源应用筛选")
    }

    // MARK: Overflow & status item menu

    var moreHelp: String { t(en: "More", zh: "更多") }
    var settingsMenu: String { t(en: "Settings…", zh: "设置…") }
    var clearHistoryMenu: String { t(en: "Clear History…", zh: "清空历史…") }
    var quitMenu: String {
        t(en: "Quit \(AppConstants.displayName)", zh: "退出 \(AppConstants.displayName)")
    }
    var showHistoryMenu: String { t(en: "Show History", zh: "显示历史") }

    // MARK: Empty states

    var emptyNoFavoritesTitle: String { t(en: "No favorites yet", zh: "暂无收藏") }
    var emptyNoResultsTitle: String { t(en: "No results", zh: "无匹配结果") }
    var emptyNoHistoryTitle: String { t(en: "No clipboard history yet", zh: "暂无剪贴板历史") }
    var emptyNoFavoritesBody: String {
        t(en: "Right-click a card or press ⌘P to favorite it.",
          zh: "右键卡片或按 ⌘P 添加收藏。")
    }
    var emptyNoResultsBody: String {
        t(en: "Try a different search, app, or favorites filter.",
          zh: "试试其他搜索词、应用或收藏筛选。")
    }
    var emptyNoHistoryBody: String {
        t(en: "Copied text and images will appear here.",
          zh: "复制的文字和图片会显示在这里。")
    }

    // MARK: Accessibility toast

    var openSettingsLink: String { t(en: "Open Settings", zh: "打开设置") }
    var openAccessibilityHelp: String {
        t(en: "Open Accessibility settings", zh: "打开辅助功能设置")
    }
    var copiedAccessibilityNeeded: String {
        t(en: "Copied · Accessibility needed to auto-paste",
          zh: "已复制 · 需要辅助功能权限才能自动粘贴")
    }

    // MARK: Status toasts

    var statusCopied: String { t(en: "Copied", zh: "已复制") }
    var statusDeleted: String { t(en: "Deleted", zh: "已删除") }
    var statusFavorited: String { t(en: "Favorited", zh: "已收藏") }
    var statusUnfavorited: String { t(en: "Unfavorited", zh: "已取消收藏") }
    var statusNoteCleared: String { t(en: "Note cleared", zh: "备注已清除") }
    var statusNoteSaved: String { t(en: "Note saved", zh: "备注已保存") }
    var statusHistoryCleared: String {
        t(en: "History cleared · favorites kept",
          zh: "历史已清空 · 收藏已保留")
    }

    // MARK: Favorite note alert

    var noteAlertTitle: String { t(en: "Favorite note", zh: "收藏备注") }
    var noteAlertMessage: String {
        t(en: "Up to \(AppConstants.maxPinNoteLength) characters. Shown on the card.",
          zh: "最多 \(AppConstants.maxPinNoteLength) 个字符，显示在卡片上。")
    }
    var noteAlertContentLabel: String { t(en: "Card content", zh: "卡片内容") }
    var noteAlertNoteLabel: String { t(en: "Note", zh: "备注") }
    var noteAlertPlaceholder: String {
        t(en: "e.g. work email", zh: "例如：工作邮箱")
    }
    var noteAlertImageOnly: String {
        t(en: "(Image)", zh: "（图片）")
    }
    var noteAlertSave: String { t(en: "Save", zh: "保存") }
    var noteAlertCancel: String { t(en: "Cancel", zh: "取消") }

    // MARK: Card context menu & meta

    var copy: String { t(en: "Copy", zh: "复制") }
    var delete: String { t(en: "Delete", zh: "删除") }
    var addToFavorites: String { t(en: "Add to Favorites", zh: "添加收藏") }
    var removeFavorite: String { t(en: "Remove Favorite", zh: "取消收藏") }
    var addNote: String { t(en: "Add Note…", zh: "添加备注…") }
    var editNote: String { t(en: "Edit Note…", zh: "编辑备注…") }
    var favoriteA11y: String { t(en: "Favorite", zh: "收藏") }
    var imageUnavailable: String { t(en: "Image unavailable", zh: "图片不可用") }
    var unknownApp: String { t(en: "Unknown app", zh: "未知应用") }
    var mixedBadge: String { t(en: "Mixed", zh: "图文") }

    func noteA11y(note: String, source: String) -> String {
        t(en: "Note: \(note). Source: \(source)",
          zh: "备注：\(note)。来源：\(source)")
    }

    func sourceHelp(_ appName: String) -> String {
        t(en: "Source: \(appName)", zh: "来源：\(appName)")
    }

    // MARK: Clear history alert (status item / overflow)

    var clearConfirmTitle: String {
        t(en: "Clear clipboard history?", zh: "清空剪贴板历史？")
    }
    var clearConfirmMessage: String {
        t(en: "Unpinned items are deleted permanently. Your favorites stay.",
          zh: "将永久删除未收藏的条目，收藏的内容会保留。")
    }
    var clearConfirmAction: String { t(en: "Clear History", zh: "清空历史") }
    var clearConfirmCancel: String { t(en: "Cancel", zh: "取消") }

    // MARK: Errors

    func pinError(_ error: PinError) -> String {
        switch error {
        case .notFound:
            return t(en: "Item not found", zh: "未找到该条目")
        case .favoritesFull(let limit):
            return t(en: "Favorites full (\(limit)). Unpin one first.",
                     zh: "收藏已满（\(limit)）。请先取消一条收藏。")
        }
    }

    func displayError(_ error: Error) -> String {
        if let pin = error as? PinError {
            return pinError(pin)
        }
        return error.localizedDescription
    }
}
