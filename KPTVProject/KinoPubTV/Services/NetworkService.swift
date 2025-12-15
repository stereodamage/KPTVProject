//
//  NetworkService.swift
//  KinoPubTV
//

import Foundation

// MARK: - Network Error

enum NetworkError: Error, LocalizedError {
    case invalidURL
    case noData
    case decodingError(Error)
    case serverError(Int)
    case unauthorized
    case networkError(Error)
    case timeout
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Неверный URL"
        case .noData:
            return "Нет данных"
        case .decodingError(let error):
            return "Ошибка декодирования: \(error.localizedDescription)"
        case .serverError(let code):
            return "Ошибка сервера: \(code)"
        case .unauthorized:
            return "Требуется авторизация"
        case .networkError(let error):
            return "Ошибка сети: \(error.localizedDescription)"
        case .timeout:
            return "Превышено время ожидания"
        }
    }
    
    var isRetryable: Bool {
        switch self {
        case .timeout, .networkError:
            return true
        case .serverError(let code):
            return code >= 500
        default:
            return false
        }
    }
}

// MARK: - Network Service

actor NetworkService {
    static let shared = NetworkService()
    
    private let session: URLSession
    
    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 60
        // Improve connection handling
        config.waitsForConnectivity = true
        config.allowsConstrainedNetworkAccess = true
        config.allowsExpensiveNetworkAccess = true
        self.session = URLSession(configuration: config)
    }
    
    // MARK: - Generic Request
    
    func request<T: Decodable>(_ endpoint: APIEndpoint, retryCount: Int = 2) async throws -> T {
        var lastError: Error?
        
        for attempt in 0...retryCount {
            do {
                return try await performRequest(endpoint)
            } catch let error as NetworkError where error.isRetryable && attempt < retryCount {
                lastError = error
                // Exponential backoff: 1s, 2s, 4s...
                let delay = UInt64(pow(2.0, Double(attempt))) * 1_000_000_000
                try? await Task.sleep(nanoseconds: delay)
                continue
            } catch {
                throw error
            }
        }
        
        throw lastError ?? NetworkError.networkError(NSError(domain: "NetworkService", code: -1))
    }
    
    private func performRequest<T: Decodable>(_ endpoint: APIEndpoint) async throws -> T {
        guard let url = endpoint.url else {
            throw NetworkError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = endpoint.method.rawValue
        request.httpBody = endpoint.body
        
        for (key, value) in endpoint.headers {
            request.setValue(value, forHTTPHeaderField: key)
        }
        
        do {
            let (data, response) = try await session.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw NetworkError.noData
            }
            
            switch httpResponse.statusCode {
            case 200...299:
                do {
                    let decoder = JSONDecoder()
                    return try decoder.decode(T.self, from: data)
                } catch {
                    #if DEBUG
                    print("Decoding error: \(error)")
                    if let jsonString = String(data: data, encoding: .utf8) {
                        print("Response: \(jsonString.prefix(1500))")
                    }
                    #endif
                    throw NetworkError.decodingError(error)
                }
            case 401:
                throw NetworkError.unauthorized
            default:
                throw NetworkError.serverError(httpResponse.statusCode)
            }
        } catch let error as NetworkError {
            throw error
        } catch let error as URLError where error.code == .timedOut {
            throw NetworkError.timeout
        } catch {
            throw NetworkError.networkError(error)
        }
    }
    
    // MARK: - Request without response body
    
    func requestVoid(_ endpoint: APIEndpoint) async throws {
        guard let url = endpoint.url else {
            throw NetworkError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = endpoint.method.rawValue
        request.httpBody = endpoint.body
        
        for (key, value) in endpoint.headers {
            request.setValue(value, forHTTPHeaderField: key)
        }
        
        let (_, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NetworkError.noData
        }
        
        switch httpResponse.statusCode {
        case 200...299:
            return
        case 401:
            throw NetworkError.unauthorized
        default:
            throw NetworkError.serverError(httpResponse.statusCode)
        }
    }
}
