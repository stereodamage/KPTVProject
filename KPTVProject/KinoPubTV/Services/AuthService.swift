//
//  AuthService.swift
//  KinoPubTV
//

import Foundation
import SwiftUI

// MARK: - Auth Service

@MainActor
@Observable
final class AuthService {
    static let shared = AuthService()
    
    private(set) var isAuthenticated = false
    private(set) var isLoading = false
    
    var accessToken: String? {
        get { KeychainService.shared.get(key: .accessToken) }
        set {
            if let value = newValue {
                KeychainService.shared.save(key: .accessToken, value: value)
            } else {
                KeychainService.shared.delete(key: .accessToken)
            }
        }
    }
    
    var refreshToken: String? {
        get { KeychainService.shared.get(key: .refreshToken) }
        set {
            if let value = newValue {
                KeychainService.shared.save(key: .refreshToken, value: value)
            } else {
                KeychainService.shared.delete(key: .refreshToken)
            }
        }
    }
    
    private var tokenExpiry: Date? {
        get {
            guard let timestamp = UserDefaults.standard.object(forKey: "tokenExpiry") as? TimeInterval else {
                return nil
            }
            return Date(timeIntervalSince1970: timestamp)
        }
        set {
            if let date = newValue {
                UserDefaults.standard.set(date.timeIntervalSince1970, forKey: "tokenExpiry")
            } else {
                UserDefaults.standard.removeObject(forKey: "tokenExpiry")
            }
        }
    }
    
    private init() {
        checkAuthentication()
    }
    
    // MARK: - Check Authentication
    
    func checkAuthentication() {
        if let token = accessToken, !token.isEmpty {
            if let expiry = tokenExpiry, expiry > Date().addingTimeInterval(600) {
                isAuthenticated = true
            } else if refreshToken != nil {
                Task {
                    do {
                        try await refreshAccessToken()
                        isAuthenticated = true
                    } catch {
                        isAuthenticated = false
                    }
                }
            } else {
                isAuthenticated = false
            }
        } else {
            isAuthenticated = false
        }
    }
    
    // MARK: - Get Device Code
    
    func getDeviceCode() async throws -> DeviceCodeResponse {
        let endpoint = APIEndpoint.getDeviceCode()
        return try await NetworkService.shared.request(endpoint)
    }
    
    // MARK: - Check Device Token
    
    func checkDeviceToken(code: String) async throws -> TokenResponse {
        let endpoint = APIEndpoint.checkDeviceToken(code: code)
        return try await NetworkService.shared.request(endpoint)
    }
    
    // MARK: - Save Tokens
    
    func saveTokens(_ response: TokenResponse) {
        accessToken = response.accessToken
        refreshToken = response.refreshToken
        tokenExpiry = Date().addingTimeInterval(TimeInterval(response.expiresIn))
        isAuthenticated = true
    }
    
    // MARK: - Refresh Token
    
    func refreshAccessToken() async throws {
        guard let token = refreshToken else {
            throw AuthError.expiredToken
        }
        
        let endpoint = APIEndpoint.refreshToken(token)
        let response: TokenResponse = try await NetworkService.shared.request(endpoint)
        saveTokens(response)
    }
    
    // MARK: - Logout
    
    func logout() {
        accessToken = nil
        refreshToken = nil
        tokenExpiry = nil
        isAuthenticated = false
    }
    
    // MARK: - Get Valid Token
    
    func getValidToken() async throws -> String {
        if let expiry = tokenExpiry, expiry <= Date().addingTimeInterval(600) {
            try await refreshAccessToken()
        }
        
        guard let token = accessToken else {
            throw AuthError.expiredToken
        }
        
        return token
    }
}

// MARK: - Keychain Service

final class KeychainService {
    static let shared = KeychainService()
    
    enum Key: String {
        case accessToken = "com.kinopubtv.accessToken"
        case refreshToken = "com.kinopubtv.refreshToken"
    }
    
    private init() {}
    
    func save(key: Key, value: String) {
        let data = Data(value.utf8)
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key.rawValue,
            kSecValueData as String: data
        ]
        
        SecItemDelete(query as CFDictionary)
        SecItemAdd(query as CFDictionary, nil)
    }
    
    func get(key: Key) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key.rawValue,
            kSecReturnData as String: true
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        guard status == errSecSuccess,
              let data = result as? Data,
              let string = String(data: data, encoding: .utf8) else {
            return nil
        }
        
        return string
    }
    
    func delete(key: Key) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key.rawValue
        ]
        
        SecItemDelete(query as CFDictionary)
    }
}
