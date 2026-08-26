//
//  SSEParser.swift
//  DshMobile
//
//  Parses SSE lines (id:, data:, event:) into typed SSEEvent structs using Swift AsyncSequence.
//

import Foundation

public struct SSEEvent: Sendable {
    public let id: String?
    public let event: String?
    public let data: String
}

public enum SSEParser {
    /// Parses any AsyncSequence of String lines into a stream of SSEEvents
    public static func parse<S: AsyncSequence>(lines: S) -> AsyncStream<SSEEvent> where S.Element == String {
        AsyncStream { continuation in
            Task {
                var currentId: String?
                var currentEvent: String?
                var dataBuffer: [String] = []

                do {
                    for try await line in lines {
                        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)

                        // Empty line triggers event dispatch
                        if trimmed.isEmpty {
                            if !dataBuffer.isEmpty {
                                let fullData = dataBuffer.joined(separator: "\n")
                                let sseEvent = SSEEvent(id: currentId, event: currentEvent, data: fullData)
                                continuation.yield(sseEvent)
                                dataBuffer.removeAll()
                                currentEvent = nil
                            }
                            continue
                        }

                        if line.hasPrefix("data:") {
                            let dataPart = String(line.dropFirst(5)).trimmingCharacters(in: .whitespaces)
                            dataBuffer.append(dataPart)
                        } else if line.hasPrefix("id:") {
                            currentId = String(line.dropFirst(3)).trimmingCharacters(in: .whitespaces)
                        } else if line.hasPrefix("event:") {
                            currentEvent = String(line.dropFirst(6)).trimmingCharacters(in: .whitespaces)
                        }
                    }
                } catch {
                    // Stream closed or network error
                }

                // Flush remaining
                if !dataBuffer.isEmpty {
                    let fullData = dataBuffer.joined(separator: "\n")
                    continuation.yield(SSEEvent(id: currentId, event: currentEvent, data: fullData))
                }
                continuation.finish()
            }
        }
    }
}
