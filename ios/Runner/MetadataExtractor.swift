import Foundation
import AVFoundation

class MetadataExtractor {
    static let shared = MetadataExtractor()
    
    private init() {}
    
    func extractMetadata(from filePath: String, completion: @escaping ([String: Any]) -> Void) {
        let url = URL(fileURLWithPath: filePath)
        let asset = AVAsset(url: url)
        
        var metadataDict: [String: Any] = [:]
        
        // Use loadValuesAsynchronously for modern iOS (we use Task for async/await)
        Task {
            do {
                let duration = try await asset.load(.duration)
                metadataDict["duration"] = duration.seconds
                
                let commonMetadata = try await asset.load(.commonMetadata)
                for item in commonMetadata {
                    if item.commonKey == .commonKeyTitle, let title = try await item.load(.stringValue) {
                        metadataDict["title"] = title
                    } else if item.commonKey == .commonKeyArtist, let artist = try await item.load(.stringValue) {
                        metadataDict["artist"] = artist
                    } else if item.commonKey == .commonKeyArtwork, let data = try await item.load(.dataValue) {
                        if let imagePath = saveArtworkLocally(data: data) {
                            metadataDict["artworkPath"] = imagePath
                        }
                    }
                }
                
                DispatchQueue.main.async {
                    completion(metadataDict)
                }
                
            } catch {
                print("MetadataExtractor: Failed to load metadata for \(filePath): \(error)")
                DispatchQueue.main.async {
                    completion(metadataDict)
                }
            }
        }
    }
    
    private func saveArtworkLocally(data: Data) -> String? {
        let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let uuid = UUID().uuidString
        let fileURL = documentsDirectory.appendingPathComponent("\(uuid)_artwork.jpg")
        
        do {
            try data.write(to: fileURL)
            return fileURL.path
        } catch {
            print("MetadataExtractor: Failed to save artwork data: \(error)")
            return nil
        }
    }
}
