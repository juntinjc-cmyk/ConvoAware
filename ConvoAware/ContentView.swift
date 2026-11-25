import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @EnvironmentObject var detector: SpeechDetector
    @EnvironmentObject var player: MusicPlayer
    @State private var showPicker = false

    var body: some View {
        NavigationStack {
            Form {
                statusSection
                musicSection
                settingsSection
                logSection
                Section {
                    Text("聲音只在手機上即時分析，不會錄存或上傳。目前分辨不出是你自己還是別人在說話，你自己開口也可能觸發。")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("對話感知 v0.1")
        }
        .fileImporter(isPresented: $showPicker, allowedContentTypes: [.audio]) { result in
            if case .success(let url) = result { player.load(from: url) }
        }
        .onAppear {
            detector.onTriggerChange = { on in player.duck(on) }
        }
    }

    // MARK: 狀態

    private var statusSection: some View {
        Section("狀態") {
            HStack {
                Circle()
                    .fill(detector.isTriggered ? Color.orange : (detector.isListening ? Color.green : Color.gray))
                    .frame(width: 14, height: 14)
                Text(detector.isTriggered ? "有人在說話，音樂已壓低"
                     : (detector.isListening ? "監聽中" : "未啟動"))
                    .font(.headline)
            }
            meter(title: "人聲信心", value: detector.speechConfidence,
                  label: "\(Int(detector.speechConfidence * 100))%",
                  marker: detector.threshold)
            meter(title: "音量", value: (detector.levelDB + 80) / 80,
                  label: "\(Int(detector.levelDB)) dB",
                  marker: (detector.minLevelDB + 80) / 80)
            Button(detector.isListening ? "停止監聽" : "開始監聽") {
                detector.isListening ? detector.stop() : detector.start()
            }
            .buttonStyle(.borderedProminent)
            .tint(detector.isListening ? .red : .accentColor)
            if let msg = detector.errorMessage {
                Text(msg).foregroundStyle(.red).font(.footnote)
            }
        }
    }

    private func meter(title: String, value: Double, label: String, marker: Double) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(title)
                Spacer()
                Text(label).monospacedDigit().foregroundStyle(.secondary)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.gray.opacity(0.2))
                    Capsule().fill(value >= marker ? Color.orange : Color.blue)
                        .frame(width: geo.size.width * min(max(value, 0), 1))
                    Rectangle().fill(Color.primary)
                        .frame(width: 2)
                        .offset(x: geo.size.width * min(max(marker, 0), 1))
                }
            }
            .frame(height: 10)
        }
    }

    // MARK: 音樂

    private var musicSection: some View {
        Section("音樂") {
            Text(player.trackName).lineLimit(1)
            HStack {
                Button("選擇音樂檔") { showPicker = true }
                Spacer()
                Button(player.isPlaying ? "暫停" : "播放") { player.togglePlay() }
                    .disabled(player.trackName == "尚未選擇音樂")
            }
            .buttonStyle(.bordered)
            slider("音量", value: $player.volume, range: 0...1, text: "\(Int(player.volume * 100))%")
            if let msg = player.errorMessage {
                Text(msg).foregroundStyle(.red).font(.footnote)
            }
        }
    }

    // MARK: 參數

    private var settingsSection: some View {
        Section("調整") {
            slider("觸發門檻（人聲信心）", value: $detector.threshold, range: 0.2...0.95,
                   text: "\(Int(detector.threshold * 100))%")
            slider("最小音量（太遠不觸發）", value: $detector.minLevelDB, range: -70...(-20),
                   text: "\(Int(detector.minLevelDB)) dB")
            slider("講完後等多久才升回", value: $detector.holdSeconds, range: 0.5...5,
                   text: String(format: "%.1f 秒", detector.holdSeconds))
            slider("壓低到原本的", value: $player.duckRatio, range: 0.1...0.9,
                   text: "\(Int(player.duckRatio * 100))%")
        }
    }

    private func slider(_ title: String, value: Binding<Double>, range: ClosedRange<Double>, text: String) -> some View {
        VStack(alignment: .leading) {
            HStack {
                Text(title)
                Spacer()
                Text(text).monospacedDigit().foregroundStyle(.secondary)
            }
            Slider(value: value, in: range)
        }
    }

    // MARK: 紀錄

    private var logSection: some View {
        Section("紀錄（只記時間和原因，不存聲音）") {
            if detector.log.isEmpty {
                Text("還沒有紀錄").foregroundStyle(.secondary)
            }
            ForEach(detector.log.prefix(50)) { entry in
                HStack(alignment: .top) {
                    Text(entry.time, format: .dateTime.hour().minute().second())
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                    Text(entry.text)
                }
                .font(.footnote)
            }
        }
    }
}
