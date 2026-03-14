import Speech
import AVFoundation
import Combine

enum SpeechError: Error, LocalizedError {
    case notAuthorized
    case notAvailable
    case audioSessionFailed
    case recognitionFailed(String)

    var errorDescription: String? {
        switch self {
        case .notAuthorized: return "Speech recognition not authorized"
        case .notAvailable: return "Speech recognition not available on this device"
        case .audioSessionFailed: return "Could not configure audio session"
        case .recognitionFailed(let msg): return "Recognition failed: \(msg)"
        }
    }
}

@MainActor
final class SpeechRecognitionService: ObservableObject {

    // MARK: - Published State

    @Published var isListening = false
    @Published var lastRecognizedLetter: Character?
    @Published var authorizationStatus: SFSpeechRecognizerAuthorizationStatus = .notDetermined
    @Published var error: SpeechError?

    /// Fires each time a valid Sloan letter is recognized.
    let recognizedLetterPublisher = PassthroughSubject<Character, Never>()

    // MARK: - Private

    private let speechRecognizer: SFSpeechRecognizer?
    private let audioEngine = AVAudioEngine()
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private var processedTranscriptLength = 0

    /// Maps spoken words/phonetics to Sloan letters.
    private static let phoneticMap: [String: Character] = [
        "C": "C", "SEE": "C", "SEA": "C",
        "D": "D", "DEE": "D",
        "H": "H", "AITCH": "H",
        "K": "K", "KAY": "K",
        "N": "N", "EN": "N",
        "O": "O", "OH": "O",
        "R": "R", "ARE": "R", "OUR": "R",
        "S": "S", "ES": "S",
        "V": "V", "VEE": "V",
        "Z": "Z", "ZED": "Z", "ZEE": "Z",
    ]

    private static let sloanLetters: Set<Character> = Set("CDHKNORSVZ")

    // MARK: - Init

    init() {
        speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
        authorizationStatus = SFSpeechRecognizer.authorizationStatus()
    }

    // MARK: - Authorization

    func requestAuthorization() async -> Bool {
        let status = await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status)
            }
        }
        authorizationStatus = status
        return status == .authorized
    }

    // MARK: - Listening

    func startListening() throws {
        guard let speechRecognizer, speechRecognizer.isAvailable else {
            error = .notAvailable
            throw SpeechError.notAvailable
        }

        guard authorizationStatus == .authorized else {
            error = .notAuthorized
            throw SpeechError.notAuthorized
        }

        // Stop any existing task
        stopListeningInternal()

        let audioSession = AVAudioSession.sharedInstance()
        do {
            try audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            self.error = .audioSessionFailed
            throw SpeechError.audioSessionFailed
        }

        processedTranscriptLength = 0

        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        request.requiresOnDeviceRecognition = true
        recognitionRequest = request

        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { buffer, _ in
            request.append(buffer)
        }

        audioEngine.prepare()
        do {
            try audioEngine.start()
        } catch {
            self.error = .audioSessionFailed
            throw SpeechError.audioSessionFailed
        }

        recognitionTask = speechRecognizer.recognitionTask(with: request) { [weak self] result, error in
            Task { @MainActor in
                self?.handleRecognitionResult(result: result, error: error)
            }
        }

        isListening = true
        self.error = nil
    }

    func stopListening() {
        stopListeningInternal()
        isListening = false
    }

    func reset() {
        stopListening()
        lastRecognizedLetter = nil
        error = nil
    }

    // MARK: - Private

    private func stopListeningInternal() {
        recognitionTask?.cancel()
        recognitionTask = nil
        recognitionRequest?.endAudio()
        recognitionRequest = nil

        audioEngine.inputNode.removeTap(onBus: 0)
        if audioEngine.isRunning {
            audioEngine.stop()
        }

        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    private func handleRecognitionResult(result: SFSpeechRecognitionResult?, error: Error?) {
        guard let result else {
            if let error {
                self.error = .recognitionFailed(error.localizedDescription)
            }
            return
        }

        let transcript = result.bestTranscription.formattedString.uppercased()

        // Only process the new portion of the transcript
        guard transcript.count > processedTranscriptLength else { return }

        let startIndex = transcript.index(transcript.startIndex, offsetBy: processedTranscriptLength)
        let newPortion = String(transcript[startIndex...])
        processedTranscriptLength = transcript.count

        // Split new portion into words and map each to a Sloan letter
        let words = newPortion.split(separator: " ").map(String.init)
        for word in words {
            let cleaned = word.trimmingCharacters(in: .punctuationCharacters).uppercased()
            if let letter = Self.phoneticMap[cleaned] {
                lastRecognizedLetter = letter
                recognizedLetterPublisher.send(letter)
            } else if cleaned.count == 1, let char = cleaned.first, Self.sloanLetters.contains(char) {
                lastRecognizedLetter = char
                recognizedLetterPublisher.send(char)
            }
        }
    }
}
