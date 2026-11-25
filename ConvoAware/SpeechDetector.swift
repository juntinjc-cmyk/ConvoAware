import AVFoundation
import SoundAnalysis
import Combine

/// 用 iPhone 麥克風聽周圍的聲音，判斷「有沒有人在說話」。
/// 聲音只在記憶體裡即時分析，不會存檔也不會上傳。
final class SpeechDetector: NSObject, ObservableObject {

    // MARK: 畫面上顯示的狀態
    @Published var isListening = false
    @Published var isTriggered = false
    @Published var speechConfidence: Double = 0      // 0~1，Apple 辨識出「人聲」的信心
    @Published var levelDB: Double = -100            // 目前麥克風音量（dBFS）
    @Published var log: [LogEntry] = []
    @Published var errorMessage: String?

    // MARK: 可以在畫面上調整的參數
    @Published var threshold: Double = 0.6           // 人聲信心超過多少才算有人在說話
    @Published var minLevelDB: Double = -45          // 太小聲（太遠）的人聲不觸發
    @Published var holdSeconds: Double = 1.5         // 人聲停止多久後才算講完

    /// 觸發（true）或結束（false）時通知音樂播放器
    var onTriggerChange: ((Bool) -> Void)?

    struct LogEntry: Identifiable {
        let id = UUID()
        let time: Date
        let text: String
    }

    private let engine = AVAudioEngine()
    private var analyzer: SNAudioStreamAnalyzer?
    private let analysisQueue = DispatchQueue(label: "convoaware.analysis")
    private var speechLabels: Set<String> = []
    private var recentLevelDB: Double = -100
    private var lastSpeechTime = Date.distantPast
    private var releaseTimer: Timer?

    // MARK: 開始 / 停止

    func start() {
        guard !isListening else { return }
        errorMessage = nil
        AVAudioApplication.requestRecordPermission { [weak self] granted in
            DispatchQueue.main.async {
                guard let self else { return }
                if granted {
                    self.startEngine()
                } else {
                    self.errorMessage = "沒有麥克風權限。請到「設定 > 隱私權與安全性 > 麥克風」打開「對話感知」。"
                }
            }
        }
    }

    func stop() {
        guard isListening else { return }
        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
        analyzer = nil
        releaseTimer?.invalidate()
        releaseTimer = nil
        if isTriggered { setTriggered(false, reason: "停止監聽") }
        isListening = false
        speechConfidence = 0
        addLog("停止監聽")
    }

    private func startEngine() {
        do {
            try AudioSessionManager.configure()

            let input = engine.inputNode
            let format = input.outputFormat(forBus: 0)
            guard format.sampleRate > 0 else {
                errorMessage = "找不到可用的麥克風。"
                return
            }

            let request = try SNClassifySoundRequest(classifierIdentifier: .version1)
            Self.setShortWindow(on: request, targetSeconds: 0.5)
            request.overlapFactor = 0.5

            // 找出所有跟「人說話」有關的分類
            speechLabels = Set(request.knownClassifications.filter { id in
                let s = id.lowercased()
                return s.contains("speech") || s.contains("conversation")
                    || s.contains("shout") || s.contains("yell") || s.contains("whisper")
            })

            let analyzer = SNAudioStreamAnalyzer(format: format)
            try analyzer.add(request, withObserver: self)
            self.analyzer = analyzer

            input.installTap(onBus: 0, bufferSize: 4096, format: format) { [weak self] buffer, time in
                guard let self else { return }
                let db = Self.rmsDB(buffer)
                self.analysisQueue.async {
                    self.analyzer?.analyze(buffer, atAudioFramePosition: time.sampleTime)
                }
                DispatchQueue.main.async {
                    self.levelDB = db
                    // 音量峰值慢慢衰減，讓一句話中間的短暫停頓不會被當成太小聲
                    self.recentLevelDB = max(db, self.recentLevelDB - 1.5)
                }
            }

            engine.prepare()
            try engine.start()
            isListening = true
            addLog("開始監聽（偵測 \(speechLabels.count) 種人聲類別）")

            releaseTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
                self?.checkRelease()
            }
        } catch {
            errorMessage = "無法啟動麥克風：\(error.localizedDescription)"
        }
    }

    // MARK: 判斷邏輯

    fileprivate func handle(confidence: Double) {
        speechConfidence = confidence
        let loudEnough = recentLevelDB >= minLevelDB
        guard confidence >= threshold && loudEnough else { return }
        lastSpeechTime = Date()
        if !isTriggered {
            setTriggered(true, reason: "人聲信心 \(Int(confidence * 100))%，音量 \(Int(recentLevelDB)) dB")
        }
    }

    private func checkRelease() {
        guard isTriggered else { return }
        if Date().timeIntervalSince(lastSpeechTime) > holdSeconds {
            setTriggered(false, reason: "已安靜 \(String(format: "%.1f", holdSeconds)) 秒")
        }
    }

    private func setTriggered(_ on: Bool, reason: String) {
        isTriggered = on
        onTriggerChange?(on)
        addLog(on ? "觸發：\(reason)" : "結束：\(reason)")
    }

    private func addLog(_ text: String) {
        log.insert(LogEntry(time: Date(), text: text), at: 0)
        if log.count > 200 { log.removeLast(log.count - 200) }
    }

    // MARK: 工具

    private static func rmsDB(_ buffer: AVAudioPCMBuffer) -> Double {
        guard let data = buffer.floatChannelData?[0] else { return -100 }
        let n = Int(buffer.frameLength)
        guard n > 0 else { return -100 }
        var sum: Float = 0
        for i in 0..<n { sum += data[i] * data[i] }
        let rms = sqrt(sum / Float(n))
        return rms > 0 ? Double(20 * log10(rms)) : -100
    }

    /// 把分析視窗設得盡量短，反應才快
    private static func setShortWindow(on request: SNClassifySoundRequest, targetSeconds: Double) {
        switch request.windowDurationConstraint {
        case .enumeratedDurations(let options):
            let longEnough: [CMTime] = options.filter { $0.seconds >= targetSeconds }
            let sorted: [CMTime] = longEnough.sorted { $0.seconds < $1.seconds }
            if let best = sorted.first ?? options.last {
                request.windowDuration = best
            }
        case .durationRange(let range):
            let lo: Double = range.start.seconds
            let hi: Double = range.end.seconds
            let chosen: Double = min(max(targetSeconds, lo), hi)
            request.windowDuration = CMTime(seconds: chosen, preferredTimescale: 48_000)
        @unknown default:
            break
        }
    }
}

extension SpeechDetector: SNResultsObserving {
    func request(_ request: SNRequest, didProduce result: SNResult) {
        guard let result = result as? SNClassificationResult else { return }
        let confidence = result.classifications
            .filter { speechLabels.contains($0.identifier) }
            .map { $0.confidence }
            .max() ?? 0
        DispatchQueue.main.async { [weak self] in
            self?.handle(confidence: confidence)
        }
    }

    func request(_ request: SNRequest, didFailWithError error: Error) {
        DispatchQueue.main.async { [weak self] in
            self?.errorMessage = "人聲辨識失敗：\(error.localizedDescription)"
        }
    }
}
