import Foundation
import ImageIO
import Vision

public enum ImageOCRService {
    public static func recognizeText(from imageData: Data) async -> String? {
        await Task.detached(priority: .utility) {
            recognizeTextSync(from: imageData)
        }.value
    }

    public static func recognizeTextSync(from imageData: Data) -> String? {
        guard let source = CGImageSourceCreateWithData(imageData as CFData, nil),
              let cgImage = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
            return nil
        }

        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true

        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        do {
            try handler.perform([request])
        } catch {
            return nil
        }

        guard let observations = request.results, !observations.isEmpty else {
            return nil
        }

        let lines = observations.compactMap { observation in
            observation.topCandidates(1).first?.string.trimmingCharacters(in: .whitespacesAndNewlines)
        }.filter { !$0.isEmpty }

        guard !lines.isEmpty else { return nil }
        return lines.joined(separator: "\n")
    }
}
