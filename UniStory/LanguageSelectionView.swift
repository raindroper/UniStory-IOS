import SwiftUI

struct LanguageSelectionView: View {
    @Environment(\.presentationMode) var presentationMode
    @EnvironmentObject private var localization: LocalizationManager
    
    var body: some View {
        List {
            Button(action: {
                localization.currentLanguage = "中文"
                presentationMode.wrappedValue.dismiss()
            }) {
                HStack {
                    Text("中文")
                    Spacer()
                    if localization.currentLanguage == "中文" {
                        Image(systemName: "checkmark")
                            .foregroundColor(.blue)
                    }
                }
            }
            .foregroundColor(.black)
            
            Button(action: {
                localization.currentLanguage = "English"
                presentationMode.wrappedValue.dismiss()
            }) {
                HStack {
                    Text("English")
                    Spacer()
                    if localization.currentLanguage == "English" {
                        Image(systemName: "checkmark")
                            .foregroundColor(.blue)
                    }
                }
            }
            .foregroundColor(.black)
        }
        .navigationTitle(localization.localizedString("selectLanguage"))
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct LanguageSelectionView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            LanguageSelectionView()
        }
    }
} 