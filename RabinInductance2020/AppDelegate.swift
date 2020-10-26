//
//  AppDelegate.swift
//  RabinInductance2020
//
//  Created by Peter Huber on 2020-10-11.
//

import Cocoa

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {

    @IBOutlet var window: NSWindow!
    @IBOutlet weak var appController: AppController!
    

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        // Insert code here to initialize your application
    }

    func applicationWillTerminate(_ aNotification: Notification) {
        // Insert code here to tear down your application
    }

    func application(_ sender:NSApplication, openFile filename:String) -> Bool
    {
        let fixedFileName = (filename as NSString).expandingTildeInPath
        
        let url = URL(fileURLWithPath: fixedFileName, isDirectory: false)
        
        return appController.doOpen(fileURL: url)
    }
}

