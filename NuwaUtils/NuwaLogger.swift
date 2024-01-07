//
//  NuwaLogger.swift
//  NuwaStone
//
//  Created by ConradSun on 2022/7/9.
//

import Foundation

/// Log level for NuwaClient, NuwaDeamon and NuwaSext
enum NuwaLogLevel: UInt8 {
    case Off        = 1
    case Error      = 2
    case Warning    = 3
    case Info       = 4
    case Debug      = 5
}

/// Log set and get methods
struct NuwaLog {
    var logLevel: UInt8 {
        get {
            let savedLevel = UserDefaults.standard.integer(forKey: UserLogLevel)
            if savedLevel > 0 {
                return UInt8(savedLevel)
            }
            return NuwaLogLevel.Info.rawValue
        }
        set {
            UserDefaults.standard.set(newValue, forKey: UserLogLevel)
        }
    }
}

/// Log printing method for NuwaClient, NuwaDeamon and NuwaSext
/// - Parameters:
///   - level: Log level
///   - message: Info to be printed
///   - file: Source code file, assignment not required
///   - lineNumber: Source code line, assignment not required
func Logger<T>(_ level: NuwaLogLevel, _ message: T, file: String = #file, lineNumber: Int = #line) {
    if level.rawValue > NuwaLog().logLevel {
        return
    }
    let fileName = (file as NSString).lastPathComponent
    NSLog("[\(level)] \(fileName): \(lineNumber) [-] \(message)")
}
