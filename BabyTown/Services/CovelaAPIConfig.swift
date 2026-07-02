import Foundation

enum CovelaAPIConfig {
    /// Override at runtime with the `COVELA_API_BASE_URL` environment variable (Xcode scheme).
    static var baseURL: URL {
        if let override = ProcessInfo.processInfo.environment["COVELA_API_BASE_URL"],
           let url = URL(string: override) {
            return url
        }
        #if DEBUG
        return URL(string: "https://pocketverse.herokuapp.com/covela/api")!
        #else
        return URL(string: "https://api.covela.app/covela/api")!
        #endif
    }
}
