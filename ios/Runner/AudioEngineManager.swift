import Foundation
import AVFoundation
import MediaPlayer
import Flutter

class AudioEngineManager: NSObject {
    static let shared = AudioEngineManager()
    
    // Core Audio Engine
    private let engine = AVAudioEngine()
    private let playerNodeA = AVAudioPlayerNode()
    private let playerNodeB = AVAudioPlayerNode()
    
    // State
    private var isPlayerAPrimary = true
    private var isPlaying = false
    private var crossfadeDuration: Double = 6.0
    private var currentFileA: AVAudioFile?
    private var currentFileB: AVAudioFile?
    
    // Flutter Bridge
    var channel: FlutterMethodChannel?
    
    private override init() {
        super.init()
        setupAudioSession()
        setupRemoteCommandCenter()
    }
    
    func setup(with messenger: FlutterBinaryMessenger) {
        channel = FlutterMethodChannel(name: "com.flowfade/audio", binaryMessenger: messenger)
        channel?.setMethodCallHandler({ [weak self] (call: FlutterMethodCall, result: @escaping FlutterResult) -> Void in
            self?.handleMethodCall(call, result: result)
        })
    }
    
    private func handleMethodCall(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "play":
            guard let args = call.arguments as? [String: Any],
                  let filePath = args["filePath"] as? String else {
                result(FlutterError(code: "INVALID_ARGUMENTS", message: "Missing filePath", details: nil))
                return
            }
            playTrack(at: filePath)
            result(nil)
            
        case "pause":
            pause()
            result(nil)
            
        case "resume":
            resume()
            result(nil)
            
        case "setCrossfadeDuration":
            guard let args = call.arguments as? [String: Any],
                  let duration = args["duration"] as? Double else {
                result(FlutterError(code: "INVALID_ARGUMENTS", message: "Missing duration", details: nil))
                return
            }
            self.crossfadeDuration = duration
            result(nil)
            
        case "extractMetadata":
            guard let args = call.arguments as? [String: Any],
                  let filePath = args["filePath"] as? String else {
                result(FlutterError(code: "INVALID_ARGUMENTS", message: "Missing filePath", details: nil))
                return
            }
            MetadataExtractor.shared.extractMetadata(from: filePath) { metadata in
                result(metadata)
            }
            
        default:
            result(FlutterMethodNotImplemented)
        }
    }
    
    private func setupAudioSession() {
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playback, mode: .default, options: [])
            try session.setActive(true)
            print("AudioEngineManager: Audio session configured for playback")
        } catch {
            print("AudioEngineManager: Failed to setup audio session: \(error)")
        }
    }
    
    private func setupRemoteCommandCenter() {
        let commandCenter = MPRemoteCommandCenter.shared()
        
        commandCenter.playCommand.addTarget { [weak self] event in
            self?.resume()
            return .success
        }
        
        commandCenter.pauseCommand.addTarget { [weak self] event in
            self?.pause()
            return .success
        }
        
        commandCenter.nextTrackCommand.addTarget { [weak self] event in
            self?.channel?.invokeMethod("nextTrack", arguments: nil)
            return .success
        }
        
        commandCenter.previousTrackCommand.addTarget { [weak self] event in
            self?.channel?.invokeMethod("previousTrack", arguments: nil)
            return .success
        }
    }
    
    // MARK: - Playback Controls
    
    func playTrack(at path: String) {
        print("AudioEngineManager: playTrack called with path: \(path)")
        
        let url = URL(fileURLWithPath: path)
        
        // Verify file exists
        guard FileManager.default.fileExists(atPath: path) else {
            print("AudioEngineManager: ERROR - File does not exist at \(path)")
            return
        }
        
        guard let file = try? AVAudioFile(forReading: url) else {
            print("AudioEngineManager: ERROR - Cannot read audio file at \(path)")
            return
        }
        
        let format = file.processingFormat
        print("AudioEngineManager: File format -> sampleRate: \(format.sampleRate), channels: \(format.channelCount)")
        
        // Stop everything and rebuild the engine graph with the correct format
        engine.stop()
        engine.reset()
        
        // Attach nodes fresh
        engine.attach(playerNodeA)
        engine.attach(playerNodeB)
        
        // Connect with the actual file format so there is no sample rate mismatch
        engine.connect(playerNodeA, to: engine.mainMixerNode, format: format)
        engine.connect(playerNodeB, to: engine.mainMixerNode, format: format)
        
        do {
            try engine.start()
            print("AudioEngineManager: Engine started successfully")
        } catch {
            print("AudioEngineManager: ERROR - Failed to start engine: \(error)")
            return
        }
        
        let primaryPlayer = isPlayerAPrimary ? playerNodeA : playerNodeB
        
        primaryPlayer.stop()
        primaryPlayer.scheduleFile(file, at: nil, completionHandler: nil)
        primaryPlayer.play()
        
        if isPlayerAPrimary {
            currentFileA = file
        } else {
            currentFileB = file
        }
        
        isPlaying = true
        print("AudioEngineManager: ✅ Playback started for \(url.lastPathComponent)")
        
        updateNowPlayingInfo(with: url)
    }
    
    func pause() {
        print("AudioEngineManager: pause()")
        if isPlayerAPrimary {
            playerNodeA.pause()
        } else {
            playerNodeB.pause()
        }
        isPlaying = false
    }
    
    func resume() {
        print("AudioEngineManager: resume()")
        if isPlayerAPrimary {
            playerNodeA.play()
        } else {
            playerNodeB.play()
        }
        isPlaying = true
    }
    
    private func updateNowPlayingInfo(with url: URL) {
        // Basic now-playing update
        var nowPlayingInfo = [String: Any]()
        nowPlayingInfo[MPMediaItemPropertyTitle] = url.deletingPathExtension().lastPathComponent
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nowPlayingInfo
    }
}
