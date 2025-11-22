import Foundation
import AppKit
import FaviconFinder

// Responsible for locating, storing, and deleting favicon files on disk.
final class FaviconCache {
    static let shared = FaviconCache()

    private let fileManager = FileManager.default

    private lazy var cacheDirectory: URL? = {
        guard let base = fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first else {
            Logger.log("Failed to locate caches directory for favicon cache", level: .error)
            return nil
        }
        let dir = base.appendingPathComponent("RugburnFavicons", isDirectory: true)
        do {
            try fileManager.createDirectory(at: dir, withIntermediateDirectories: true)
        } catch {
            Logger.log("Failed to create favicon cache directory: \(error)", level: .error)
            return nil
        }
        return dir
    }()

    func fileURL(forFileName name: String) -> URL? {
        cacheDirectory?.appendingPathComponent(name)
    }

    func generateFileName(for url: URL) -> String {
        // Stable-ish hash based on full URL string. Collisions are harmless here.
        let hash = url.absoluteString.hashValue
        return "favicon_\(hash).png"
    }

    func removeFavicon(named name: String) {
        guard let url = fileURL(forFileName: name) else { return }
        do {
            try fileManager.removeItem(at: url)
        } catch {
            Logger.log("Failed to remove cached favicon at \(url.path): \(error)", level: .warning)
        }
    }
}

// Service that uses FaviconFinder to fetch and cache favicons for web apps.
final class FaviconService {
    static let shared = FaviconService()

    private let cache = FaviconCache.shared

    /// Fetch a favicon for the given item.
    /// - Returns: the cached file name and URL, or nil if no favicon is available.
    func fetchFavicon(for item: WebAppItem,
                      forceRefresh: Bool = false,
                      completion: @escaping (Result<(fileName: String, fileURL: URL)?, Error>) -> Void) {

        if !forceRefresh,
           let existingName = item.faviconFileName,
           let existingURL = cache.fileURL(forFileName: existingName),
           FileManager.default.fileExists(atPath: existingURL.path) {
            completion(.success((existingName, existingURL)))
            return
        }

        Task {
            do {
                let finder = FaviconFinder(url: item.url)
                let faviconURL = try await finder
                    .fetchFaviconURLs()
                    .largest()

                // largest() returns a FaviconURL; use its source URL to download the image
                let sourceURL = faviconURL.source

                let (data, _) = try await URLSession.shared.data(from: sourceURL)

                let fileName = self.cache.generateFileName(for: item.url)
                guard let fileURL = self.cache.fileURL(forFileName: fileName) else {
                    completion(.success(nil))
                    return
                }

                do {
                    try data.write(to: fileURL, options: .atomic)
                    completion(.success((fileName, fileURL)))
                } catch {
                    Logger.log("Failed to write favicon data to disk: \(error)", level: .error)
                    completion(.failure(error))
                }
            } catch {
                Logger.log("Favicon download failed for \(item.url): \(error)", level: .warning)
                completion(.success(nil))
            }
        }
    }
}
