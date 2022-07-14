//
//  NuwaLogger.swift
//  NuwaStone
//
//  Created by 孙康 on 2022/7/9.
//

import Foundation

enum NuwaLogLevel : UInt32 {
    case Off        = 1
    case Error      = 2
    case Warning    = 3
    case Info       = 4
    case Debug      = 5
}

struct NuwaLog {
    var logLevel: UInt32 {
        get {
            let savedLevel = UserDefaults.standard.integer(forKey: "logLevel")
            if savedLevel > 0 {
                return UInt32(savedLevel)
            }
            return NuwaLogLevel.Info.rawValue
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "logLevel")
        }
    }
};

func Logger<Type>(_ level: NuwaLogLevel, _ message: Type, file: String = #file, lineNumber: Int = #line) {
    if level.rawValue > NuwaLog().logLevel {
        return
    }
    let fileName = (file as NSString).lastPathComponent
    print("\(level) \(fileName): \(lineNumber) [-] \(message)")
}
