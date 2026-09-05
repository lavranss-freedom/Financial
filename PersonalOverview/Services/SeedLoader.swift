import Foundation

enum SeedLoader {
    static func loadBundled() throws -> AppData {
        guard let url = Bundle.main.url(forResource: "SeedData", withExtension: "json") else {
            throw SeedError.missingFile
        }
        let data = try Data(contentsOf: url)
        let decoder = JSONDecoder()
        return try decoder.decode(AppData.self, from: data)
    }

    enum SeedError: LocalizedError {
        case missingFile
        var errorDescription: String? {
            switch self {
            case .missingFile: return "SeedData.json missing from app bundle"
            }
        }
    }
}
