import Foundation
import AVFoundation
import MediaPlayer
import Flutter

class AudioEngineManager: NSObject {
    static let shared = AudioEngineManager()
    
    // Core Audio Engine
    private let engine = AVAudioEngine()
    private let mixerNode = AVAudioMixerNode()
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
        setupEngine()
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
    
    private func setupEngine() {
        engine.attach(playerNodeA)
        engine.attach(playerNodeB)
        engine.attach(mixerNode)
        
        engine.connect(playerNodeA, to: mixerNode, format: nil)
        engine.connect(playerNodeB, to: mixerNode, format: nil)
        engine.connect(mixerNode, to: engine.mainMixerNode, format: nil)
        
        do {
            try engine.start()
        } catch {
            print("AudioEngineManager: Failed to start engine: \(error)")
        }
    }
    
    private func setupAudioSession() {
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playback, mode: .default, options: [])
            try session.setActive(true)
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
        let url = URL(fileURLWithPath: path)
        guard let file = try? AVAudioFile(forReading: url) else {
            print("AudioEngineManager: Cannot read file at \(path)")
            return
        }
        
        let primaryPlayer = isPlayerAPrimary ? playerNodeA : playerNodeB
        
        primaryPlayer.stop()
        primaryPlayer.scheduleFile(file, at: nil, completionHandler: nil)
        
        if isPlayerAPrimary {
            currentFileA = file
        } else {
            currentFileB = file
        }
        
        primaryPlayer.play()
        isPlaying = true
        
        // Setup crossfade timer logic here...
        // For the sake of the initial scaffolding, we will just play.
        // Equal power crossfade schedule logic will go here.
        updateNowPlayingInfo(with: url)
    }
    
    func pause() {
        if isPlayerAPrimary {
            playerNodeA.pause()
        } else {
            playerNodeB.pause()
        }
        isPlaying = false
    }
    
    func resume() {
        if isPlayerAPrimary {
            playerNodeA.play()
        } else {
            playerNodeB.play()
        }
        isPlaying = true
    }
    
    private func updateNowPlayingInfo(with url: URL) {
        // We will update MPNowPlayingInfoCenter here or from Flutter
        // via a separate channel method receiving artist/title metadata
    }
}
