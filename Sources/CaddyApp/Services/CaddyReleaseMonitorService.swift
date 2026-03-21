import Foundation

struct CaddyReleaseMonitorService {
    private var session: URLSession {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 5
        configuration.timeoutIntervalForResource = 5
        return URLSession(configuration: configuration)
    }

    func fetchLatestRelease() async -> CaddyReleaseInfo? {
        guard let url = URL(string: "https://api.github.com/repos/caddyserver/caddy/releases/latest") else {
            return nil
        }

        var request = URLRequest(url: url)
        request.setValue("CaddyApp/0.1", forHTTPHeaderField: "User-Agent")

        do {
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
                return nil
            }
            let payload = try JSONDecoder().decode(GitHubReleasePayload.self, from: data)
            return CaddyReleaseInfo(tagName: payload.tagName, publishedAt: payload.publishedAt, url: payload.htmlURL)
        } catch {
            return nil
        }
    }
}

private struct GitHubReleasePayload: Decodable {
    let tagName: String
    let publishedAt: Date?
    let htmlURL: URL?

    enum CodingKeys: String, CodingKey {
        case tagName = "tag_name"
        case publishedAt = "published_at"
        case htmlURL = "html_url"
    }
}
