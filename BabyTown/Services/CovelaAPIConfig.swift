import Foundation

enum CovelaAPIConfig {
    /// Override at runtime with the `COVELA_API_BASE_URL` environment variable (Xcode scheme).
    static var baseURL: URL {
        if let override = ProcessInfo.processInfo.environment["COVELA_API_BASE_URL"],
           let url = URL(string: override) {
            return url
        }
        // TODO: switch Release to https://api.covela.app/covela/api once that domain has DNS + SSL pointing at the backend.
        return URL(string: "https://pocketverse.herokuapp.com/covela/api")!
    }
}
