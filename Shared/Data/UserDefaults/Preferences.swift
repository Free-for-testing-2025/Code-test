import Foundation
import UIKit

enum Preferences {
    static var installPathChangedCallback: ((String?) -> Void)?
    static let defaultInstallPath: String = "https://api.palera.in"

    @Storage(key: "Backdoor.UserSpecifiedOnlinePath", defaultValue: defaultInstallPath)
    static var onlinePath: String? { didSet { installPathChangedCallback?(onlinePath) } }

    @Storage(key: "Backdoor.UserSelectedServer", defaultValue: false)
    static var userSelectedServer: Bool

    @Storage(key: "Backdoor.DefaultRepos", defaultValue: false)
    static var defaultRepos: Bool

    @Storage(key: "Backdoor.AppUpdates", defaultValue: false)
    static var appUpdates: Bool

    @Storage(key: "Backdoor.gotSSLCerts", defaultValue: false)
    static var gotSSLCerts: Bool

    @Storage(key: "Backdoor.BDefaultRepos", defaultValue: false)
    static var bDefaultRepos: Bool

    @Storage(key: "Backdoor.userIntefacerStyle", defaultValue: UIUserInterfaceStyle.unspecified.rawValue)
    static var preferredInterfaceStyle: Int

    @CodableStorage(key: "Backdoor.AppTintColor", defaultValue: CodableColor(UIColor(hex: "FF0000")))
    static var appTintColor: CodableColor

    @Storage(key: "Backdoor.OnboardingActive", defaultValue: true)
    static var isOnboardingActive: Bool

    @Storage(key: "Backdoor.selectedCert", defaultValue: 0)
    static var selectedCert: Int

    @Storage(key: "Backdoor.ppqcheckBypass", defaultValue: "")
    static var pPQCheckString: String

    @Storage(key: "Backdoor.CertificateTitleAppIDtoTeamID", defaultValue: false)
    static var certificateTitleAppIDtoTeamID: Bool

    @Storage(key: "Backdoor.AppDescriptionAppearence", defaultValue: 0)
    static var appDescriptionAppearence: Int

    @Storage(key: "UserPreferredLanguageCode", defaultValue: nil, callback: preferredLangChangedCallback)
    static var preferredLanguageCode: String?

    @Storage(key: "Backdoor.Beta", defaultValue: false)
    static var beta: Bool

    @CodableStorage(key: "SortOption", defaultValue: SortOption.default)
    static var currentSortOption: SortOption

    @Storage(key: "SortOptionAscending", defaultValue: true)
    static var currentSortOptionAscending: Bool

    // New SigningOptions struct and property
    struct SigningOptions: CustomStringConvertible {
        let selectedCertificateIndex: Int
        let useAppIDtoTeamID: Bool

        var description: String {
            return "Selected Certificate Index: \(selectedCertificateIndex), Use AppID to TeamID: \(useAppIDtoTeamID)"
        }
    }

    static var signingOptions: SigningOptions {
        return SigningOptions(
            selectedCertificateIndex: selectedCert,
            useAppIDtoTeamID: certificateTitleAppIDtoTeamID
        )
    }
}

// MARK: - Callbacks

private extension Preferences {
    static func preferredLangChangedCallback(newValue: String?) {
        Bundle.preferredLocalizationBundle = .makeLocalizationBundle(preferredLanguageCode: newValue)
    }
}

// MARK: - Color

struct CodableColor: Codable {
    let red: CGFloat
    let green: CGFloat
    let blue: CGFloat
    let alpha: CGFloat

    var uiColor: UIColor {
        return UIColor(red: red, green: green, blue: blue, alpha: alpha)
    }

    init(_ color: UIColor) {
        var _red: CGFloat = 0, _green: CGFloat = 0, _blue: CGFloat = 0, _alpha: CGFloat = 0

        color.getRed(&_red, green: &_green, blue: &_blue, alpha: &_alpha)

        red = _red
        blue = _blue
        green = _green
        alpha = _alpha
    }
}
