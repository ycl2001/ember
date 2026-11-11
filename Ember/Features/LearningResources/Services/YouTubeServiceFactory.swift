import Foundation

enum YouTubeServiceFactory {
    /// Configure `YouTubeProxyBaseURL` through an uncommitted xcconfig or CI build setting.
    static func makeDefault(bundle: Bundle = .main) -> any YouTubeServing {
        guard let value = bundle.object(forInfoDictionaryKey: "YouTubeProxyBaseURL") as? String,
              let url = URL(string: value),
              url.scheme == "https",
              url.host != nil else {
            return UnavailableYouTubeService()
        }
        return YouTubeProxyService(baseURL: url)
    }
}
