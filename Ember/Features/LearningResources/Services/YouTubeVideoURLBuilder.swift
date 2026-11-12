import Foundation

enum YouTubeVideoURLBuilder {
    static func isValidVideoID(_ value: String) -> Bool {
        value.count == 11 && value.allSatisfy { $0.isLetter || $0.isNumber || $0 == "_" || $0 == "-" }
    }

    static func url(videoID: String, startSeconds: Int = 0) -> URL? {
        guard isValidVideoID(videoID), startSeconds >= 0 else { return nil }
        var components = URLComponents(string: "https://www.youtube.com/watch")
        var queryItems = [URLQueryItem(name: "v", value: videoID)]
        if startSeconds > 0 {
            queryItems.append(URLQueryItem(name: "t", value: "\(startSeconds)s"))
        }
        components?.queryItems = queryItems
        return components?.url
    }

    static func validatedVideoURL(_ url: URL) -> URL? {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              components.scheme?.lowercased() == "https",
              components.user == nil,
              components.password == nil,
              components.port == nil,
              let host = components.host?.lowercased() else {
            return nil
        }

        let pathParts = components.path.split(separator: "/").map(String.init)
        switch host {
        case "youtu.be", "www.youtu.be":
            guard pathParts.count == 1, isValidVideoID(pathParts[0]) else { return nil }
        case "youtube.com", "www.youtube.com", "m.youtube.com":
            if components.path == "/watch" {
                let videoID = components.queryItems?.first { $0.name == "v" }?.value
                guard let videoID, isValidVideoID(videoID) else { return nil }
            } else {
                guard pathParts.count == 2,
                      pathParts[0].lowercased() == "shorts",
                      isValidVideoID(pathParts[1]) else {
                    return nil
                }
            }
        default:
            return nil
        }

        return url
    }
}
