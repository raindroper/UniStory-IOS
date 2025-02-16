import SwiftUI

struct SettingsPageView: View {
    @Environment(\.presentationMode) var presentationMode
    @EnvironmentObject private var localization: LocalizationManager
    
    var body: some View {
        List {
            // 检查更新
            Button(action: {
                // 处理检查更新
            }) {
                HStack {
                    Text(localization.localizedString("checkUpdate"))
                    Spacer()
                    Image(systemName: "chevron.right")
                        .foregroundColor(.gray)
                }
            }
            .foregroundColor(.black)
            
            // 反馈建议
            Button(action: {
                // 处理反馈建议
            }) {
                HStack {
                    Text(localization.localizedString("feedback"))
                    Spacer()
                    Image(systemName: "chevron.right")
                        .foregroundColor(.gray)
                }
            }
            .foregroundColor(.black)
            
            // 官方网站
            Button(action: {
                // 处理官方网站
            }) {
                HStack {
                    Text(localization.localizedString("officialWebsite"))
                    Spacer()
                    Image(systemName: "chevron.right")
                        .foregroundColor(.gray)
                }
            }
            .foregroundColor(.black)
        }
        .navigationTitle(localization.localizedString("settings"))
        .navigationBarTitleDisplayMode(.inline)
    }
} 