import CoreNFC
import Foundation
import UIKit

/// Reads a card or sticker with Apple's NDEF reader, the same kind of read that
/// Shortcuts' NFC automation uses. A card's ID is the hex of its first NDEF record.
final class NFCScanner: NSObject, NFCNDEFReaderSessionDelegate, @unchecked Sendable {
    enum ScanError: LocalizedError {
        case unavailable
        case cancelled
        case rejected
        case empty

        var errorDescription: String? {
            switch self {
            case .unavailable: "This iPhone can't read NFC cards."
            case .cancelled: nil
            case .rejected: "That card isn't paired."
            case .empty: "This card has no data and can't be written. Try an NTAG213 or NTAG215 sticker."
            }
        }
    }

    private var session: NFCNDEFReaderSession?
    private var continuation: CheckedContinuation<String, Error>?
    private var successMessage = ""
    private var accept: (String) -> Bool = { _ in true }
    private var writeIfBlank = false

    /// Shows the scan sheet and returns the card's ID as hex.
    /// - Parameters:
    ///   - prompt: The line shown on the sheet while it waits.
    ///   - success: The line shown when the card is accepted.
    ///   - accept: Return false to reject a card (for example, one that isn't paired).
    ///   - writeIfBlank: When the card has no data and can be written, write a link to it
    ///     first (used when pairing), then read it back.
    func scan(prompt: String, success: String, writeIfBlank: Bool = false, accept: @escaping (String) -> Bool = { _ in true }) async throws -> String {
        guard NFCNDEFReaderSession.readingAvailable else { throw ScanError.unavailable }
        return try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation
            self.successMessage = success
            self.accept = accept
            self.writeIfBlank = writeIfBlank
            let session = NFCNDEFReaderSession(delegate: self, queue: nil, invalidateAfterFirstRead: true)
            session.alertMessage = prompt
            self.session = session
            session.begin()
        }
    }

    private func finish(_ result: Result<String, Error>) {
        guard let continuation else { return }
        self.continuation = nil
        continuation.resume(with: result)
    }

    func readerSessionDidBecomeActive(_ session: NFCNDEFReaderSession) {}

    func readerSession(_ session: NFCNDEFReaderSession, didInvalidateWithError error: Error) {
        if let readerError = error as? NFCReaderError, readerError.code == .readerSessionInvalidationErrorUserCanceled {
            finish(.failure(ScanError.cancelled))
        } else if let readerError = error as? NFCReaderError, readerError.code == .readerSessionInvalidationErrorFirstNDEFTagRead {
            // Normal end after a successful read; the result was already delivered.
            finish(.failure(ScanError.cancelled))
        } else {
            finish(.failure(error))
        }
        self.session = nil
    }

    /// The protocol requires this one. It is never used, because the tag version below takes over.
    func readerSession(_ session: NFCNDEFReaderSession, didDetectNDEFs messages: [NFCNDEFMessage]) {}

    /// Implementing this method (rather than didDetectNDEFs) means the session hands us the tag,
    /// so we connect, check it can hold data, and read its first record ourselves.
    /// The old no-op version of this method is why nothing ever happened.
    func readerSession(_ session: NFCNDEFReaderSession, didDetect tags: [NFCNDEFTag]) {
        guard let tag = tags.first else { return }
        session.connect(to: tag) { [weak self] error in
            guard let self else { return }
            if error != nil {
                session.invalidate(errorMessage: "Hold the card still and try again.")
                self.finish(.failure(ScanError.cancelled))
                return
            }
            tag.queryNDEFStatus { status, _, statusError in
                guard statusError == nil, status != .notSupported else {
                    session.invalidate(errorMessage: "This card can't store data. Try an NTAG213 or NTAG215 sticker.")
                    self.finish(.failure(ScanError.empty))
                    return
                }
                tag.readNDEF { message, readError in
                    if readError == nil, let payload = message?.records.first?.payload, !payload.isEmpty {
                        self.complete(payload: payload, session: session)
                    } else if self.writeIfBlank, status == .readWrite {
                        self.writeLink(to: tag, session: session)
                    } else {
                        session.invalidate(errorMessage: ScanError.empty.errorDescription ?? "")
                        self.finish(.failure(ScanError.empty))
                    }
                }
            }
        }
    }

    /// Writes a unique link to a blank card, then reads it back so the saved ID
    /// is exactly what later scans will read.
    private func writeLink(to tag: NFCNDEFTag, session: NFCNDEFReaderSession) {
        guard let url = URL(string: "focuscard://card/\(UUID().uuidString.lowercased())"),
              let record = NFCNDEFPayload.wellKnownTypeURIPayload(url: url)
        else {
            session.invalidate(errorMessage: ScanError.empty.errorDescription ?? "")
            finish(.failure(ScanError.empty))
            return
        }
        session.alertMessage = "Setting up your card. Keep holding it."
        tag.writeNDEF(NFCNDEFMessage(records: [record])) { writeError in
            if writeError != nil {
                session.invalidate(errorMessage: "Couldn't write to this card. Hold it still and try again.")
                self.finish(.failure(ScanError.cancelled))
                return
            }
            tag.readNDEF { message, readError in
                guard readError == nil, let payload = message?.records.first?.payload, !payload.isEmpty else {
                    session.invalidate(errorMessage: "Couldn't check the card. Try again.")
                    self.finish(.failure(ScanError.cancelled))
                    return
                }
                self.complete(payload: payload, session: session)
            }
        }
    }

    private func complete(payload: Data, session: NFCNDEFReaderSession) {
        let hex = payload.map { String(format: "%02X", $0) }.joined()
        print("[FocusCard] read card \(hex)")
        if accept(hex) {
            DispatchQueue.main.async { UIImpactFeedbackGenerator(style: .medium).impactOccurred() }
            session.alertMessage = successMessage
            finish(.success(hex))
            session.invalidate()
        } else {
            session.invalidate(errorMessage: ScanError.rejected.errorDescription ?? "")
            finish(.failure(ScanError.rejected))
        }
    }
}
