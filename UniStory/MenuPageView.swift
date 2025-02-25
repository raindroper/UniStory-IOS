import SwiftUI

struct MenuPageView: View {
    @Environment(\.presentationMode) var presentationMode
    @Binding var isSettingsActive: Bool
    @Binding var isLanguageActive: Bool
    @EnvironmentObject private var localization: LocalizationManager
    
    var body: some View {
        VStack(spacing: 0) {
            // 第一组按钮
            VStack(spacing: 0) {
                Button(action: {
                    // 处理导入操作
                    presentationMode.wrappedValue.dismiss()
                }) {
                    HStack {
                        Image(systemName: "square.and.arrow.down")
                            .foregroundColor(.black)
                            .frame(width: 20)
                        Text(localization.localizedString("import"))
                            .foregroundColor(.black)
                        Spacer()
                    }
                    .padding(.vertical, 12)
                }
            }
            .padding(.horizontal, 25)
            .background(Color(red: 1, green: 1, blue: 1))
            .cornerRadius(10)
            .padding(.horizontal, 25)
            .padding(.top, 20)
            
            // 第二组按钮
            VStack(spacing: 0) {
                NavigationLink(destination: SettingsPageView()) {
                    HStack {
                        Image(systemName: "gearshape")
                            .foregroundColor(.black)
                            .frame(width: 20)
                        Text(localization.localizedString("settings"))
                            .foregroundColor(.black)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .foregroundColor(.gray)
                            .font(.system(size: 14))
                    }
                    .padding(.vertical, 12)
                }
                
                NavigationLink(destination: LanguageSelectionView()) {
                    HStack {
                        Image(systemName: "globe")
                            .foregroundColor(.black)
                            .frame(width: 20)
                        Text(localization.localizedString("language"))
                            .foregroundColor(.black)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .foregroundColor(.gray)
                            .font(.system(size: 14))
                    }
                    .padding(.vertical, 12)
                }
            }
            .padding(.horizontal, 25)
            .background(Color(red: 1, green: 1, blue: 1))
            .cornerRadius(10)
            .padding(.horizontal, 25)
            .padding(.top, 19)
            
            Spacer()
        }
        .background(Color(red: 0.98, green: 0.98, blue: 0.98))
        .navigationTitle(localization.localizedString("menu"))
        .navigationBarTitleDisplayMode(.inline)
    }
} 