//
//  SettingsViewModel.swift
//  KinoPubTV
//

import Foundation
import UIKit

@MainActor
@Observable
final class SettingsViewModel {
    var user: User?
    var device: Device?
    var deviceName: String = ""
    
    var isLoading = false
    var error: String?
    
    private let contentService = ContentService.shared
    
    var subscriptionDaysLeft: Int {
        Int(user?.subscription?.days ?? 0)
    }
    
    var subscriptionEndDate: Date? {
        guard let endTime = user?.subscription?.endTime else { return nil }
        return Date(timeIntervalSince1970: TimeInterval(endTime))
    }
    
    var registrationDate: Date? {
        guard let regDate = user?.regDate else { return nil }
        return Date(timeIntervalSince1970: TimeInterval(regDate))
    }
    
    func loadUserInfo() async {
        isLoading = true
        error = nil
        
        do {
            let token = try await AuthService.shared.getValidToken()
            
            async let userResponse = contentService.getUserInfo(accessToken: token)
            async let deviceResponse = contentService.getDeviceInfo(accessToken: token)
            
            let (u, d) = try await (userResponse, deviceResponse)
            
            user = u.user
            device = d.device
            deviceName = d.device?.title ?? ""
            
        } catch {
            self.error = error.localizedDescription
        }
        
        isLoading = false
    }
    
    func logout() {
        AuthService.shared.logout()
    }
    
    var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }
    
    var buildNumber: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
    }
    
    var deviceIdentifier: String {
        UIDevice.current.identifierForVendor?.uuidString ?? "Unknown"
    }
}
