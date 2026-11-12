enum YouTubeServiceFactory {
    static func makeDefault() -> any YouTubeServing {
        FirebaseYouTubeService()
    }
}
