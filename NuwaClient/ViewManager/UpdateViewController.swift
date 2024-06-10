//
//  UpdateViewController.swift
//  NuwaClient
//
//  Created by ConradSun on 2024/5/12.
//

import Cocoa

class UpdateViewController: NSViewController {
    @IBOutlet weak var iconImageView: NSImageView!
    @IBOutlet weak var launchProgressIndicator: NSProgressIndicator!
    
    private var updateCheckTask: Process?
    private var checkResultPipe: Pipe?
    private var checkInfoWindow: NSAlert?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        let icon = NSImage(named: "AppIcon")
        icon?.size = NSMakeSize(80, 80)
        iconImageView.image = icon
        launchProgressIndicator.startAnimation(nil)
        
        checkInfoWindow = NSAlert()
        checkInfoWindow?.alertStyle = .informational
        
        DispatchQueue.global().async { [self] in
            var latestVersion = String()
            let currentVersion = Bundle.main.object(forInfoDictionaryKey: VersionInfoKey) as! String
            
            initCheckTask()
            if let checkResult = launchCheckTask() {
                let contentList = checkResult.split(separator: "\r\n")
                for contentItem in contentList {
                    if contentItem.contains("location") {
                        let tag = contentItem.split(separator: "/").last!
                        if tag.first == "v" {
                            Logger(.Info, "The latest version is \(tag).")
                            latestVersion = tag.dropFirst().lowercased()
                        }
                    }
                }
            }
            
            DispatchQueue.main.async { [self] in
                setupInfoWindow(latestVersion: latestVersion, currentVersion: currentVersion)
                view.window?.close()
                let resp = checkInfoWindow?.runModal()
                if resp == .alertSecondButtonReturn {
                    let downloadAddr = URL(string: PackageURL)
                    NSWorkspace.shared.open(downloadAddr!)
                }
            }
        }
    }
    
    override func viewDidAppear() {
        super.viewDidAppear()

        if let window = view.window, let screen = NSScreen.main {
            let screenRect = screen.visibleFrame
            let windowRect = window.frame

            window.setFrameOrigin(NSPoint(
                x: screenRect.midX - windowRect.width / 2,
                y: screenRect.midY - windowRect.height / 2
            ))
        }
    }
    
    override func viewDidDisappear() {
        super.viewDidDisappear()
        updateCheckTask?.terminate()
    }
    
    private func initCheckTask() {
        updateCheckTask = Process()
        checkResultPipe = Pipe()
        updateCheckTask?.arguments = ["-I", ReleaseURL]
        updateCheckTask?.standardOutput = checkResultPipe
        
        if #available(macOS 10.13, *) {
            updateCheckTask?.executableURL = URL(fileURLWithPath: "/usr/bin/curl")
        } else {
            updateCheckTask?.launchPath = "/usr/bin/curl"
        }
    }
    
    private func setupInfoWindow(latestVersion: String, currentVersion: String) {
        if latestVersion.isEmpty {
            checkInfoWindow?.alertStyle = .critical
            checkInfoWindow?.messageText = "Error"
            checkInfoWindow?.informativeText = "Failed to get latest info for NuwaStone."
        } else if latestVersion == currentVersion {
            checkInfoWindow?.messageText = "You're up-to-date!"
            checkInfoWindow?.informativeText = "NuwaStone \(currentVersion) is the latest version."
        } else {
            checkInfoWindow?.messageText = "You're out-of-date!"
            checkInfoWindow?.informativeText = "Newer version \(latestVersion) is currently avaliable."
            checkInfoWindow?.addButton(withTitle: "Ignore")
            checkInfoWindow?.addButton(withTitle: "Update")
        }
    }
    
    private func launchCheckTask() -> String? {
        var output = Data()

        if #available(macOS 10.13, *) {
            try? updateCheckTask?.run()
        } else {
            updateCheckTask?.launch()
        }

        if #available(macOS 10.15.4, *) {
            guard let value = try? checkResultPipe?.fileHandleForReading.readToEnd() else {
                return nil
            }
            output = value
        } else {
            guard let value = checkResultPipe?.fileHandleForReading.readDataToEndOfFile() else {
                return nil
            }
            output = value
        }

        guard let result = String(data: output, encoding: .utf8) else {
            return nil
        }
        return result
    }
    
    @IBAction func cancelButtonClicked(_ sender: NSButton) {
        view.window?.close()
    }
}
