//
//  AppDelegate.swift
//  browseCaster
//
//  Created by Daniel Samchenko on 2026-01-06.
//


import UIKit
import GoogleCast

final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {

        let criteria = GCKDiscoveryCriteria(applicationID: kGCKDefaultMediaReceiverApplicationID)
        let options = GCKCastOptions(discoveryCriteria: criteria)

        // Keep default behavior: discovery starts when user taps the Cast button the first time.
        // (This aligns with Google’s iOS 14+ discovery behavior guidance.) :contentReference[oaicite:1]{index=1}
        options.startDiscoveryAfterFirstTapOnCastButton = true

        GCKCastContext.setSharedInstanceWith(options)

        // Logging: reduce noise (recommended approach is via filter). :contentReference[oaicite:2]{index=2}
        let filter = GCKLoggerFilter()
        filter.minimumLevel = .warning
        GCKLogger.sharedInstance().filter = filter

        return true
    }
}
