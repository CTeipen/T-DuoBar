import Foundation

func localized(_ key: String) -> String {
    AppLocalization.string(key, language: AppLocalization.language)
}

func localized(_ key: String, _ arguments: CVarArg...) -> String {
    String(format: localized(key), locale: AppLocalization.language.locale, arguments: arguments)
}
