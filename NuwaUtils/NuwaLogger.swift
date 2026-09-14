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

    /// Stop retrying file logging after this many consecutive failures.
    private let maxFailures = 10

    private let queue = DispatchQueue(label: "com.nuwastone.filelogger")
    private let fileManager = FileManager.default
    private var failureCount = 0

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

    private init() {}

    /// Map each target to a stable log file name (no extension).
    private var logName: String {
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
    }

    private var activePath: String {
        "\(LogFileDirectory)/\(logName).log"
    }

    func write(level: NuwaLogLevel, file: String, lineNumber: Int, message: String) {
        queue.sync {
            guard failureCount < maxFailures else { return }
            do {
                try append(level: level, file: file, lineNumber: lineNumber, message: message)
                failureCount = 0
            } catch {
                failureCount += 1
            }
        }
    }

    private func append(level: NuwaLogLevel, file: String, lineNumber: Int, message: String) throws {
        try fileManager.createDirectory(atPath: LogFileDirectory, withIntermediateDirectories: true,
                                        attributes: [.posixPermissions: 0o1777])

        if !fileManager.fileExists(atPath: activePath) {
            fileManager.createFile(atPath: activePath, contents: nil, attributes: nil)
        }

        let timestamp = lineTimestamp.string(from: Date())
        let line = "\(timestamp) [\(level)] \(file): \(lineNumber) [-] \(message)\n"
        let handle = try FileHandle(forWritingTo: URL(fileURLWithPath: activePath))
        defer { handle.closeFile() }
        handle.seekToEndOfFile()
        handle.write(line.data(using: .utf8) ?? Data())

        rotateIfNeeded()
    }

    /// Rename + gzip the active file once it reaches the size limit.
    private func rotateIfNeeded() {
        guard let attrs = try? fileManager.attributesOfItem(atPath: activePath),
              let size = attrs[.size] as? NSNumber,
              size.uint64Value >= LogFileSizeLimit else {
            return
        }

        let stamped = "\(LogFileDirectory)/\(logName)-\(archiveTimestamp.string(from: Date())).log"
        do {
            try fileManager.moveItem(atPath: activePath, toPath: stamped)
        } catch {
            return
        }
        gzipFile(atPath: stamped)
    }

    /// Compress a rotated log file into a standard gzip archive, then drop the original.
    private func gzipFile(atPath path: String) {
        guard let data = fileManager.contents(atPath: path), !data.isEmpty else { return }

        guard let gz = gzopen(path + ".gz", "wb") else { return }
        defer { gzclose(gz) }
        data.withUnsafeBytes { buffer in
            _ = gzwrite(gz, buffer.baseAddress, UInt32(buffer.count))
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
    NSLog("[\(level)] \(fileName): \(lineNumber) [-] \(msg)")
    FileLogger.shared.write(level: level, file: fileName, lineNumber: lineNumber, message: msg)
}
