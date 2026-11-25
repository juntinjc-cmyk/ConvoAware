import AVFoundation

/// App 內建的簡單音樂播放器。有人說話時把音量緩降，講完再緩升。
final class MusicPlayer: ObservableObject {
    @Published var trackName = "尚未選擇音樂"
    @Published var isPlaying = false
    @Published var isDucked = false
    @Published var volume: Double = 0.8 {          // 平常的音量
        didSet { applyVolume(fade: 0.1) }
    }
    @Published var duckRatio: Double = 0.5         // 壓低時剩下原本音量的幾成
    @Published var errorMessage: String?

    private var player: AVAudioPlayer?

    /// 從「檔案」App 選的音樂，先複製一份到 App 裡再播放
    func load(from pickedURL: URL) {
        errorMessage = nil
        let accessing = pickedURL.startAccessingSecurityScopedResource()
        defer { if accessing { pickedURL.stopAccessingSecurityScopedResource() } }
        do {
            let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            let dest = docs.appendingPathComponent(pickedURL.lastPathComponent)
            if FileManager.default.fileExists(atPath: dest.path) {
                try FileManager.default.removeItem(at: dest)
            }
            try FileManager.default.copyItem(at: pickedURL, to: dest)

            try AudioSessionManager.configure()
            let newPlayer = try AVAudioPlayer(contentsOf: dest)
            newPlayer.numberOfLoops = -1
            newPlayer.prepareToPlay()
            player?.stop()
            player = newPlayer
            trackName = pickedURL.deletingPathExtension().lastPathComponent
            isPlaying = false
            applyVolume(fade: 0)
        } catch {
            errorMessage = "無法載入這個音樂檔：\(error.localizedDescription)"
        }
    }

    func togglePlay() {
        guard let player else { return }
        if player.isPlaying {
            player.pause()
            isPlaying = false
        } else {
            try? AudioSessionManager.configure()
            player.play()
            isPlaying = true
        }
    }

    /// on = true：緩降；on = false：緩升
    func duck(_ on: Bool) {
        isDucked = on
        applyVolume(fade: on ? 0.4 : 1.0)
    }

    private func applyVolume(fade: TimeInterval) {
        let target = isDucked ? volume * duckRatio : volume
        player?.setVolume(Float(target), fadeDuration: fade)
    }
}
