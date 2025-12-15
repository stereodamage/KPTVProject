//
//  User.swift
//  KinoPubTV
//

import Foundation

// MARK: - User Response

struct UserResponse: Codable {
    let user: User
}

// MARK: - User

struct User: Codable {
    let username: String
    let regDate: Int?
    let subscription: Subscription?
    
    enum CodingKeys: String, CodingKey {
        case username
        case regDate = "reg_date"
        case subscription
    }
}

// MARK: - Subscription

struct Subscription: Codable {
    let active: Bool?
    let endTime: Int?
    let days: Double?
    
    enum CodingKeys: String, CodingKey {
        case active
        case endTime = "end_time"
        case days
    }
}

// MARK: - Device

struct DeviceResponse: Codable {
    let device: Device?
    let settings: DeviceSettings?
}

struct Device: Codable {
    let id: Int
    let title: String?
    let hardware: String?
    let software: String?
    let settings: DeviceSettings?
}

struct DeviceSettings: Codable {
    let supportHevc: SettingValue?
    let support4k: SettingValue?
    let mixedPlaylist: SettingValue?
    let streamingType: StreamingTypeSetting?
    let serverLocation: ServerLocationSetting?
    
    enum CodingKeys: String, CodingKey {
        case supportHevc, support4k, mixedPlaylist, streamingType, serverLocation
    }
}

struct SettingValue: Codable {
    let value: Int?
}

struct StreamingTypeSetting: Codable {
    let value: [StreamingOption]?
}

struct ServerLocationSetting: Codable {
    let value: [ServerOption]?
}

struct StreamingOption: Codable, Identifiable {
    let id: Int
    let label: String?
    let selected: Int?
}

struct ServerOption: Codable, Identifiable {
    let id: Int
    let label: String?
    let location: String?
    let selected: Int?
}
