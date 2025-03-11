import Foundation

class LocalizationManager: ObservableObject {
    static let shared = LocalizationManager()
    @Published var currentLanguage: String {
        didSet {
            UserDefaults.standard.set(currentLanguage, forKey: "AppLanguage")
            NotificationCenter.default.post(name: .languageDidChange, object: nil)
        }
    }
    
    init() {
        // 获取系统语言
        let preferredLanguage = Locale.preferredLanguages[0]
        let isChineseSystem = preferredLanguage.contains("zh")
        
        // 从 UserDefaults 获取已保存的语言设置，如果没有则使用系统语言
        currentLanguage = UserDefaults.standard.string(forKey: "AppLanguage") 
            ?? (isChineseSystem ? "中文" : "English")
    }
    
    // 所有文本的字典
    private let localizedStrings: [String: [String: String]] = [
        "中文": [
            "loadVideo": "加载本地视频",
            "export": "导出",
            "selectVideo": "请选择一个视频",
            "loading": "正在加载视频...",
            "progress": "%d%%",
            "lensNumber": "镜号",
            "time": "时间",
            "jumpToTime": "跳转到此时间",
            "confirmDelete": "确认删除",
            "deleteMessage": "您确定要删除这张图片吗？",
            "delete": "删除",
            "cancel": "取消",
            "confirm": "确认",
            "modifyLensNumber": "修改镜号",
            "inputNewLensNumber": "请输入新镜号",
            "numberRange": "请输入1-%d之间的数字",
            "import": "导入",
            "member": "会员",
            "settings": "设置",
            "language": "语言",
            "selectLanguage": "选择语言",
            "done": "完成",
            "pleaseSelect": "请选择",
            "pleaseInput": "请输入内容",
            "imageLoadFailed": "图片加载失败",
            "addField": "添加",
            "selectFieldType": "选择字段类型",
            "shotType": "景别",
            "cameraMovement": "运镜",
            "custom": "自定义",
            "formTitle": "表单标题",
            "fieldType.custom": "自定义",
            "fieldType.shotType": "景别",
            "fieldType.cameraMovement": "运镜",
            "shotType.extreme": "全景",
            "shotType.long": "远景",
            "shotType.medium": "中景",
            "shotType.close": "近景",
            "shotType.detail": "特写",
            "cameraMovement.fixed": "固定",
            "cameraMovement.pan": "横摇",
            "cameraMovement.tilt": "俯仰",
            "cameraMovement.truck": "横移",
            "cameraMovement.pedestal": "升降",
            "cameraMovement.follow": "跟随",
            "cameraMovement.orbit": "环绕",
            "cameraMovement.zoom": "推拉",
            "fieldSettings": "字段设置（拖动排序）",
            "save": "保存",
            "screenshot": "截图",
            "insert": "插入",
            "checkUpdate": "检查更新",
            "feedback": "反馈建议",
            "officialWebsite": "官方网站",
            "captureFirst": "请先截图",
            "exportExcel": "导出Excel文件",
            "menu": "菜单",
            "back": "返回"
        ],
        "English": [
            "loadVideo": "Load Video",
            "export": "Export",
            "selectVideo": "Please select a video",
            "loading": "Loading video...",
            "progress": "%d%%",
            "lensNumber": "Lens No.",
            "time": "Time",
            "jumpToTime": "Jump to time",
            "confirmDelete": "Confirm Delete",
            "deleteMessage": "Are you sure you want to delete this image?",
            "delete": "Delete",
            "cancel": "Cancel",
            "confirm": "Confirm",
            "modifyLensNumber": "Modify Lens Number",
            "inputNewLensNumber": "Please input new lens number",
            "numberRange": "Please input a number between 1-%d",
            "import": "Import",
            "member": "Member",
            "settings": "Settings",
            "language": "Language",
            "selectLanguage": "Select Language",
            "done": "Done",
            "pleaseSelect": "Please select",
            "pleaseInput": "Please input",
            "imageLoadFailed": "Image load failed",
            "addField": "Add",
            "selectFieldType": "Select Field Type",
            "shotType": "Shot Type",
            "cameraMovement": "Camera Movement",
            "custom": "Custom",
            "formTitle": "Form Title",
            "fieldType.custom": "Custom",
            "fieldType.shotType": "Shot Type",
            "fieldType.cameraMovement": "Camera Movement",
            "shotType.extreme": "Extreme Shot",
            "shotType.long": "Long Shot",
            "shotType.medium": "Medium Shot",
            "shotType.close": "Close Shot",
            "shotType.detail": "Detail Shot",
            "cameraMovement.fixed": "Fixed",
            "cameraMovement.pan": "Pan",
            "cameraMovement.tilt": "Tilt",
            "cameraMovement.truck": "Truck",
            "cameraMovement.pedestal": "Pedestal",
            "cameraMovement.follow": "Follow",
            "cameraMovement.orbit": "Orbit",
            "cameraMovement.zoom": "Zoom",
            "fieldSettings": "Field Settings (Drag to Sort)",
            "save": "Save",
            "screenshot": "Screenshot",
            "insert": "Insert",
            "checkUpdate": "Check Update",
            "feedback": "Feedback",
            "officialWebsite": "Official Website",
            "captureFirst": "Please capture first",
            "exportExcel": "Export Excel File",
            "menu": "Menu",
            "back": "Back"
        ]
    ]
    
    // 获取本地化文本
    func localizedString(_ key: String) -> String {
        return localizedStrings[currentLanguage]?[key] ?? key
    }
    
    // 获取带格式的本地化文本
    func localizedString(_ key: String, arguments: CVarArg...) -> String {
        let format = localizedStrings[currentLanguage]?[key] ?? key
        return String(format: format, arguments: arguments)
    }
    
    // 添加获取选项数组的方法
    func getShotTypeOptions() -> [String] {
        return [
            localizedString("shotType.extreme"),
            localizedString("shotType.long"),
            localizedString("shotType.medium"),
            localizedString("shotType.close"),
            localizedString("shotType.detail")
        ]
    }
    
    func getCameraMovementOptions() -> [String] {
        return [
            localizedString("cameraMovement.fixed"),
            localizedString("cameraMovement.pan"),
            localizedString("cameraMovement.tilt"),
            localizedString("cameraMovement.truck"),
            localizedString("cameraMovement.pedestal"),
            localizedString("cameraMovement.follow"),
            localizedString("cameraMovement.orbit"),
            localizedString("cameraMovement.zoom")
        ]
    }
}

// 添加通知名称
extension Notification.Name {
    static let languageDidChange = Notification.Name("languageDidChange")
} 