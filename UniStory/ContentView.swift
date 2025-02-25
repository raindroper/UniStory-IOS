import SwiftUI
import PhotosUI
import AVKit
import AVFoundation

import SwiftXLSX
import Foundation

enum FieldType: String, Codable {
    case text = "自定义"
    case shotType = "景别"
    case cameraMovement = "运镜"
}

struct FieldInfo: Identifiable, Codable {
    let id = UUID()
    var title: String
    var value: String
    var key: String // 全局唯一
    var type: FieldType // 添加字段类型
    
    // 添加预设选项
    static let shotTypeOptions = ["全景", "远景", "中景", "近景", "特写"]
    static let cameraMovementOptions = ["固定", "横摇", "俯仰", "横移", "升降", "跟随", "环绕", "推拉"]
}

struct CurrentImage: Identifiable, Codable {
    let id = UUID()        // 唯一标识符
    var image: Data     // 截图图片
    var lensNumber: Int // 镜号
    var timestamp: String    // 时间
    var fields: [FieldInfo] // 字段信息列表
}

struct ScreenItem {
    var id: Int
    var currentImage: String
    var name: String
    var timestamp: String
}

struct ScreenListItemView: View {
    let currentImage: CurrentImage
    let geometry: GeometryProxy
    let selectedImage: CurrentImage?
    let onTap: (CurrentImage) -> Void
    @EnvironmentObject private var localization: LocalizationManager
    
    var body: some View {
        if let uiImage = UIImage(data: currentImage.image) {
            Button(action: {
                onTap(currentImage)
            }) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFit()
                    .frame(width: geometry.size.width * 0.4 - 20, height: 80)
                    .cornerRadius(8)
                    .shadow(radius: 2)
                    .padding(3)
                    .overlay(
                        HStack {
                            Text("\(currentImage.lensNumber)")
                                .font(.caption)
                                .foregroundColor(.white)
                                .padding(5)
                                .background(Color.black)
                                .clipShape(Circle())
                                .padding(.leading, 7)
                            
                            Spacer()
                            
                            Text(currentImage.timestamp)
                                .font(.caption)
                                .foregroundColor(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 3)
                                .background(Color.black.opacity(0.8))
                                .cornerRadius(4)
                                .padding(.trailing, 7)
                        }
                        .padding(.top, 7),
                        alignment: .top
                    )
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color(hex: "4784e1"), lineWidth: selectedImage?.id == currentImage.id ? 2 : 0)
                    )
            }
        } else {
            Text(localization.localizedString("imageLoadFailed"))
                .foregroundColor(.red)
                .frame(width: geometry.size.width * 0.4 - 20, height: 80)
                .background(Color.gray.opacity(0.1))
                .cornerRadius(8)
        }
    }
}

struct ContentView: View {
    @State private var videoURL: URL?
    @State private var showPicker = false
    @State private var screenshotImage: UIImage?
    @State private var player: AVPlayer?
    @State private var screenShotTime: CMTime?
    @State private var currentSeq = 1
    
    @State private var screenList: [CurrentImage] = []
    
    @State private var tempImageInfo: CurrentImage?
    @State private var selectedImage: CurrentImage?
    
    @State private var screenType = ""
    
    @State private var isSettingsSheetPresented = false
    @State private var globalFields: [FieldInfo] = [] // 全局表单项
    
    @State private var showDeleteConfirmation = false
    @State private var deletedImageId: UUID?
    
    @State private var showLensNumberInput = false // 控制镜号输入弹窗
    @State private var newLensNumber: String = "" // 存储用户输入的新镜号
    @State private var tempScreenForLensChange: CurrentImage? // 临时存储要修改镜号的分镜
    
    @State private var isLoadingVideo = false
    @State private var exportProgress: Float = 0
    
    @EnvironmentObject private var localization: LocalizationManager
    
    @State private var isSettingsActive = false
    @State private var isLanguageActive = false
    
    @State private var isExportActive = false  // 新增状态变量
    
    @State private var selectedFieldIndex: Int = 0
    @State private var focusedFieldIndex: Int? // 添加此行以定义 focusedFieldIndex
    
    @FocusState private var isInputFocused: Bool // 添加此行
    
    init() {
        // 设置音频会话，允许在静音模式下播放声音
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback)
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("设置音频会话失败: \(error)")
        }
    }
    
    // 添加一个用于顶部导航栏的视图
    private var topNavigationBar: some View {
        HStack {
            // 左侧按钮
            HStack(spacing: 0) {
                NavigationLink(destination: MenuPageView(
                    isSettingsActive: $isSettingsActive,
                    isLanguageActive: $isLanguageActive
                )) {
                    Image(systemName: "line.horizontal.3")
                        .font(.system(size: 24))
                        .foregroundColor(.black)
                        .padding(16)
                }
                
                Button(action: {
                    showPicker = true
                }) {
                    Text(localization.localizedString("selectVideo"))
                        .font(.system(size: 16))
                        .foregroundColor(.blue)
                        .padding(10)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.blue, lineWidth: 2)
                        )
                }
                .padding(.trailing, 16)
            }
            
            Spacer()
            
            // 右侧按钮
            Button(action: {
                isExportActive = true  // 设置状态变量为 true
            }) {
                Text(localization.localizedString("export"))
                    .font(.system(size: 16))
                    .foregroundColor(.white)
                    .padding([.leading, .trailing], 16)
                    .padding([.top, .bottom], 10)
                    .background(Color.blue)
                    .cornerRadius(8)
            }
            .padding(.trailing, 16)
        }
        .frame(height: 64)
        .background(Color.white)
        .shadow(radius: 4)
    }
    
    // 添加主要内容区域的视图
    private func mainContentView(_ geometry: GeometryProxy) -> some View {
        HStack(spacing: 0) {
            // 左侧滚动列表
            ScrollView {
                VStack(spacing: 10) {
                    ForEach(screenList) { currentImage in
                        ScreenListItemView(
                            currentImage: currentImage,
                            geometry: geometry,
                            selectedImage: selectedImage,
                            onTap: { selected in
                                selectedImage = selected
                            }
                        )
                    }
                    // 在 VStack 的底部添加空白视图，确保内容可以完全滚动
                    Color.clear.frame(height: 80)  // 添加与底部操作栏等高的空白区域
                }
                .padding()
            }
            .frame(width: geometry.size.width * 0.4)
            .overlay(
                Rectangle()
                    .frame(width: 1)
                    .foregroundColor(Color(.systemGray5))
                    .padding(.leading, geometry.size.width * 0.4 - 1),
                alignment: .trailing
            )
            
            // 右侧详情视图
            VStack(alignment: .leading, spacing: 10) {
                if let selected = selectedImage {
                    HStack(spacing: 0) {
                        Text(String(format: "%@: %d", 
                            localization.localizedString("lensNumber"), 
                            selected.lensNumber))
                        Spacer()
                        Button(action: {
                            isSettingsSheetPresented = true
                        }) {
                            Image(systemName: "gearshape")
                                .foregroundColor(.blue)
                        }
                        .padding(.trailing, 10)
                        Button(action: {
                            showDeleteConfirmation = true
                        }) {
                            Image(systemName: "trash")
                                .foregroundColor(.blue)
                        }
                    }
                    HStack(spacing: 0) {
                        Text(String(format: "%@: %@", 
                            localization.localizedString("time"), 
                            selected.timestamp))
                        Spacer()
                        Button(action: {
                            jumpVideoToTime(time: selected.timestamp)
                        }) {
                            Text(localization.localizedString("jumpToTime"))
                                .font(.caption)
                                .padding(6)
                                .background(Color.blue.opacity(0.1))
                                .cornerRadius(4)
                        }
                    }
                    .padding(.top)
                    
                    ScrollView {
                        VStack(spacing: 10) {
                            ForEach(Array(selected.fields.enumerated()), id: \.offset) { index, field in
                                fieldInputView(for: field, index: index)
                            }
                        }
                    }
                }
            }
            .frame(width: geometry.size.width * 0.6 - 26)
            .background(Color.white)
            .frame(maxHeight: .infinity, alignment: .top)
            .padding([.leading, .trailing], 13)
            .padding([.top, .bottom], 10)
            .padding(.bottom, 80) // 添加底部的 padding，留出空间给操作栏
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    var body: some View {
        NavigationView {
            ZStack(alignment: .bottom) {
                // 主要内容
                GeometryReader { geometry in
                    VStack(spacing: 0) {
                        topNavigationBar
                        
                        // 视频播放器部分
                        if isLoadingVideo {
                            VStack {
                                ProgressView(localization.localizedString("loading"))
                                Text(String(format: localization.localizedString("progress"), Int(exportProgress * 100)))
                                ProgressView(value: exportProgress)
                                    .padding()
                            }
                            .frame(width: geometry.size.width, height: geometry.size.width * 9 / 16)
                        } else if let videoURL = videoURL {
                            VideoPlayer(player: player)
                                .frame(width: geometry.size.width, height: geometry.size.width * 9 / 16)
                                .onAppear {
                                    player = AVPlayer(url: videoURL)
                                    player?.play()
                                }
                        } else {
                            Text(localization.localizedString("selectVideo"))
                                .foregroundColor(.gray)
                                .frame(width: geometry.size.width, height: geometry.size.width * 9 / 16)
                                .background(Color.black.opacity(0.1))
                        }

                        // 主要内容视图
                        mainContentView(geometry)
                    }
                }
                
                // 添加导航链接
                NavigationLink(destination: SettingsPageView(), isActive: $isSettingsActive) {
                    EmptyView()
                }
                NavigationLink(destination: LanguageSelectionView(), isActive: $isLanguageActive) {
                    EmptyView()
                }
                NavigationLink(destination: ExportPageView(screenList: screenList, globalFields: globalFields), isActive: $isExportActive) {
                    EmptyView()
                }
                
                // 添加工具栏
                .toolbar {
                    ToolbarItemGroup(placement: .keyboard) {
                        HStack {
                            if let index = focusedFieldIndex {
                                TextField(localization.localizedString("pleaseInput"), text: Binding(
                                    get: {
                                        return self.selectedImage?.fields[index].value ?? ""
                                    },
                                    set: { newValue in
                                        if var image = self.selectedImage {
                                            image.fields[index].value = newValue
                                            self.selectedImage = image  // 重新赋值以更新状态
                                            saveChanges()
                                        }
                                    }
                                ))
                                .focused($isInputFocused)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .frame(minWidth: 0, maxWidth: 300)
                                .background(Color.yellow) // 添加背景颜色以调试
                                .onTapGesture {
                                    isInputFocused = true // 设置焦点
                                }
                                .onSubmit {
                                    focusedFieldIndex = nil  // 当用户完成输入时清除聚焦状态
                                }
                            }
                            
                            Button(action: {
                                hideKeyboard()
                            }) {
                                Text(localization.localizedString("done"))
                            }
                        }
                    }
                }

                
                // 底部操作栏
                VStack(spacing: 0) {
                    HStack(spacing: 10) {
                        if let screenshotImage = screenshotImage {
                            Image(uiImage: screenshotImage)
                                .resizable()
                                .scaledToFit()
                                .frame(height: 200)
                                .padding()
                        } else {
                            Text(localization.localizedString("captureFirst"))
                                .foregroundColor(.gray)
                                .frame(width: 100, height: 60)
                                .background(Color.black.opacity(0.1))
                        }
                        
                        VStack(alignment: .leading, spacing: 5) {
                            Text(String(format: "%@: %@", 
                                localization.localizedString("time"), 
                                formatVideoTime(screenShotTime ?? CMTime(seconds: 0, preferredTimescale: 1))))
                            HStack(spacing: 4) {
                                Text(String(format: "%@: %d", 
                                    localization.localizedString("lensNumber"), 
                                    currentSeq))
                                Button(action: {
                                    if let tempImage = tempImageInfo {
                                        tempScreenForLensChange = tempImage
                                        let maxNumber = screenList.count + 1
                                        newLensNumber = "\(maxNumber)"
                                        showLensNumberInput = true
                                    }
                                }) {
                                    Image(systemName: "pencil")
                                        .foregroundColor(.blue)
                                }
                            }
                        }
                        
                        Spacer()
                        
                        Button(action: takeScreenshot) {
                            VStack(spacing: 5) {
                                Image(systemName: "camera")
                                    .font(.system(size: 20))
                                Text(localization.localizedString("screenshot"))
                                    .font(.caption)
                            }
                            .frame(width: 48, height: 55)
                            .foregroundColor(.white)
                            .background(Color.blue)
                            .cornerRadius(10)
                        }
                        Button(action: insertScreen) {
                            VStack(spacing: 5) {
                                Image(systemName: "plus.square")
                                    .font(.system(size: 20))
                                Text(localization.localizedString("insert"))
                                    .font(.caption)
                            }
                            .frame(width: 48, height: 55)
                            .foregroundColor(.blue)
                            .background(Color.blue.opacity(0.1))
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(Color.blue.opacity(0.3), lineWidth: 1)
                            )
                            .cornerRadius(10)
                        }
                    }
                    .padding([.leading, .trailing])
                    .frame(height: 80)
                    .background(Color.white)
                }
                .edgesIgnoringSafeArea(.all)
            }
        }
        .navigationViewStyle(StackNavigationViewStyle())
        .sheet(isPresented: $showPicker) {
            PhotoPicker(videoURL: $videoURL, 
                        isLoadingVideo: $isLoadingVideo, 
                        exportProgress: $exportProgress)
        }
        .sheet(isPresented: $isSettingsSheetPresented) {
            SettingsSheet(globalFields: $globalFields) { updatedFields in
                globalFields = updatedFields
                syncGlobalFieldsToImages()
                if let selectedIndex = screenList.firstIndex(where: { $0.id == selectedImage?.id }) {
                    selectedImage = screenList[selectedIndex]
                }
            }
        }
        .preferredColorScheme(.light)
        .background(Color.white)
        .edgesIgnoringSafeArea(.horizontal)
        .onAppear {
            screenList = loadScreenListFromFileSystem()
            globalFields = loadGlobalFieldsFromFileSystem()
            
            if !screenList.isEmpty {
                selectedImage = screenList[0]
            }
        }
        .alert(isPresented: $showDeleteConfirmation) {
            Alert(
                title: Text(localization.localizedString("confirmDelete")),
                message: Text(localization.localizedString("deleteMessage")),
                primaryButton: .destructive(Text(localization.localizedString("delete"))) {
                    deleteImage()
                },
                secondaryButton: .cancel()
            )
        }
        .alert(localization.localizedString("modifyLensNumber"), isPresented: $showLensNumberInput) {
            TextField(localization.localizedString("inputNewLensNumber"), text: $newLensNumber)
                .keyboardType(.numberPad)
            Button(localization.localizedString("cancel"), role: .cancel) {
                showLensNumberInput = false
            }
            Button(localization.localizedString("confirm")) {
                if let newNumber = Int(newLensNumber),
                   let tempImage = tempScreenForLensChange {
                    updateLensNumber(for: tempImage, to: newNumber)
                }
                showLensNumberInput = false
            }
        } message: {
            Text(String(format: localization.localizedString("numberRange"), screenList.count + 1))
        }
    }
    
    func exportToExcel() {
        let book = XWorkBook()
        let sheet = book.NewSheet("Export")
        
        // 添加标题行
        var cell = sheet.AddCell(XCoords(row: 1, col: 1))
        cell.value = .text(localization.localizedString("lensNumber"))
        cell = sheet.AddCell(XCoords(row: 1, col: 2))
        cell.value = .text(localization.localizedString("time"))
        cell = sheet.AddCell(XCoords(row: 1, col: 3))
        cell.value = .text(localization.localizedString("screenshot"))
        
        // 动态添加 globalFields 的列标题
        for (index, field) in globalFields.enumerated() {
            cell = sheet.AddCell(XCoords(row: 1, col: 4 + index))
            cell.value = .text(field.title) // 设置列标题为字段名
        }
        
        // 填充内容
        for (rowIndex, screen) in screenList.enumerated() {
            let row = rowIndex + 2 // 数据从第二行开始
            
            // 填充镜号
            cell = sheet.AddCell(XCoords(row: row, col: 1))
            cell.value = .text("\(screen.lensNumber)")
            
            // 填充时间
            cell = sheet.AddCell(XCoords(row: row, col: 2))
            cell.value = .text("\(screen.timestamp)")
            
            // 填充分镜图
            cell = sheet.AddCell(XCoords(row: row, col: 3))
            if let image = UIImage(data: screen.image) {
                let imageCellValue: XImageCell = XImageCell(key: XImages.append(with: image)!, size: CGSize(width: 200, height: 150))
                cell.value = .icon(imageCellValue)
            }
            
            // 动态设置单元格高度为 150
            sheet.ForRowSetHeight(row, 150)
            
            // 填充 fields 的值
            for (colIndex, field) in globalFields.enumerated() {
                let col = 4 + colIndex
                if let fieldValue = screen.fields.first(where: { $0.key == field.key })?.value {
                    cell = sheet.AddCell(XCoords(row: row, col: col))
                    cell.value = .text(fieldValue) // 设置字段值
                } else {
                    cell = sheet.AddCell(XCoords(row: row, col: col))
                    cell.value = .text("") // 如果字段为空，填充空白
                }
            }
        }
        
        // 构建索引和设置列宽
        sheet.buildindex()
        sheet.ForColumnSetWidth(3, 200) // 调整视频截图列宽

        // 保存文件
        let fileid = book.save("example.xlsx")
        print("<<<File XLSX generated!>>>")
        print("\(fileid)")
    }

    // 调整图片大小的方法
    func resizeImage(_ image: UIImage, to targetSize: CGSize) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: targetSize)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: targetSize))
        }
    }
    
    func jumpVideoToTime(time: String) {
        print("原始时间字符串: \(time)")
        if let timeToJump = parseTimeString(time) {
            print("解析后的时间（秒）: \(timeToJump.seconds)")
            
            player?.seek(to: timeToJump, toleranceBefore: .zero, toleranceAfter: .zero) { finished in
                if finished {
                    print("跳转成功")
                    self.player?.play()
                } else {
                    print("跳转失败")
                }
            }
        } else {
            print("时间解析失败")
        }
    }
    
    // 删除当前选中的图片
    func deleteImage() {
        if let selected = selectedImage {
            // 从列表中删除选中的图片
            screenList.removeAll { $0.id == selected.id }
            selectedImage = nil // 清除选中的图片
        }
    }
    
    func syncGlobalFieldsToImages() {
        for index in screenList.indices {
            // 确保图片字段与全局字段一致
            let updatedFields = globalFields.map { globalField in
                if let existingField = screenList[index].fields.first(where: { $0.key == globalField.key }) {
                    return FieldInfo(title: globalField.title, value: existingField.value, key: globalField.key, type: globalField.type)
                } else {
                    return FieldInfo(title: globalField.title, value: "", key: globalField.key, type: globalField.type)
                }
            }
            screenList[index].fields = updatedFields
        }
    }
    
    func loadGlobalFieldsFromFileSystem() -> [FieldInfo] {
        let fileURL = getDocumentsDirectory().appendingPathComponent("globalFields.json")
        
        do {
            let jsonData = try Data(contentsOf: fileURL)
            let fields = try JSONDecoder().decode([FieldInfo].self, from: jsonData)
            print("成功加载 globalFields：\(fields.count) 项")
            
            // 如果字段为空，添加默认字段
            if fields.isEmpty {
                return [
                    FieldInfo(title: "景别", value: "", key: UUID().uuidString, type: .shotType),
                    FieldInfo(title: "运镜", value: "", key: UUID().uuidString, type: .cameraMovement),
                    FieldInfo(title: "镜头分析", value: "", key: UUID().uuidString, type: .text)
                ]
            }
            
            return fields
        } catch {
            print("加载 globalFields 失败：\(error.localizedDescription)")
            // 如果文件不存在或加载失败，返回默认字段
            return [
                FieldInfo(title: "景别", value: "", key: UUID().uuidString, type: .shotType),
                FieldInfo(title: "运镜", value: "", key: UUID().uuidString, type: .cameraMovement),
                FieldInfo(title: "镜头分析", value: "", key: UUID().uuidString, type: .text)
            ]
        }
    }

    
    func saveChanges() {
        guard let selected = selectedImage else { return }

        // 更新 `screenList` 中的对应图片
        if let index = screenList.firstIndex(where: { $0.id == selected.id }) {
            screenList[index] = selected
        }

        // 保存到文件系统
        saveScreenListToFileSystem(screenList)
        print("实时保存成功：\(selected.id)")
    }
    
    func takeScreenshot() {
        guard let player = player,
              let currentItem = player.currentItem else {
            print("播放器未初始化或没有视频")
            return
        }
        
        let asset = currentItem.asset
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.requestedTimeToleranceBefore = .zero
        generator.requestedTimeToleranceAfter = .zero
        
        let currentTime = player.currentTime()
        screenShotTime = currentTime
        
        generator.generateCGImageAsynchronously(for: currentTime) { cgImage, actualTime, error in
            if let error = error {
                print("截图失败: \(error.localizedDescription)")
                return
            }
            
            guard let cgImage = cgImage else {
                print("截图失败：未生成图像")
                return
            }
            
            DispatchQueue.main.async {
                let uiImage = UIImage(cgImage: cgImage)
                let imageData = uiImage.jpegData(compressionQuality: 1.0) ?? Data()
                let formattedTime = formatVideoTime(actualTime)
                
                // 计算最大镜号
                let maxLensNumber = screenList.map { $0.lensNumber }.max() ?? 0
                let newImage = CurrentImage(
                    image: imageData,
                    lensNumber: maxLensNumber + 1,
                    timestamp: formattedTime,
                    fields: globalFields.map { globalField in
                        FieldInfo(title: globalField.title, value: "", key: globalField.key, type: globalField.type)
                    }
                )
                
                self.tempImageInfo = newImage
                self.screenshotImage = uiImage
                // 更新当前显示的镜号为最大值
                self.currentSeq = maxLensNumber + 1
                print("截图成功：时间点 \(actualTime.seconds), \(uiImage)")
            }
        }
    }
    
    // 将 "hh:mm:ss" 格式的字符串转换为 CMTime
    func parseTimeString(_ timeString: String) -> CMTime? {
        let timeComponents = timeString.split(separator: ":").map { String($0) }
        print("时间组件: \(timeComponents)")
        
        if timeComponents.count == 2 {
            // 处理 mm:ss 格式
            guard let minutes = Int(timeComponents[0]),
                  let seconds = Int(timeComponents[1]) else {
                print("mm:ss 格式解析失败")
                return nil
            }
            let totalSeconds = (minutes * 60) + seconds
            print("计算得到的总秒数(mm:ss): \(totalSeconds)")
            return CMTime(seconds: Double(totalSeconds), preferredTimescale: 1)
        } else if timeComponents.count == 3 {
            // 处理 h:mm:ss 格式
            guard let hours = Int(timeComponents[0]),
                  let minutes = Int(timeComponents[1]),
                  let seconds = Int(timeComponents[2]) else {
                print("h:mm:ss 格式解析失败")
                return nil
            }
            let totalSeconds = (hours * 3600) + (minutes * 60) + seconds
            print("计算得到的总秒数(h:mm:ss): \(totalSeconds)")
            return CMTime(seconds: Double(totalSeconds), preferredTimescale: 1)
        } else {
            print("无效的时间格式")
            return nil
        }
    }
    
    func formatVideoTime(_ time: CMTime) -> String {
        let totalSeconds = Int(CMTimeGetSeconds(time))
        guard totalSeconds >= 0 else { return "00:00" } // 防止负时间

        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let seconds = totalSeconds % 60

        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds) // 显示 h:mm:ss
        } else {
            return String(format: "%02d:%02d", minutes, seconds) // 显示 mm:ss
        }
    }
    
    func saveScreenListToFileSystem(_ screenList: [CurrentImage]) {
        let fileURL = getDocumentsDirectory().appendingPathComponent("screenList.json")
        
        do {
            // 将 `screenList` 转换为 JSON 数据
            let jsonData = try JSONEncoder().encode(screenList)
            try jsonData.write(to: fileURL) // 保存到文件系统
            print("screenList 已成功保存：\(fileURL)")
        } catch {
            print("保存 screenList 失败：\(error.localizedDescription)")
        }
    }
    
    func insertScreen() {
        guard let tempImage = tempImageInfo else {
            print("未找到临时图片信息，无法添加")
            
            let uiImage = UIImage(systemName: "photo")!
            let imageData = uiImage.jpegData(compressionQuality: 1.0) ?? Data()
            
            // 计算最大镜号
            let maxLensNumber = screenList.map { $0.lensNumber }.max() ?? 0
            let newImage = CurrentImage(
                image: imageData,
                lensNumber: maxLensNumber + 1,
                timestamp: "00:00:00",
                fields: globalFields.map { globalField in
                    FieldInfo(title: globalField.title, value: "", key: globalField.key, type: globalField.type)
                }
            )
            
            screenList.append(newImage)
            return
        }

        // 添加到 screenList
        screenList.append(tempImage)

        // 保存更新后的 screenList
        saveScreenListToFileSystem(screenList)

        // 清空临时数据
        tempImageInfo = nil
        screenshotImage = nil
    }
    
    func saveImageToFileSystem(_ image: UIImage) -> String? {
            guard let data = image.jpegData(compressionQuality: 1.0) else {
                print("无法将图片转换为 JPEG 数据")
                return nil
            }

            // 生成唯一的文件名
            let fileName = UUID().uuidString + ".jpg"
            let filePath = getDocumentsDirectory().appendingPathComponent(fileName)

            do {
                try data.write(to: filePath)
                print("图片已保存到: \(filePath)")
                return filePath.path
            } catch {
                print("保存图片失败: \(error)")
                return nil
            }
        }


    func loadScreenListFromFileSystem() -> [CurrentImage] {
        let fileURL = getDocumentsDirectory().appendingPathComponent("screenList.json")
        
        do {
            // 读取 JSON 数据并解析为 `screenList`
            let jsonData = try Data(contentsOf: fileURL)
            let screenList = try JSONDecoder().decode([CurrentImage].self, from: jsonData)
            print(jsonData)
            print("成功加载 screenList：\(screenList.count) 项")
            return screenList
        } catch {
            print("加载 screenList 失败：\(error.localizedDescription)")
            return []
        }
    }
    
    func updateLensNumber(for image: CurrentImage, to newNumber: Int) {
        // 确保镜号在有效范围内，如果超过最大值则自动调整为最大值
        let maxNumber = screenList.count + 1
        let adjustedNumber = min(newNumber, maxNumber)
        
        guard adjustedNumber > 0 else { return }
        
        var updatedImage = image
        updatedImage.lensNumber = adjustedNumber
        
        // 如果是已存在的镜号，需要调整其他分镜的镜号
        if adjustedNumber <= screenList.count {
            // 将新镜号及之后的所有分镜号加1
            for i in (adjustedNumber - 1)..<screenList.count {
                screenList[i].lensNumber += 1
            }
        }
        
        // 更新临时图片信息
        tempImageInfo = updatedImage
        
        // 更新当前显示的镜号
        currentSeq = adjustedNumber
    }
    
    @ViewBuilder
    func fieldInputView(for field: FieldInfo, index: Int) -> some View {
        VStack(alignment: .leading) {
            Text(field.title)
                .font(.subheadline)
            
            switch field.type {
            case .shotType:
                Menu {
                    Picker("", selection: Binding(
                        get: { selectedImage?.fields[index].value ?? "" },
                        set: { newValue in
                            selectedImage?.fields[index].value = newValue
                            saveChanges()
                        }
                    )) {
                        Text(localization.localizedString("pleaseSelect")).tag("")
                        ForEach(FieldInfo.shotTypeOptions, id: \.self) { option in
                            Text(option).tag(option)
                        }
                    }
                    .labelsHidden()
                } label: {
                    HStack {
                        Text(selectedImage?.fields[index].value.isEmpty ?? true ? localization.localizedString("pleaseSelect") : selectedImage?.fields[index].value ?? "")
                            .foregroundColor(selectedImage?.fields[index].value.isEmpty ?? true ? .gray : .black)
                        Spacer()
                        Image(systemName: "chevron.down")
                            .foregroundColor(.gray)
                    }
                    .padding(8)
                    .frame(maxWidth: .infinity)
                    .background(Color(.systemGray6))
                    .cornerRadius(8)
                }
                
            case .cameraMovement:
                Menu {
                    Picker("", selection: Binding(
                        get: { selectedImage?.fields[index].value ?? "" },
                        set: { newValue in
                            selectedImage?.fields[index].value = newValue
                            saveChanges()
                        }
                    )) {
                        Text(localization.localizedString("pleaseSelect")).tag("")
                        ForEach(FieldInfo.cameraMovementOptions, id: \.self) { option in
                            Text(option).tag(option)
                        }
                    }
                    .labelsHidden()
                } label: {
                    HStack {
                        Text(selectedImage?.fields[index].value.isEmpty ?? true ? localization.localizedString("pleaseSelect") : selectedImage?.fields[index].value ?? "")
                            .foregroundColor(selectedImage?.fields[index].value.isEmpty ?? true ? .gray : .black)
                        Spacer()
                        Image(systemName: "chevron.down")
                            .foregroundColor(.gray)
                    }
                    .padding(8)
                    .frame(maxWidth: .infinity)
                    .background(Color(.systemGray6))
                    .cornerRadius(8)
                }
                
            case .text:
                GeometryReader { geometry in
                    TextField(localization.localizedString("pleaseInput"), text: Binding(
                        get: { selectedImage?.fields[index].value ?? "" },
                        set: { newValue in
                            selectedImage?.fields[index].value = newValue
                            saveChanges()
                        }
                    ))
                    .focused($isInputFocused)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .frame(width: geometry.size.width) // 确保 TextField 的宽度有效
                    .simultaneousGesture(
                        TapGesture().onEnded {
                            isInputFocused = true // 设置焦点
                            print("\(index)")
                            focusedFieldIndex = index
                            print("\(focusedFieldIndex)")
                        }
                    )
                    .onSubmit {
                        focusedFieldIndex = nil  // 当用户完成输入时清除聚焦状态
                    }
                }
                .frame(height: 44) // 设置一个有效的高度
            }
        }
    }

    // 添加一个辅助函数来隐藏键盘
    private func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}


// 获取沙盒目录径
func getDocumentsDirectory() -> URL {
    FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
}

@ViewBuilder
private func screenListItemView(
    for currentImage: CurrentImage, 
    geometry: GeometryProxy, 
    selectedImage: CurrentImage?, 
    localization: LocalizationManager,
    onTap: @escaping (CurrentImage) -> Void
) -> some View {
    if let uiImage = UIImage(data: currentImage.image) {
        Button(action: {
            onTap(currentImage)
        }) {
            Image(uiImage: uiImage)
                .resizable()
                .scaledToFit()
                .frame(width: geometry.size.width * 0.4 - 20, height: 80)
                .cornerRadius(8)
                .shadow(radius: 2)
                .padding(3)
                .overlay(
                    HStack {
                        // 镜号显示（左上角）
                        Text("\(currentImage.lensNumber)")
                            .font(.caption)
                            .foregroundColor(.white)
                            .padding(5)
                            .background(Color.black)
                            .clipShape(Circle())
                            .padding(.leading, 7)  // 调整左边距以适应新的内边距
                        
                        Spacer()
                        
                        // 时间戳显示（右上角）
                        Text(currentImage.timestamp)
                            .font(.caption)
                            .foregroundColor(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(Color.black.opacity(0.8))
                            .cornerRadius(4)
                            .padding(.trailing, 7)  // 调整右边距以适应新的内边距
                    }
                    .padding(.top, 7),  // 调整顶部边距以适应新的内边距
                    alignment: .top
                )
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color(hex: "4784e1"), lineWidth: selectedImage?.id == currentImage.id ? 2 : 0)
                )
        }
    } else {
        Text(localization.localizedString("imageLoadFailed"))
            .foregroundColor(.red)
            .frame(width: geometry.size.width * 0.4 - 20, height: 80)
            .background(Color.gray.opacity(0.1))
            .cornerRadius(8)
    }
}

// 添加用于解析十六进制颜色的扩展
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
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

struct PhotoPicker: UIViewControllerRepresentable {
    @Binding var videoURL: URL?
    @Binding var isLoadingVideo: Bool
    @Binding var exportProgress: Float
    
    func makeUIViewController(context: Context) -> PHPickerViewController {
        var config = PHPickerConfiguration()
        config.filter = .videos
        config.selectionLimit = 1
        
        let picker = PHPickerViewController(configuration: config)
        picker.delegate = context.coordinator
        return picker
    }
    
    func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        return Coordinator(videoURL: $videoURL, isLoadingVideo: $isLoadingVideo, exportProgress: $exportProgress)
    }
    
    class Coordinator: NSObject, PHPickerViewControllerDelegate {
        @Binding var videoURL: URL?
        @Binding var isLoadingVideo: Bool
        @Binding var exportProgress: Float
        
        init(videoURL: Binding<URL?>, isLoadingVideo: Binding<Bool>, exportProgress: Binding<Float>) {
            _videoURL = videoURL
            _isLoadingVideo = isLoadingVideo
            _exportProgress = exportProgress
        }
        
        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            print("进入 picker 方法")
            picker.dismiss(animated: true)
            
            guard let result = results.first else {
                print("未选择视频")
                videoURL = nil
                return
            }
            
            // 打印详细信息
            print("选择的视频信息:")
            print("- itemProvider: \(result.itemProvider)")
            print("- assetIdentifier: \(String(describing: result.assetIdentifier))")
            print("- supportedContentTypes: \(result.itemProvider.registeredTypeIdentifiers)")
            print("- suggestedName: \(String(describing: result.itemProvider.suggestedName))")
            
            print("选择了视频，开始处理")
            isLoadingVideo = true
            self.exportProgress = 0
            
            // 检查文件类型
            let supportedTypes = result.itemProvider.registeredTypeIdentifiers
            if supportedTypes.contains("public.mpeg-4") {
                // 处理 MP4 文件
                handleMP4Video(result)
            } else if supportedTypes.contains("com.apple.quicktime-movie") {
                // 处理 MOV 文件
                handleMOVVideo(result)
            } else {
                print("不支持的文件类型")
                isLoadingVideo = false
                self.exportProgress = 0
            }
        }

        // 处理 MP4 文件 - 直接加载
        func handleMP4Video(_ result: PHPickerResult) {
            result.itemProvider.loadFileRepresentation(forTypeIdentifier: "public.mpeg-4") { [weak self] (url, error) in
                guard let self = self else { return }
                
                if let error = error {
                    print("加载MP4文件时出错: \(error)")
                    DispatchQueue.main.async {
                        self.isLoadingVideo = false
                        self.exportProgress = 0
                    }
                    return
                }
                
                guard let url = url else {
                    print("无法获取MP4文件URL")
                    DispatchQueue.main.async {
                        self.isLoadingVideo = false
                        self.exportProgress = 0
                    }
                    return
                }
                
                // 创建目标URL
                let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
                let destinationURL = documentsPath.appendingPathComponent(url.lastPathComponent)
                
                do {
                    // 如果目标位置已存在文件，先删除
                    if FileManager.default.fileExists(atPath: destinationURL.path) {
                        try FileManager.default.removeItem(at: destinationURL)
                    }
                    
                    // 复制文件到应用沙盒
                    try FileManager.default.copyItem(at: url, to: destinationURL)
                    
                    DispatchQueue.main.async {
                        self.videoURL = destinationURL
                        self.isLoadingVideo = false
                        self.exportProgress = 1.0
                    }
                } catch {
                    print("处理MP4文件时出错: \(error)")
                    DispatchQueue.main.async {
                        self.isLoadingVideo = false
                        self.exportProgress = 0
                    }
                }
            }
        }

        // 处理 MOV 文件 - 需要转码
        func handleMOVVideo(_ result: PHPickerResult) {
            result.itemProvider.loadFileRepresentation(forTypeIdentifier: "com.apple.quicktime-movie") { [weak self] (url, error) in
                guard let self = self else { return }
                
                if let error = error {
                    print("加载MOV文件时出错: \(error)")
                    DispatchQueue.main.async {
                        self.isLoadingVideo = false
                        self.exportProgress = 0
                    }
                    return
                }
                
                guard let url = url else {
                    print("无法获取MOV文件URL")
                    DispatchQueue.main.async {
                        self.isLoadingVideo = false
                        self.exportProgress = 0
                    }
                    return
                }
                
                // 创建目标URL
                let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
                let destinationURL = documentsPath.appendingPathComponent(url.lastPathComponent)
                
                do {
                    // 如果目标位置已存在文件，先删除
                    if FileManager.default.fileExists(atPath: destinationURL.path) {
                        try FileManager.default.removeItem(at: destinationURL)
                    }
                    
                    // 复制文件到应用沙盒
                    try FileManager.default.copyItem(at: url, to: destinationURL)
                    
                    DispatchQueue.main.async {
                        self.videoURL = destinationURL
                        self.isLoadingVideo = false
                        self.exportProgress = 1.0
                    }
                } catch {
                    print("处理MOV文件时出错: \(error)")
                    DispatchQueue.main.async {
                        self.isLoadingVideo = false
                        self.exportProgress = 0
                    }
                }
            }
        }
    }
}

struct SettingsSheet: View {
    @Binding var globalFields: [FieldInfo]
    @Environment(\.presentationMode) var presentationMode
    @EnvironmentObject private var localization: LocalizationManager
    let onFieldsUpdated: ([FieldInfo]) -> Void
    @State private var showingAddFieldSheet = false
    
    var body: some View {
        NavigationView {
            VStack {
                HStack {
                    Text(localization.localizedString("fieldSettings"))
                        .font(.headline)
                        .padding(.leading)
                    Spacer()
                    Button(localization.localizedString("save")) {
                        onFieldsUpdated(globalFields)
                        saveGlobalFieldsToFileSystem(globalFields)
                        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                        presentationMode.wrappedValue.dismiss()
                    }
                    .padding([.leading, .trailing], 16)
                    .padding([.top, .bottom], 10)
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(8)
                    .padding(.trailing)
                }
                .padding(.top)

                List {
                    ForEach(Array(globalFields.enumerated()), id: \.offset) { index, field in
                        HStack(alignment: .center, spacing: 12) {
                            // 左侧拖拽图标
                            Image(systemName: "line.horizontal.3")
                                .foregroundColor(.gray)
                                .font(.system(size: 14))
                                .frame(width: 20)
                            
                            // 右侧内容
                            VStack(spacing: 8) {
                                // 上方的类型和删除按钮
                                HStack {
                                    Text(field.type.rawValue)
                                        .font(.caption)
                                        .foregroundColor(.gray)
                                    Spacer()
                                    Button(action: {
                                        deleteField(at: IndexSet(integer: index))
                                    }) {
                                        Image(systemName: "trash")
                                            .foregroundColor(.red)
                                            .font(.system(size: 12))
                                            .frame(width: 16)
                                    }
                                }
                                
                                // 下方的输入框
                                TextField("表单标题", text: Binding(
                                    get: { globalFields[index].title },
                                    set: { newValue in
                                        globalFields[index].title = newValue
                                    }
                                ))
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                            }
                        }
                        .padding(.vertical, 8)
                        .padding(.horizontal, 4)
                        .background(Color.white)
                    }
                    .onMove(perform: moveField)
                }
                .listStyle(PlainListStyle())

                Button(action: { showingAddFieldSheet = true }) {
                    HStack {
                        Image(systemName: "plus")
                        Text(localization.localizedString("add"))
                    }
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(8)
                }
                .padding()
            }
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    TextField(localization.localizedString("formTitle"), text: Binding(
                        get: { 
                            // 获取当前正在编辑的字段的标题
                            if let focusedField = globalFields.first(where: { $0.title == "" }) {
                                return focusedField.title
                            }
                            return ""
                        },
                        set: { newValue in
                            // 更新当前正在编辑的字段的标题
                            if let index = globalFields.firstIndex(where: { $0.title == "" }) {
                                globalFields[index].title = newValue
                            }
                        }
                    ))
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .frame(minWidth: 0, maxWidth: .infinity)  // 确保输入框占据所有可用空间
                    
                    Button(localization.localizedString("done")) {
                        // 先让当前输入框失去焦点
                        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), 
                                                     to: nil, 
                                                     from: nil, 
                                                     for: nil)
                        
                        // 短暂延迟后再次确保键盘收起
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), 
                                                         to: nil, 
                                                         from: nil, 
                                                         for: nil)
                        }
                    }
                    .padding(.leading, 8)
                }
            }
        }
        .actionSheet(isPresented: $showingAddFieldSheet) {
            ActionSheet(
                title: Text(localization.localizedString("selectFieldType")),
                buttons: [
                    .default(Text(localization.localizedString("shotType"))) { 
                        addNewField(.shotType) 
                    },
                    .default(Text(localization.localizedString("cameraMovement"))) { 
                        addNewField(.cameraMovement) 
                    },
                    .default(Text(localization.localizedString("custom"))) { 
                        addNewField(.text) 
                    },
                    .cancel()
                ]
            )
        }
    }
    
    private func saveGlobalFieldsToFileSystem(_ fields: [FieldInfo]) {
        let fileName = "globalFields.json"
        let fileURL = getDocumentsDirectory().appendingPathComponent(fileName)
        
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = .prettyPrinted // 使JSON更易读
            
            let jsonData = try encoder.encode(fields)
            
            // 检查文件是否存在,如存在则先删除
            if FileManager.default.fileExists(atPath: fileURL.path) {
                try FileManager.default.removeItem(at: fileURL)
            }
            
            try jsonData.write(to: fileURL, options: .atomic)
            print("✅ globalFields 已成功保存到: \(fileURL.path)")
        } catch {
            print("❌ 保存 globalFields 失败: \(error.localizedDescription)")
        }
    }

    // 删除表单项
    private func deleteField(at indexSet: IndexSet) {
        globalFields.remove(atOffsets: indexSet)
    }

    // 移动表单项
    private func moveField(from source: IndexSet, to destination: Int) {
        globalFields.move(fromOffsets: source, toOffset: destination)
    }
    
    private func addNewField(_ type: FieldType) {
        let newField = FieldInfo(
            title: localization.localizedString(type == .shotType ? "shotType" : 
                                              type == .cameraMovement ? "cameraMovement" : 
                                              "custom"),
            value: "",
            key: UUID().uuidString,
            type: type
        )
        globalFields.append(newField)
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
            .environmentObject(LocalizationManager.shared)
    }
}
