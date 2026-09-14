//
//  NuwaLogger.swift
//  NuwaStone
//
//  Created by ConradSun on 2022/7/9.
//

import Foundation
import zlib

/// Log level for NuwaClient, NuwaDeamon and NuwaSext
enum NuwaLogLevel: UInt8 {
    case Off = 1, Error, Warning, Info, Debug

    /// Get NuwaLogLevel from raw value, fallback to Info
    static func from(_ value: UInt8) -> NuwaLogLevel {
        return NuwaLogLevel(rawValue: value) ?? .Info
    }
}

struct NuwaLog {
    private static var _logLevel: NuwaLogLevel = {
        NuwaLog.registerDefault()
        let savedLevel = UserDefaults.standard.integer(forKey: UserLogLevel)
        if let level = NuwaLogLevel(rawValue: UInt8(savedLevel)), savedLevel > 0 {
            return level
        }
        return .Info
    }()

    static var logLevel: NuwaLogLevel {
        get { _logLevel }
        set {
            _logLevel = newValue
            UserDefaults.standard.set(newValue.rawValue, forKey: UserLogLevel)
        }
    }

    static func registerDefault() {
        UserDefaults.standard.register(defaults: [UserLogLevel: NuwaLogLevel.Info.rawValue])
    }
}

/// Persistent, size-rotated file logging shared by all Nuwa processes.
class FileLogger {
    static let shared = FileLogger()

    // Serializes appends so log lines are never interleaved or lost.
    private let queue = DispatchQueue(label: "com.nuwastone.filelogger")
    // Runs the (potentially slow) gzip step off the append path.
    private let compressQueue = DispatchQueue(label: "com.nuwastone.logcompress", qos: .utility)

    private let fileManager = FileManager.default
    // Whether the log directory has been created successfully; avoids re-checking per line.
    private var directoryReady = false

    private let lineTimestamp: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"
        return formatter
    }()

    private let archiveTimestamp: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        return formatter
    }()

    // Map each target to a stable log file name (no extension), resolved once.
    private lazy var logName: String = {
        switch Bundle.main.bundleIdentifier?.lowercased() {
        case "com.nuwastone.client":     return "nuwaclient"
        case "com.nuwastone.service":    return "nuwaservice"
        case "com.nuwastone.service.es": return "nuwasext"
        default:
            let name = ProcessInfo.processInfo.processName
                .lowercased()
                .replacingOccurrences(of: ".", with: "_")
            return name.isEmpty ? "nuwa" : name
        }
    }()

    private lazy var activePath: String = {
        "\(LogFileDirectory)/\(logName).log"
    }()

    private init() {}

    func write(level: NuwaLogLevel, file: String, lineNumber: Int, message: String) {
        queue.sync {
            append(level: level, file: file, lineNumber: lineNumber, message: message)
        }
    }

    private func append(level: NuwaLogLevel, file: String, lineNumber: Int, message: String) {
        do {
            try prepareDirectory()
        } catch {
            return
        }

        if !fileManager.fileExists(atPath: activePath) {
            fileManager.createFile(atPath: activePath, contents: nil, attributes: nil)
        }

        let timestamp = lineTimestamp.string(from: Date())
        let line = "\(timestamp) [\(level)] \(file): \(lineNumber) [-] \(message)\n"
        guard let handle = try? FileHandle(forWritingTo: URL(fileURLWithPath: activePath)) else { return }
        defer { handle.closeFile() }
        handle.seekToEndOfFile()
        handle.write(Data(line.utf8))

        rotateIfNeeded()
    }

    /// Create the shared log directory once, writable by every Nuwa process (sticky 1777).
    private func prepareDirectory() throws {
        guard !directoryReady else { return }
        try fileManager.createDirectory(atPath: LogFileDirectory, withIntermediateDirectories: true,
                                        attributes: [.posixPermissions: 0o1777])
        directoryReady = true
    }

    /// Rename the active file once it reaches the size limit, then compress it in the background.
    private func rotateIfNeeded() {
        guard let attrs = try? fileManager.attributesOfItem(atPath: activePath),
              let size = attrs[.size] as? NSNumber,
              size.uint64Value >= LogFileSizeLimit else {
            return
        }

        let stamped = "\(LogFileDirectory)/\(logName)-\(archiveTimestamp.string(from: Date())).log"
        guard (try? fileManager.moveItem(atPath: activePath, toPath: stamped)) != nil else { return }
        compressQueue.async { [weak self] in
            self?.gzipFile(atPath: stamped)
        }
    }

    /// Compress a rotated log into a standard gzip archive; delete the original only on success.
    private func gzipFile(atPath path: String) {
        guard let data = fileManager.contents(atPath: path), !data.isEmpty else { return }

        // Write to a temp file first: a crash or exit mid-compression then leaves no
        // half-written .gz behind, and the original .log is only removed once the
        // archive is complete and valid.
        let tempPath = path + ".gz.tmp"
        guard let gz = gzopen(tempPath, "wb") else { return }
        let written = data.withUnsafeBytes { buffer -> Int in
            // gzwrite takes a UInt32 length, so feed it in chunks to avoid truncation.
            var offset = 0
            var total = 0
            let bytes = buffer.bindMemory(to: UInt8.self)
            while offset < bytes.count {
                let chunk = min(bytes.count - offset, 1 << 20)
                let n = Int(gzwrite(gz, bytes.baseAddress! + offset, UInt32(chunk)))
                guard n > 0 else { break }
                total += n
                offset += n
            }
            return total
        }
        let closed = gzclose(gz)

        guard written == data.count, closed == Z_OK else {
            try? fileManager.removeItem(atPath: tempPath)
            return
        }
        guard (try? fileManager.moveItem(atPath: tempPath, toPath: path + ".gz")) != nil else {
            try? fileManager.removeItem(atPath: tempPath)
            return
        }
        try? fileManager.removeItem(atPath: path)
    }
}

/// Log printing method for NuwaClient, NuwaDeamon and NuwaSext
/// - Parameters:
///   - level: Log level
///   - message: Info to be printed
///   - file: Source code file, assignment not required
///   - lineNumber: Source code line, assignment not required
func Logger(_ level: NuwaLogLevel, _ message: Any..., file: String = #file, lineNumber: Int = #line) {
    if level.rawValue > NuwaLog.logLevel.rawValue {
        return
    }
    let fileName = (file as NSString).lastPathComponent
    let msg = message.map { "\($0)" }.joined(separator: " ")
    NSLog("%@", "[\(level)] \(fileName): \(lineNumber) [-] \(msg)")
    FileLogger.shared.write(level: level, file: fileName, lineNumber: lineNumber, message: msg)
}
