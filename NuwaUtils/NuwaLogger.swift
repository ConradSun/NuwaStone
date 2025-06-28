//
//  NuwaLogger.swift
//  NuwaStone
//
//  Created by ConradSun on 2022/7/9.
//

import Foundation

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
}
