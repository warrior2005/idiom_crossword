// macOS 本地 OCR：调用方传入 PDF、从 1 开始的页码；逐页输出 JSON。
import Foundation
import PDFKit
import Vision
import AppKit

let args = CommandLine.arguments
guard args.count >= 3, let document = PDFDocument(url: URL(fileURLWithPath: args[1])) else {
    fputs("Usage: textbook_ocr PDF PAGE [PAGE ...]\n", stderr)
    exit(1)
}
for value in args.dropFirst(2) {
    let number = Int(value) ?? 0
    do {
        let result: [String: Any] = try autoreleasepool {
            guard number > 0, let page = document.page(at: number - 1) else {
                throw NSError(domain: "Invalid PDF page", code: 1)
            }
            let bounds = page.bounds(for: .mediaBox)
            let scale = min(3.0, 2400.0 / max(bounds.width, bounds.height))
            let image = page.thumbnail(of: NSSize(width: bounds.width * scale, height: bounds.height * scale), for: .mediaBox)
            guard let cg = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
                throw NSError(domain: "Cannot render PDF page", code: 2)
            }
            let request = VNRecognizeTextRequest()
            request.recognitionLevel = .accurate
            request.recognitionLanguages = ["zh-Hans", "en-US"]
            request.usesLanguageCorrection = false
            try VNImageRequestHandler(cgImage: cg).perform([request])
            let observations = request.results ?? []
            return ["page": number, "text": observations.compactMap { $0.topCandidates(1).first?.string }.joined(separator: "\n"),
                    "confidence": observations.compactMap { $0.topCandidates(1).first?.confidence }.map(Double.init),
                    "engine": "Apple Vision", "os": ProcessInfo.processInfo.operatingSystemVersionString]
        }
        let data = try JSONSerialization.data(withJSONObject: result, options: [.sortedKeys])
        print(String(data: data, encoding: .utf8)!)
    } catch {
        let data = try! JSONSerialization.data(withJSONObject: ["page": number, "error": error.localizedDescription])
        print(String(data: data, encoding: .utf8)!)
    }
}
