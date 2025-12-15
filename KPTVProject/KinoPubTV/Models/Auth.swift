//
//  Auth.swift
//  KinoPubTV
//

import Foundation

// MARK: - Device Code Response

struct DeviceCodeResponse: Codable {
    let code: String
    let userCode: String
    let verificationUri: String
    let expiresIn: Int
    let interval: Int
    
    enum CodingKeys: String, CodingKey {
        case code
        case userCode = "user_code"
        case verificationUri = "verification_uri"
        case expiresIn = "expires_in"
        case interval
    }
}

// MARK: - Token Response

struct TokenResponse: Codable {
    let accessToken: String
    let refreshToken: String
    let expiresIn: Int
    let tokenType: String?
    
    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
        case expiresIn = "expires_in"
        case tokenType = "token_type"
    }
}

// MARK: - Error Response

struct ErrorResponse: Codable {
    let error: String?
    let errorDescription: String?
    let status: Int?
    
    enum CodingKeys: String, CodingKey {
        case error
        case errorDescription = "error_description"
        case status
    }
}

// MARK: - Auth Error

enum AuthError: Error, LocalizedError {
    case authorizationPending
    case expiredToken
    case invalidGrant
    case networkError(Error)
    case unknown(String)
    
    var errorDescription: String? {
        switch self {
        case .authorizationPending:
            return "Ожидание авторизации"
        case .expiredToken:
            return "Код авторизации истёк"
        case .invalidGrant:
            return "Неверный код авторизации"
        case .networkError(let error):
            return "Ошибка сети: \(error.localizedDescription)"
        case .unknown(let message):
            return message
        }
    }
}
