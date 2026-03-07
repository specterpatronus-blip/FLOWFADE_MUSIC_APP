import Foundation
import AVFoundation

class MetadataExtractor {
    static let shared = MetadataExtractor()
    
    private init() {}
    
    func extractMetadata(from filePath: String, completion: @escaping ([String: Any]) -> Void) {
        let url = URL(fileURLWithPath: filePath)
        let asset = AVAsset(url: url)
        
        var metadataDict: [String: Any] = [:]
        
        let keys = ["duration", "commonMetadata"]
        asset.loadValuesAsynchronously(forKeys: keys) {
            var metadataDict: [String: Any] = [:]
            
            var error: NSError? = nil
            let status = asset.statusOfValue(forKey: "commonMetadata", error: &error)
            
            if status == .loaded {
                metadataDict["duration"] = asset.duration.seconds
                
                for item in asset.commonMetadata {
                    if item.commonKey == .commonKeyTitle, let title = item.stringValue {
                        metadataDict["title"] = title
                    } else if item.commonKey == .commonKeyArtist, let artist = item.stringValue {
                        metadataDict["artist"] = artist
                    } else if item.commonKey == .commonKeyArtwork, let data = item.dataValue {
                        if let imagePath = self.saveArtworkLocally(data: data) {
                            metadataDict["artworkPath"] = imagePath
                        }
                    }
                }
            } else {
                print("MetadataExtractor: Failed to load metadata for \(filePath): \(String(describing: error))")
            }
            
            DispatchQueue.main.async {
                completion(metadataDict)
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
