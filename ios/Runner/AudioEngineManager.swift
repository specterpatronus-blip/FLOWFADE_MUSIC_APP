import Foundation
import AVFoundation
import MediaPlayer
import Flutter

class AudioEngineManager: NSObject, AVAudioPlayerDelegate {
    static let shared = AudioEngineManager()
    
    // Use AVAudioPlayer for reliable playback
    private var audioPlayer: AVAudioPlayer?
    
    // State
    private var isPlaying = false
    private var crossfadeDuration: Double = 6.0
    
    // Flutter Bridge
    var channel: FlutterMethodChannel?
    
    private override init() {
        super.init()
        setupAudioSession()
        setupRemoteCommandCenter()
        print("AudioEngineManager: Initialized with AVAudioPlayer")
    }
    
    func setup(with messenger: FlutterBinaryMessenger) {
        channel = FlutterMethodChannel(name: "com.flowfade/audio", binaryMessenger: messenger)
        channel?.setMethodCallHandler({ [weak self] (call: FlutterMethodCall, result: @escaping FlutterResult) -> Void in
            self?.handleMethodCall(call, result: result)
        })
        print("AudioEngineManager: MethodChannel 'com.flowfade/audio' registered")
    }
    
    private func handleMethodCall(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        print("AudioEngineManager: Received method call: \(call.method)")
        
        switch call.method {
        case "play":
            guard let args = call.arguments as? [String: Any],
                  let filePath = args["filePath"] as? String else {
                print("AudioEngineManager: ERROR - Missing filePath argument")
                result(FlutterError(code: "INVALID_ARGUMENTS", message: "Missing filePath", details: nil))
                return
            }
            print("AudioEngineManager: play() called with: \(filePath)")
            let success = playTrack(at: filePath)
            if success {
                result(nil)
            } else {
                result(FlutterError(code: "PLAYBACK_ERROR", message: "Failed to play file", details: filePath))
            }
            
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
    
    // MARK: - Audio Session
    
    private func setupAudioSession() {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default, options: [])
            try session.setActive(true)
            print("AudioEngineManager: ✅ Audio session active (.playback)")
        } catch {
            print("AudioEngineManager: ❌ Audio session error: \(error)")
        }
    }
    
    // MARK: - Remote Command Center
    
    private func setupRemoteCommandCenter() {
        let commandCenter = MPRemoteCommandCenter.shared()
        
        commandCenter.playCommand.addTarget { [weak self] _ in
            self?.resume()
            return .success
        }
        commandCenter.pauseCommand.addTarget { [weak self] _ in
            self?.pause()
            return .success
        }
        commandCenter.nextTrackCommand.addTarget { [weak self] _ in
            self?.channel?.invokeMethod("nextTrack", arguments: nil)
            return .success
        }
        commandCenter.previousTrackCommand.addTarget { [weak self] _ in
            self?.channel?.invokeMethod("previousTrack", arguments: nil)
            return .success
        }
    }
    
    // MARK: - Playback Controls
    
    func playTrack(at path: String) -> Bool {
        print("AudioEngineManager: playTrack() path: \(path)")
        
        // 1. Verify file exists
        let fileManager = FileManager.default
        guard fileManager.fileExists(atPath: path) else {
            print("AudioEngineManager: ❌ File NOT found at: \(path)")
            return false
        }
        print("AudioEngineManager: ✅ File exists")
        
        // 2. Get file size for verification
        if let attrs = try? fileManager.attributesOfItem(atPath: path),
           let size = attrs[.size] as? UInt64 {
            print("AudioEngineManager: File size: \(size) bytes")
        }
        
        // 3. Create URL and AVAudioPlayer
        let url = URL(fileURLWithPath: path)
        
        do {
            // Stop any previous playback
            audioPlayer?.stop()
            audioPlayer = nil
            
            // Create the player
            let player = try AVAudioPlayer(contentsOf: url)
            player.delegate = self
            player.prepareToPlay()
            
            print("AudioEngineManager: AVAudioPlayer created - duration: \(player.duration)s, channels: \(player.numberOfChannels)")
            
            let started = player.play()
            if started {
                audioPlayer = player
                isPlaying = true
                print("AudioEngineManager: ✅ PLAYBACK STARTED for \(url.lastPathComponent)")
                updateNowPlayingInfo(title: url.deletingPathExtension().lastPathComponent, duration: player.duration)
                return true
            } else {
                print("AudioEngineManager: ❌ player.play() returned false")
                return false
            }
        } catch {
            print("AudioEngineManager: ❌ AVAudioPlayer init error: \(error.localizedDescription)")
            return false
        }
    }
    
    func pause() {
        audioPlayer?.pause()
        isPlaying = false
        print("AudioEngineManager: ⏸ Paused")
    }
    
    func resume() {
        audioPlayer?.play()
        isPlaying = true
        print("AudioEngineManager: ▶️ Resumed")
    }
    
    // MARK: - AVAudioPlayerDelegate
    
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        print("AudioEngineManager: Track finished (success: \(flag))")
        isPlaying = false
        // Notify Flutter that the track ended
        channel?.invokeMethod("nextTrack", arguments: nil)
    }
    
    func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: Error?) {
        print("AudioEngineManager: ❌ Decode error: \(String(describing: error))")
    }
    
    // MARK: - Now Playing Info
    
    private func updateNowPlayingInfo(title: String, duration: TimeInterval) {
        var info = [String: Any]()
        info[MPMediaItemPropertyTitle] = title
        info[MPMediaItemPropertyPlaybackDuration] = duration
        info[MPNowPlayingInfoPropertyElapsedPlaybackTime] = 0.0
        info[MPNowPlayingInfoPropertyPlaybackRate] = 1.0
        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
        print("AudioEngineManager: Updated Now Playing info: \(title)")
    }
}
