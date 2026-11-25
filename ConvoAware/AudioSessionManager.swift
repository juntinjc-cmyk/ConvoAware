import AVFoundation

/// 設定 iPhone 的音訊：音樂從 AirPods 播出（高音質 A2DP），收音用 iPhone 本身的麥克風。
/// 如果改用 AirPods 的麥克風，藍牙會切到通話模式，音樂音質會變很差，所以刻意避開。
enum AudioSessionManager {
    static func configure() throws {
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playAndRecord,
                                mode: .default,
                                options: [.allowBluetoothA2DP, .defaultToSpeaker])
        try session.setActive(true)
        if let builtInMic = session.availableInputs?.first(where: { $0.portType == .builtInMic }) {
            try? session.setPreferredInput(builtInMic)
        }
    }
}
