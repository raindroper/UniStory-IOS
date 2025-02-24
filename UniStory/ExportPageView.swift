import SwiftUI
import SwiftXLSX
import UIKit

struct ExportPageView: View {
    @Environment(\.presentationMode) var presentationMode
    @EnvironmentObject private var localization: LocalizationManager
    
    var screenList: [CurrentImage] // 接收的参数
    var globalFields: [FieldInfo]  // 接收的参数
    
    var body: some View {
        VStack {
            Text(localization.localizedString("export"))
                .font(.largeTitle)
                .padding()
            
            Button(action: {
                exportToExcel() // 调用 exportToExcel 方法
            }) {
                Text("开始导出")
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(8)
            }
            .padding()
            
            Spacer()
        }
        .navigationTitle(localization.localizedString("export"))
        .navigationBarTitleDisplayMode(.inline)
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
                let imageCellValue: XImageCell = XImageCell(key: XImages.append(with: image)!, size: CGSize(width: 200, height: 150))
                cell.value = .icon(imageCellValue)
            }
            
            // 动态设置单元格高度为 150
            sheet.ForRowSetHeight(row, 150)
            
            // 填充每个 globalField 对应的值
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
        
        // 修改保存逻辑：
        // 1. 保存时只传入文件名，让 SwiftXLSX 保存到内部临时目录
        let tempFilePath = book.save("example.xlsx")
        print("生成的临时文件路径：\(tempFilePath)")
        
        // 2. 构造目标路径：Documents 目录下的 example.xlsx
        guard let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            print("无法获取 Documents 目录")
            return
        }
        let destinationURL = documentsDirectory.appendingPathComponent("example.xlsx")
        
        // 3. 将临时文件复制到目标位置
        do {
            if FileManager.default.fileExists(atPath: destinationURL.path) {
                try FileManager.default.removeItem(at: destinationURL)
            }
            try FileManager.default.copyItem(atPath: tempFilePath, toPath: destinationURL.path)
            print("文件已成功复制到：\(destinationURL.path)")
        } catch {
            print("复制文件失败：\(error)")
            return
        }
        
        // 4. 检查目标文件存在后，使用 UIDocumentPickerViewController 导出
        if FileManager.default.fileExists(atPath: destinationURL.path) {
            print("文件存在，准备分享")
                let activityVC = UIActivityViewController(activityItems: [destinationURL], applicationActivities: nil)
                // iPad 上需要配置弹出框
                if let popoverController = activityVC.popoverPresentationController,
                   let rootViewController = UIApplication.shared.windows.first?.rootViewController {
                    popoverController.sourceView = rootViewController.view
                    popoverController.sourceRect = CGRect(x: rootViewController.view.bounds.midX,
                                                          y: rootViewController.view.bounds.midY,
                                                          width: 0, height: 0)
                    popoverController.permittedArrowDirections = []
                }
                
                if let rootViewController = UIApplication.shared.windows.first?.rootViewController {
                    rootViewController.present(activityVC, animated: true, completion: nil)
                }
        } else {
            print("文件不存在，无法导出")
        }
    }
}
