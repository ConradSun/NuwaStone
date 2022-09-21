//
//  PrefsViewController.swift
//  NuwaClient
//
//  Created by ConradSun on 2022/9/18.
//

import Cocoa

class PrefsViewController: NSViewController {
    @IBOutlet weak var operatePopup: NSPopUpButton!
    @IBOutlet weak var filterPopup: NSPopUpButton!
    @IBOutlet weak var pathView: NSTextView!
    
    var eventProvider: NuwaEventProviderProtocol?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        if #available(macOS 10.16, *) {
            eventProvider = SextManager.shared
        }
        else {
            eventProvider = KextManager.shared
        }
    }
    
    @IBAction func operateMenuSelected(_ sender: NSPopUpButton) {
        pathView.string = ""
        if operatePopup.selectedTag() != NuwaPrefOpt.Display.rawValue {
            return
        }
        
        let menu = UInt8(filterPopup.selectedTag())
        switch menu {
        case NuwaMuteType.FilterFileEvent.rawValue:
            pathView.string = PrefPathList.shared.filterFileList.joined(separator: "\n")
        case NuwaMuteType.FilterNetEvent.rawValue:
            pathView.string = PrefPathList.shared.filterNetworkList.joined(separator: "\n")
        case NuwaMuteType.AllowExec.rawValue:
            let allowDict = PrefPathList.shared.authExecDict.filter { $0.value == true }
            pathView.string = allowDict.keys.joined(separator: "\n")
        case NuwaMuteType.DenyExec.rawValue:
            let denyDict = PrefPathList.shared.authExecDict.filter { $0.value == false }
            pathView.string = denyDict.keys.joined(separator: "\n")
        default:
            return
        }
    }
    
    @IBAction func filterMenuSelected(_ sender: NSPopUpButton) {
        if operatePopup.selectedTag() != NuwaPrefOpt.Display.rawValue {
            return
        }
        
        operateMenuSelected(operatePopup)
    }
    
    @IBAction func cancelButtonClicked(_ sender: NSButton) {
        view.window?.close()
    }
    
    @IBAction func okButtonClicked(_ sender: NSButton) {
        if operatePopup.selectedTag() == NuwaPrefOpt.Display.rawValue {
            view.window?.close()
        }
        
        let muteType = NuwaMuteType(rawValue: UInt8(filterPopup.selectedTag()))
        let optType = NuwaPrefOpt(rawValue: UInt8(operatePopup.selectedTag()))
        let paths = pathView.string.components(separatedBy: "\n")
        
        switch muteType {
        case .FilterFileEvent:
            PrefPathList.shared.updateWhiteFileList(paths: paths, opt: .Add)
            for path in paths {
                _ = eventProvider!.udpateMuteList(vnodeID: getFileVnodeID(path), type: .FilterFileEvent, opt: optType!)
            }
        case .FilterNetEvent:
            PrefPathList.shared.updateWhiteNetworkList(paths: paths, opt: optType!)
        case .AllowExec:
            PrefPathList.shared.updateExecList(paths: paths, opt: optType!, isWhite: true)
            for path in paths {
                _ = eventProvider!.udpateMuteList(vnodeID: getFileVnodeID(path), type: .AllowExec, opt: optType!)
            }
        case .DenyExec:
            PrefPathList.shared.updateExecList(paths: paths, opt: optType!, isWhite: false)
            for path in paths {
                _ = eventProvider!.udpateMuteList(vnodeID: getFileVnodeID(path), type: .DenyExec, opt: optType!)
            }
        default:
            break
        }
        
        view.window?.close()
    }
}
