import SwiftUI
import PhotosUI
import AVKit
import AVFoundation

import SwiftXLSX
import Foundation


struct FieldInfo: Identifiable, Codable {
    let id = UUID()
    var title: String
    var value: String
    var key: String // 全局唯一
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
    
    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                // 顶部导航栏
                HStack {
                    // 左侧按钮
                    HStack(spacing: 0) {
                        Button(action: {
                            print("Hamburger menu tapped")
                        }) {
                            Image(systemName: "line.horizontal.3")
                                .font(.system(size: 24))
                                .foregroundColor(.black)
                                .padding(16)
                        }
                        
                        Button(action: {
                            showPicker = true
                        }) {
                            Text("加载本地视频")
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
                        exportToExcel()
                    }) {
                        Text("导出")
                            .font(.system(size: 16))
                            .foregroundColor(.white)
                            .padding()
                            .background(Color.blue)
                            .cornerRadius(8)
                    }
                    .padding(.trailing, 16)
                }
                .frame(height: 64)
                .background(Color.white)
                .shadow(radius: 4)
                // 视频播放器或占位符
                if let videoURL = videoURL {
                    VideoPlayer(player: player)
                        .frame(width: geometry.size.width, height: geometry.size.width * 3 / 4)
                        .onAppear {
                            player = AVPlayer(url: videoURL)
                            player?.play()
                        }
                } else {
                    Text("请选择一个视频")
                        .foregroundColor(.gray)
                        .frame(width: geometry.size.width, height: geometry.size.width * 3 / 4)
                        .background(Color.black.opacity(0.1))
                }
                
                HStack(spacing: 0) {
                    ScrollView {
                        VStack(spacing: 10) {
                            ForEach(screenList) { currentImage in
                                screenListItemView(for: currentImage, geometry: geometry, onTap: { selected in
                                    selectedImage = selected
                                })
                            }
                        }
                        .padding()
                    }
                    .frame(width: geometry.size.width * 0.4)
                    .background(Color.gray.opacity(0.05))
                    
                    VStack(alignment: .leading, spacing: 10) {
                        if let selected = selectedImage {
                        HStack(spacing: 0) {
                            Text("分镜号：\(selected.lensNumber)")
                            Spacer()
                            Button(action: {
                                isSettingsSheetPresented = true
                            }) {
                                Image(systemName: "gearshape")
                                    .foregroundColor(.blue)
                            }
                            Button(action: {
                                showDeleteConfirmation = true
                            }) {
                                Image(systemName: "trash")
                                    .foregroundColor(.blue)
                            }
                        }
                        HStack(spacing: 0) {
                            Text("时间：\(selected.timestamp)")
                            Spacer()
                            Button(action: {
                                jumpVideoToTime(time: selected.timestamp)
                            }) {
                                Text("跳转到此时间")
                            }
                        }
                        .padding([.top, .trailing])
                        ForEach(Array(selected.fields.enumerated()), id: \.offset) { index, field in
                                VStack(alignment: .leading) {
                                    Text(field.title)
                                        .font(.subheadline)
                                        .foregroundColor(.gray)

                                    TextField("请输入内容", text: Binding(
                                        get: { selectedImage?.fields[index].value ?? "" },
                                        set: { newValue in
                                            selectedImage?.fields[index].value = newValue
                                        }
                                    ))
                                    .textFieldStyle(RoundedBorderTextFieldStyle())
                                    .padding([.leading, .trailing])
                                    .onChange(of: selectedImage?.fields[index].value ?? "") {
                                        saveChanges()
                                    }
                                }
                            }
                        } else {
                            Text("请选择一张图片")
                                .foregroundColor(.gray)
                                .padding()
                        }
                    }
                    .frame(width: geometry.size.width * 0.6)
                    .background(Color.white)
                    .frame(maxHeight: .infinity, alignment: .top)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                HStack(spacing: 10) {
                    if let screenshotImage = screenshotImage {
                        Image(uiImage: screenshotImage)
                            .resizable()
                            .scaledToFit()
                            .frame(height: 200)
                            .padding()
                    } else {
                        Text("请先截图")
                            .foregroundColor(.gray)
                            .frame(width: 100, height: 60)
                            .background(Color.black.opacity(0.1))
                    }
                    
                    VStack(alignment: .leading, spacing: 5) {
                        Text("时间: \(formatVideoTime(screenShotTime ?? CMTime(seconds: 0, preferredTimescale: 1)))")
                        HStack(spacing: 4) {
                            Text("镜号: \(currentSeq)")
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
                            Text("截图")
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
                            Text("插入")
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
            }
        }
        .sheet(isPresented: $showPicker) {
            PhotoPicker(videoURL: $videoURL)
        }
        .sheet(isPresented: $isSettingsSheetPresented) {
            SettingsSheet(globalFields: $globalFields) { updatedFields in
                globalFields = updatedFields
                syncGlobalFieldsToImages() // 同步所有图片的字段
                
                // 更新当前选中图片的字段
                if let selectedIndex = screenList.firstIndex(where: { $0.id == selectedImage?.id }) {
                    selectedImage = screenList[selectedIndex]
                }
            }
        }

        .background(Color.white)
        .edgesIgnoringSafeArea(.horizontal)
        .onAppear {
            // 加载图片列表
            screenList = loadScreenListFromFileSystem()
            globalFields = loadGlobalFieldsFromFileSystem() // 加载全局字段
            
            // 如果 screenList 不为空，默认选择第一项
            if !screenList.isEmpty {
                selectedImage = screenList[0]
            }
        }
        .alert(isPresented: $showDeleteConfirmation) {
            Alert(
                title: Text("确认删除"),
                message: Text("您确定要删除这张图片吗？"),
                primaryButton: .destructive(Text("删除")) {
                    deleteImage()
                },
                secondaryButton: .cancel()
            )
        }
        .alert("修改镜号", isPresented: $showLensNumberInput) {
            TextField("请输入新镜号", text: $newLensNumber)
                .keyboardType(.numberPad)
            Button("取消", role: .cancel) {
                showLensNumberInput = false
            }
            Button("确认") {
                if let newNumber = Int(newLensNumber),
                   let tempImage = tempScreenForLensChange {
                    updateLensNumber(for: tempImage, to: newNumber)
                }
                showLensNumberInput = false
            }
        } message: {
            Text("请输入1-\(screenList.count + 1)之间的数字")
        }
    }
    
    func exportToExcel() {
        let book = XWorkBook()
        let sheet = book.NewSheet("Export")
        
        // 添加标题行
        var cell = sheet.AddCell(XCoords(row: 1, col: 1))
        cell.value = .text("镜号")
        cell = sheet.AddCell(XCoords(row: 1, col: 2))
        cell.value = .text("时间")
        cell = sheet.AddCell(XCoords(row: 1, col: 3))
        cell.value = .text("视频截图")
        
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
//                let resizedImage = resizeImage(image, to: CGSize(width: 200, height: 150)) // 调整图片大小
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
                    return FieldInfo(title: globalField.title, value: existingField.value, key: globalField.key)
                } else {
                    return FieldInfo(title: globalField.title, value: "", key: globalField.key)
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
            return fields
        } catch {
            print("加载 globalFields 失败：\(error.localizedDescription)")
            return []
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
                        FieldInfo(title: globalField.title, value: "", key: globalField.key)
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
                    FieldInfo(title: globalField.title, value: "", key: globalField.key)
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
}


// 获取沙盒目录径
func getDocumentsDirectory() -> URL {
    FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
}

@ViewBuilder
private func screenListItemView(for currentImage: CurrentImage, geometry: GeometryProxy, onTap: @escaping (CurrentImage) -> Void) -> some View {
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
                .overlay(
                    Text("\(currentImage.lensNumber)")
                        .font(.caption)
                        .foregroundColor(.white)
                        .padding(5)
                        .background(Color.black)
                        .clipShape(Circle())
                        .padding(.leading, 4),
                    alignment: .topLeading
                )
        }
    } else {
        Text("图片加载失败")
            .foregroundColor(.red)
            .frame(width: geometry.size.width * 0.4 - 20, height: 80)
            .background(Color.gray.opacity(0.1))
            .cornerRadius(8)
    }
}


struct PhotoPicker: UIViewControllerRepresentable {
    @Binding var videoURL: URL?
    
    func makeUIViewController(context: Context) -> PHPickerViewController {
        var config = PHPickerConfiguration()
        config.filter = .videos // 仅显示视频
        config.selectionLimit = 1 // 限制为单个视频
        
        let picker = PHPickerViewController(configuration: config)
        picker.delegate = context.coordinator
        return picker
    }
    
    func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        return Coordinator(videoURL: $videoURL)
    }
    
    class Coordinator: NSObject, PHPickerViewControllerDelegate {
        @Binding var videoURL: URL?
        
        init(videoURL: Binding<URL?>) {
            _videoURL = videoURL
        }
        
        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            picker.dismiss(animated: true)
            
            guard let result = results.first,
                  result.itemProvider.hasItemConformingToTypeIdentifier("public.movie") else {
                videoURL = nil
                return
            }
            
            result.itemProvider.loadDataRepresentation(forTypeIdentifier: "public.movie") { data, error in
                DispatchQueue.main.async {
                    if let data = data {
                        // 创建临时文件
                        let temporaryDirectoryURL = FileManager.default.temporaryDirectory
                        let tempVideoURL = temporaryDirectoryURL.appendingPathComponent(UUID().uuidString).appendingPathExtension("mov")
                        
                        do {
                            try data.write(to: tempVideoURL)
                            self.videoURL = tempVideoURL
                        } catch {
                            print("Error writing video data: \(error.localizedDescription)")
                            self.videoURL = nil
                        }
                    } else {
                        print("Error loading video: \(error?.localizedDescription ?? "Unknown error")")
                        self.videoURL = nil
                    }
                }
            }
        }
    }
}

struct SettingsSheet: View {
    @Binding var globalFields: [FieldInfo] // 全局表单项
    @Environment(\.presentationMode) var presentationMode
    let onFieldsUpdated: ([FieldInfo]) -> Void // 回调：字段更新时触发

    var body: some View {
        NavigationView {
            VStack {
                HStack {
                    Text("字段设置（拖动排序）")
                        .font(.headline)
                        .padding(.leading)
                    Spacer()
                    Button("保存") {
                        onFieldsUpdated(globalFields) // 回调更新字段
                        saveGlobalFieldsToFileSystem(globalFields) // 保存到本地
                        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                        presentationMode.wrappedValue.dismiss()
                    }
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(8)
                    .padding(.trailing)
                }
                .padding(.top)

                List {
                    ForEach(Array(globalFields.enumerated()), id: \.offset) { index, field in
                        HStack {
                            Image(systemName: "line.horizontal.3")
                                .foregroundColor(.gray)
                            TextField("表单标题", text: Binding(
                                get: { globalFields[index].title },
                                set: { newValue in
                                    globalFields[index].title = newValue
                                }
                            ))
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            
                            Spacer()
                            
                            Button(action: {
                                deleteField(at: IndexSet(integer: index))
                            }) {
                                Image(systemName: "trash")
                                    .foregroundColor(.red)
                            }
                        }
                        .padding(.vertical, 5)
                    }
                    .onMove(perform: moveField)
                }
                .listStyle(PlainListStyle())

                Button(action: addNewField) {
                    HStack {
                        Image(systemName: "plus")
                        Text("添加")
                    }
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(8)
                }
                .padding()
            }
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

    // 新增表单项
    private func addNewField() {
        let newField = FieldInfo(title: "新表单项", value: "", key: UUID().uuidString)
        globalFields.append(newField)
    }
    
    // 移动表单项
    private func moveField(from source: IndexSet, to destination: Int) {
        globalFields.move(fromOffsets: source, toOffset: destination)
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
