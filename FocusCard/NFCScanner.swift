import CoreNFC
import Foundation

/// Reads an NFC card's hardware ID with Apple's scan sheet.
/// Works with NTAG213/215/216 cards and stickers, and most other tags.
final class NFCScanner: NSObject, NFCTagReaderSessionDelegate, @unchecked Sendable {
    enum ScanError: LocalizedError {
        case unavailable
        case cancelled
        case rejected

        var errorDescription: String? {
            switch self {
            case .unavailable: "This iPhone can't read NFC cards."
            case .cancelled: nil
            case .rejected: "That card isn't paired."
            }
        }
    }

    private var session: NFCTagReaderSession?
    private var continuation: CheckedContinuation<String, Error>?
    private var successMessage = ""
    private var accept: (String) -> Bool = { _ in true }

    /// Shows the scan sheet and returns the tag's ID as hex.
    /// - Parameters:
    ///   - prompt: The line shown on the sheet while it waits.
    ///   - success: The line shown when the card is accepted.
    ///   - accept: Return false to reject a card (for example, one that isn't paired).
    func scan(prompt: String, success: String, accept: @escaping (String) -> Bool = { _ in true }) async throws -> String {
        guard NFCTagReaderSession.readingAvailable else { throw ScanError.unavailable }
        return try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation
            self.successMessage = success
            self.accept = accept
            let session = NFCTagReaderSession(pollingOption: [.iso14443, .iso15693], delegate: self, queue: nil)
            session?.alertMessage = prompt
            self.session = session
            session?.begin()
        }
    }

    private func finish(_ result: Result<String, Error>) {
        guard let continuation else { return }
        self.continuation = nil
        continuation.resume(with: result)
    }

    func tagReaderSessionDidBecomeActive(_ session: NFCTagReaderSession) {}

    func tagReaderSession(_ session: NFCTagReaderSession, didInvalidateWithError error: Error) {
        if let readerError = error as? NFCReaderError,
           readerError.code == .readerSessionInvalidationErrorUserCanceled
            || readerError.code == .readerSessionInvalidationErrorFirstNDEFTagRead {
            finish(.failure(ScanError.cancelled))
        } else {
            finish(.failure(error))
        }
        self.session = nil
    }

    func tagReaderSession(_ session: NFCTagReaderSession, didDetect tags: [NFCTag]) {
        guard let tag = tags.first else { return }
        // Shows on the sheet as soon as a tag is found, so we can tell detection apart from a failed read.
        session.alertMessage = "Card found. Keep it still."
        session.connect(to: tag) { [weak self] error in
            guard let self else { return }
            if error != nil {
                session.invalidate(errorMessage: "Hold the card still and try again.")
                return
            }
            guard let id = Self.identifier(of: tag) else {
                session.invalidate(errorMessage: "This card can't be read.")
                return
            }
            let hex = id.map { String(format: "%02X", $0) }.joined()
            if self.accept(hex) {
                session.alertMessage = self.successMessage
                self.finish(.success(hex))
                session.invalidate()
            } else {
                session.invalidate(errorMessage: ScanError.rejected.errorDescription ?? "")
                self.finish(.failure(ScanError.rejected))
            }
        }
    }

    private static func identifier(of tag: NFCTag) -> Data? {
        switch tag {
        case .miFare(let tag): tag.identifier
        case .iso15693(let tag): tag.identifier
        case .iso7816(let tag): tag.identifier
        case .feliCa(let tag): tag.currentIDm
        @unknown default: nil
        }
    }
}
