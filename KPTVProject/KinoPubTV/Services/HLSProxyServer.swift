//
//  HLSProxyServer.swift
//  KinoPubTV
//
//  A local HTTP proxy server that intercepts HLS manifest requests
//  and modifies audio track NAME attributes to show rich descriptions.
//

import Foundation
import Network

/// Local HTTP proxy server for HLS manifest modification
final class HLSProxyServer {
    
    static let shared = HLSProxyServer()
    
    private var listener: NWListener?
    private var connections: [NWConnection] = []
    private let queue = DispatchQueue(label: "com.kptv.hlsproxy", qos: .userInitiated)
    private let session: URLSession
    
    /// The local port the server is listening on
    private(set) var port: UInt16 = 0
    
    /// Audio tracks for the current playback session (single video at a time)
    private var currentAudioTracks: [AudioTrack] = []
    private let lock = NSLock()
    
    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 300
        self.session = URLSession(configuration: config)
    }
    
    // MARK: - Public API
    
    /// Starts the proxy server if not already running.
    /// Use the async version `startAsync()` to wait for the server to be ready.
    func start() {
        guard listener == nil else { return }
        
        do {
            // Use a random available port
            let params = NWParameters.tcp
            params.allowLocalEndpointReuse = true
            
            listener = try NWListener(using: params, on: .any)
            
            listener?.stateUpdateHandler = { [weak self] state in
                switch state {
                case .ready:
                    if let port = self?.listener?.port?.rawValue {
                        self?.port = port
                        print("🌐 HLS Proxy Server started on port \(port)")
                    }
                case .failed(let error):
                    print("🌐 HLS Proxy Server failed: \(error)")
                    self?.stop()
                default:
                    break
                }
            }
            
            listener?.newConnectionHandler = { [weak self] connection in
                self?.handleConnection(connection)
            }
            
            listener?.start(queue: queue)
        } catch {
            print("🌐 HLS Proxy Server failed to start: \(error)")
        }
    }
    
    /// Starts the proxy server and waits for it to be ready
    func startAsync() async {
        guard listener == nil else { return }
        
        await withCheckedContinuation { continuation in
            do {
                let params = NWParameters.tcp
                params.allowLocalEndpointReuse = true
                
                listener = try NWListener(using: params, on: .any)
                
                listener?.stateUpdateHandler = { [weak self] state in
                    switch state {
                    case .ready:
                        if let port = self?.listener?.port?.rawValue {
                            self?.port = port
                            print("🌐 HLS Proxy Server started on port \(port)")
                            continuation.resume()
                        }
                    case .failed(let error):
                        print("🌐 HLS Proxy Server failed: \(error)")
                        self?.stop()
                        continuation.resume()
                    case .cancelled:
                        continuation.resume()
                    default:
                        break
                    }
                }
                
                listener?.newConnectionHandler = { [weak self] connection in
                    self?.handleConnection(connection)
                }
                
                listener?.start(queue: queue)
            } catch {
                print("🌐 HLS Proxy Server failed to start: \(error)")
                continuation.resume()
            }
        }
    }
    
    /// Whether the server is ready to accept connections
    var isReady: Bool {
        port > 0
    }
    
    /// Stops the proxy server
    func stop() {
        listener?.cancel()
        listener = nil
        connections.forEach { $0.cancel() }
        connections.removeAll()
        port = 0
        print("🌐 HLS Proxy Server stopped")
    }
    
    /// Registers audio tracks for the current playback session
    func registerAudioTracks(_ tracks: [AudioTrack], forURL url: URL) {
        // Apply unique language codes to each track
        let uniqueTracks = tracks.map { $0.withUniqueLanguage() }
        
        lock.lock()
        currentAudioTracks = uniqueTracks
        lock.unlock()
        print("🌐 ✅ Registered \(uniqueTracks.count) audio tracks for current session (with unique language codes)")
        print("🌐    URL: \(url.lastPathComponent)")
        for (i, track) in uniqueTracks.enumerated() {
            let type = track.type?.title ?? "?"
            let author = track.author?.title ?? "?"
            let lang = track.lang ?? "?"
            print("🌐    [\(i)] \(type) - \(author) (\(lang))")
        }
    }
    
    /// Clears audio tracks for the current session
    func clearAudioTracks() {
        lock.lock()
        currentAudioTracks = []
        lock.unlock()
    }
    
    /// Converts an original HLS URL to a proxied URL
    /// This intercepts and modifies the HLS manifest to set proper audio track names
    func proxiedURL(for originalURL: URL, audioTracks: [AudioTrack]) -> URL? {
        guard port > 0 else {
            print("🌐 Proxy server not running")
            return nil
        }
        
        // Register the audio tracks for this session
        registerAudioTracks(audioTracks, forURL: originalURL)
        
        // Encode the original URL as a query parameter
        guard let encodedURL = originalURL.absoluteString.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else {
            return nil
        }
        
        // Return proxied URL that will intercept and modify the manifest
        let proxyURLString = "http://127.0.0.1:\(port)/hls?url=\(encodedURL)"
        return URL(string: proxyURLString)
    }
    
    // MARK: - Private
    
    /// Helper struct to hold parsed HLS audio track information
    private struct HLSAudioTrack {
        let line: String
        let language: String
        let channels: String?
        let groupID: String?
        let name: String
        let nameRange: Range<String.Index>
        let isDefault: Bool
        let autoselect: Bool
    }
    
    private func handleConnection(_ connection: NWConnection) {
        connections.append(connection)
        
        connection.stateUpdateHandler = { [weak self, weak connection] state in
            if case .cancelled = state, let conn = connection {
                self?.connections.removeAll { $0 === conn }
            }
        }
        
        connection.start(queue: queue)
        
        // Receive the HTTP request
        connection.receive(minimumIncompleteLength: 1, maximumLength: 65536) { [weak self] data, _, isComplete, error in
            guard let self = self, let data = data, error == nil else {
                connection.cancel()
                return
            }
            
            self.handleRequest(data: data, connection: connection)
        }
    }
    
    private func handleRequest(data: Data, connection: NWConnection) {
        guard let requestString = String(data: data, encoding: .utf8) else {
            sendErrorResponse(connection: connection, status: 400, message: "Bad Request")
            return
        }
        
        // Parse the HTTP request
        let lines = requestString.components(separatedBy: "\r\n")
        guard let requestLine = lines.first else {
            sendErrorResponse(connection: connection, status: 400, message: "Bad Request")
            return
        }
        
        let parts = requestLine.components(separatedBy: " ")
        guard parts.count >= 2, parts[0] == "GET" else {
            sendErrorResponse(connection: connection, status: 405, message: "Method Not Allowed")
            return
        }
        
        let path = parts[1]
        
        // Parse the URL parameter
        guard path.hasPrefix("/hls?url="),
              let encodedURL = path.dropFirst("/hls?url=".count).removingPercentEncoding,
              let originalURL = URL(string: encodedURL) else {
            sendErrorResponse(connection: connection, status: 400, message: "Missing or invalid URL parameter")
            return
        }
        
        print("🌐 Proxying request for: \(originalURL.lastPathComponent)")
        
        // Fetch the original content
        var request = URLRequest(url: originalURL)
        request.cachePolicy = .reloadIgnoringLocalCacheData
        
        let task = session.dataTask(with: request) { [weak self] data, response, error in
            guard let self = self else { return }
            
            if let error = error {
                print("🌐 Upstream error: \(error)")
                self.sendErrorResponse(connection: connection, status: 502, message: "Upstream error: \(error.localizedDescription)")
                return
            }
            
            guard let data = data, let httpResponse = response as? HTTPURLResponse else {
                print("🌐 No response from upstream")
                self.sendErrorResponse(connection: connection, status: 502, message: "No response from upstream")
                return
            }
            
            print("🌐 Got \(data.count) bytes from upstream, status: \(httpResponse.statusCode)")
            
            var responseData = data
            let contentType = httpResponse.value(forHTTPHeaderField: "Content-Type") ?? "application/vnd.apple.mpegurl"
            
            // If this is an HLS manifest, modify it
            if originalURL.pathExtension == "m3u8" || contentType.contains("mpegurl") {
                if let manifestString = String(data: data, encoding: .utf8) {
                    self.lock.lock()
                    let audioTracks = self.currentAudioTracks
                    let tracksCount = audioTracks.count
                    self.lock.unlock()
                    
                    print("🌐 Processing manifest: \(originalURL.lastPathComponent)")
                    print("🌐    Current audio tracks in memory: \(tracksCount)")
                    
                    let modifiedManifest = self.modifyManifest(manifestString, audioTracks: audioTracks, baseURL: originalURL)
                    responseData = modifiedManifest.data(using: .utf8) ?? data
                    
                    if responseData.count != data.count {
                        print("🌐 ✓ Manifest modified: \(data.count) → \(responseData.count) bytes")
                    } else {
                        print("🌐 ⚠️  Manifest NOT modified (same size)")
                    }
                } else {
                    print("🌐 ⚠️  Could not parse manifest as UTF-8 string")
                }
            } else {
                print("🌐 ⏩ Skipping non-manifest file: \(originalURL.lastPathComponent)")
            }
            
            // Return response with same Content-Type as CDN
            self.sendSuccessResponse(connection: connection, data: responseData, contentType: contentType)
        }
        task.resume()
    }
    
    private func modifyManifest(_ manifest: String, audioTracks: [AudioTrack], baseURL: URL) -> String {
        var modifiedManifest = manifest
        
        // Detect manifest type
        let isMasterPlaylist = manifest.contains("#EXT-X-MEDIA:TYPE=AUDIO") || 
                              manifest.contains("#EXT-X-STREAM-INF")
        let isMediaPlaylist = manifest.contains("#EXTINF:")
        
        // Rewrite relative URLs to absolute proxied URLs (for all manifest types)
        modifiedManifest = rewriteURLsInManifest(modifiedManifest, baseURL: baseURL)
        
        // ONLY modify audio track names in MASTER playlist
        if isMasterPlaylist && !audioTracks.isEmpty {
            print("🌐 📝 Processing MASTER playlist (has audio track definitions)")
            print("🌐    Audio tracks registered: \(audioTracks.count)")
            modifiedManifest = modifyAudioTrackNames(modifiedManifest, audioTracks: audioTracks)
        } else if isMediaPlaylist {
            print("🌐 ⏩ Skipping MEDIA/VARIANT playlist (no audio track definitions)")
        } else if !isMasterPlaylist && audioTracks.isEmpty {
            print("🌐 ⏩ Skipping playlist (no audio tracks to inject, isEmpty: \(audioTracks.isEmpty))")
        } else if isMasterPlaylist && audioTracks.isEmpty {
            print("🌐 ⚠️  WARNING: Master playlist but NO audio tracks registered!")
            print("🌐    This means registerAudioTracks() wasn't called or tracks array is empty")
        }
        
        return modifiedManifest
    }
    
    private func rewriteURLsInManifest(_ manifest: String, baseURL: URL) -> String {
        var result = manifest
        let lines = manifest.components(separatedBy: "\n")
        
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            
            // Skip comments and empty lines, but check for URI= attributes in EXT-X-MEDIA
            if trimmed.hasPrefix("#") {
                // Check for URI= in EXT-X-MEDIA tags - these reference audio/subtitle playlists
                if trimmed.hasPrefix("#EXT-X-MEDIA") {
                    if let uriRange = line.range(of: #"URI="([^"]*)""#, options: .regularExpression) {
                        let uriMatch = String(line[uriRange])
                        let uri = String(uriMatch.dropFirst(5).dropLast(1)) // Remove URI=" and "
                        
                        // Only proxy .m3u8 files, not segments
                        guard uri.contains(".m3u8") else { continue }
                        
                        if !uri.hasPrefix("http") {
                            if let absoluteURL = URL(string: uri, relativeTo: baseURL)?.absoluteURL,
                               let proxiedURI = createProxiedURLString(for: absoluteURL) {
                                let newURIAttribute = "URI=\"\(proxiedURI)\""
                                result = result.replacingOccurrences(of: uriMatch, with: newURIAttribute)
                            }
                        } else if let url = URL(string: uri),
                                  let proxiedURI = createProxiedURLString(for: url) {
                            let newURIAttribute = "URI=\"\(proxiedURI)\""
                            result = result.replacingOccurrences(of: uriMatch, with: newURIAttribute)
                        }
                    }
                }
                continue
            }
            
            // Handle playlist references (lines that are URLs or relative paths)
            if trimmed.isEmpty { continue }
            
            // Only proxy .m3u8 playlist references, not media segments (.ts, .m4s, etc.)
            if trimmed.hasSuffix(".m3u8") || trimmed.contains(".m3u8?") {
                let originalRef = trimmed
                
                if !originalRef.hasPrefix("http") {
                    if let absoluteURL = URL(string: originalRef, relativeTo: baseURL)?.absoluteURL,
                       let proxiedPath = createProxiedURLString(for: absoluteURL) {
                        result = result.replacingOccurrences(of: originalRef, with: proxiedPath)
                    }
                } else if let url = URL(string: originalRef),
                          let proxiedPath = createProxiedURLString(for: url) {
                    result = result.replacingOccurrences(of: originalRef, with: proxiedPath)
                }
            }
        }
        
        return result
    }
    
    private func createProxiedURLString(for url: URL) -> String? {
        guard let encodedURL = url.absoluteString.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else {
            return nil
        }
        return "http://127.0.0.1:\(port)/hls?url=\(encodedURL)"
    }
    
    private func modifyAudioTrackNames(_ manifest: String, audioTracks: [AudioTrack]) -> String {
        var modifiedManifest = manifest
        let lines = manifest.components(separatedBy: "\n")
        let audioLines = lines.filter { $0.hasPrefix("#EXT-X-MEDIA:TYPE=AUDIO") }
        
        print("🌐    Found \(audioLines.count) audio track lines in manifest, have \(audioTracks.count) API tracks")
        
        guard !audioLines.isEmpty else {
            print("🌐    ⚠️  No #EXT-X-MEDIA:TYPE=AUDIO lines found!")
            return manifest
        }
        
        // Debug: Print API tracks
        print("🌐    API tracks available:")
        for (i, track) in audioTracks.enumerated() {
            let type = track.type?.title ?? "?"
            let author = track.author?.title ?? "?"
            let lang = track.lang ?? "?"
            let codec = track.codec ?? "?"
            let index = track.index != nil ? String(track.index!) : "?"
            print("🌐      [\(i)]: type=\"\(type)\" author=\"\(author)\" lang=\"\(lang)\" codec=\"\(codec)\" index=\(index)")
        }
        
        // Parse all HLS audio tracks
        var hlsTracks: [HLSAudioTrack] = []
        for line in audioLines {
            guard let nameRange = extractAttributeRange(from: line, attribute: "NAME"),
                  let currentName = extractAttributeValue(from: line, attribute: "NAME") else {
                continue
            }
            
            let language = extractAttributeValue(from: line, attribute: "LANGUAGE")?.lowercased() ?? "unknown"
            let channels = extractAttributeValue(from: line, attribute: "CHANNELS")
            let groupID = extractAttributeValue(from: line, attribute: "GROUP-ID")
            let isDefault = extractAttributeValue(from: line, attribute: "DEFAULT")?.uppercased() == "YES"
            let autoselect = extractAttributeValue(from: line, attribute: "AUTOSELECT")?.uppercased() == "YES"
            
            hlsTracks.append(HLSAudioTrack(
                line: line,
                language: language,
                channels: channels,
                groupID: groupID,
                name: currentName,
                nameRange: nameRange,
                isDefault: isDefault,
                autoselect: autoselect
            ))
        }
        
        // Debug: Print all HLS track names
        print("🌐    HLS tracks in manifest:")
        for (i, track) in hlsTracks.enumerated() {
            print("🌐      HLS[\(i)]: \"\(track.name)\" lang=\(track.language) group=\(track.groupID ?? "nil")")
        }
        
        // Parse track number from NAME like "01. Studio Name (RUS)" or "01 - Studio Name (RUS)"
        func extractTrackNumber(from name: String) -> Int? {
            // Match both "01." and "01 -" formats
            let pattern = #"^(\d+)[\.\s\-]"#
            guard let regex = try? NSRegularExpression(pattern: pattern),
                  let match = regex.firstMatch(in: name, range: NSRange(name.startIndex..., in: name)),
                  let numberRange = Range(match.range(at: 1), in: name),
                  let number = Int(name[numberRange]) else {
                return nil
            }
            return number
        }
        
        // Group API tracks by language
        var apiTracksByLanguage: [String: [(track: AudioTrack, originalIndex: Int)]] = [:]
        for (index, track) in audioTracks.enumerated() {
            let lang = normalizeLanguageCode(track.lang?.lowercased() ?? "unknown")
            apiTracksByLanguage[lang, default: []].append((track, index))
        }
        
        // Track which API tracks we've used (by originalIndex) - reset per language pass
        var usedAPIIndicesPerPass: [String: Set<Int>] = [:] // [language: Set of used API indices]
        
        // First pass: Match numbered tracks to establish baseline
        var numberedMatches: [(hlsIndex: Int, apiIndex: Int)] = []
        for (hlsIndex, hlsTrack) in hlsTracks.enumerated() {
            let normalizedLang = normalizeLanguageCode(hlsTrack.language)
            if let trackNumber = extractTrackNumber(from: hlsTrack.name),
               let apiTracksForLang = apiTracksByLanguage[normalizedLang],
               trackNumber > 0 && trackNumber <= apiTracksForLang.count {
                let apiIndex = apiTracksForLang[trackNumber - 1].originalIndex
                numberedMatches.append((hlsIndex, apiIndex))
                usedAPIIndicesPerPass[normalizedLang, default: []].insert(apiIndex)
            }
        }
        
        // Match each HLS track to corresponding API track
        for (hlsIndex, hlsTrack) in hlsTracks.enumerated() {
            let normalizedLang = normalizeLanguageCode(hlsTrack.language)
            let apiTracksForLang = apiTracksByLanguage[normalizedLang] ?? []
            
            guard !apiTracksForLang.isEmpty else {
                print("🌐       ⚠️  Track \(hlsIndex): No API tracks for language '\(normalizedLang)'")
                continue
            }
            
            // Extract track number from HLS name (e.g., "01. ..." -> 1)
            let trackNumber = extractTrackNumber(from: hlsTrack.name)
            
            // Find matching API track
            let apiPair: (track: AudioTrack, originalIndex: Int)
            let indexInLanguage: Int
            
            if let trackNum = trackNumber, trackNum > 0, trackNum <= apiTracksForLang.count {
                // Has number: "01. Studio (RUS)" -> use that number
                apiPair = apiTracksForLang[trackNum - 1]
                indexInLanguage = trackNum - 1
            } else {
                // No number: "Track 3 (RUS)" -> find next unused API track
                let alreadyUsed = usedAPIIndicesPerPass[normalizedLang] ?? []
                
                // Find first unused API track for this language
                if let unusedPair = apiTracksForLang.first(where: { !alreadyUsed.contains($0.originalIndex) }) {
                    apiPair = unusedPair
                    usedAPIIndicesPerPass[normalizedLang, default: []].insert(apiPair.originalIndex)
                    indexInLanguage = apiTracksForLang.firstIndex(where: { $0.originalIndex == apiPair.originalIndex }) ?? 0
                } else {
                    // All used - this shouldn't happen if API data is complete
                    // Fall back to modulo
                    let position = hlsTracks.prefix(hlsIndex + 1).filter { $0.language == hlsTrack.language }.count - 1
                    let index = position % apiTracksForLang.count
                    apiPair = apiTracksForLang[index]
                    indexInLanguage = index
                }
            }
            
            // Build enriched name using API metadata
            // Use API track's global index if available, otherwise fall back to originalIndex
            let globalIndex = apiPair.track.index ?? (apiPair.originalIndex + 1)
            let newName = buildEnrichedTrackName(
                apiTrack: apiPair.track,
                hlsTrack: hlsTrack,
                globalIndex: globalIndex
            )
            
            print("🌐       🔍 DEBUG Track \(hlsIndex): newName=\"\(newName)\" vs hlsTrack.name=\"\(hlsTrack.name)\"")
            print("🌐       🔍 API: author=\(apiPair.track.author?.title ?? "nil") type=\(apiPair.track.type?.title ?? "nil")")
            
            // Only modify if:
            // 1. Name actually changed, AND
            // 2. New name has meaningful content (not just number)
            let hasContent = !newName.matches(#"^\d+\.$"#)
            
            print("🌐       🔍 hasContent=\(hasContent), namesMatch=\(newName == hlsTrack.name)")
            
            if newName != hlsTrack.name && hasContent {
                // Replace NAME attribute
                var newLine = hlsTrack.line.replacingCharacters(in: hlsTrack.nameRange, with: "NAME=\"\(newName)\"")
                
                // Replace LANGUAGE attribute with unique code from modified track
                let uniqueLang = apiPair.track.lang ?? "und"
                if let langPattern = try? NSRegularExpression(pattern: #"LANGUAGE="[^"]*""#),
                   let match = langPattern.firstMatch(in: newLine, range: NSRange(newLine.startIndex..., in: newLine)),
                   let range = Range(match.range, in: newLine) {
                    newLine = newLine.replacingCharacters(in: range, with: "LANGUAGE=\"\(uniqueLang)\"")
                }
                
                modifiedManifest = modifiedManifest.replacingOccurrences(of: hlsTrack.line, with: newLine)
                print("🌐       ✓ Track \(hlsIndex) (API[\(apiPair.originalIndex)]): \"\(hlsTrack.name)\" → \"\(newName)\" lang=\(uniqueLang)")
                print("🌐         OUTPUT: \(newLine)")
            } else if !hasContent {
                print("🌐       - Track \(hlsIndex) (API[\(apiPair.originalIndex)]): \"\(hlsTrack.name)\" (kept - API has no metadata)")
            } else {
                print("🌐       = Track \(hlsIndex) (API[\(apiPair.originalIndex)]): \"\(hlsTrack.name)\" (unchanged)")
            }
        }
        
        print("🌐    ✅ Processed \(hlsTracks.count) audio track entries")
        print("🌐    📤 OUTPUT SAMPLE (first 3 audio lines):")
        let outputLines = modifiedManifest.components(separatedBy: "\n").filter { $0.hasPrefix("#EXT-X-MEDIA:TYPE=AUDIO") }
        for (i, line) in outputLines.prefix(3).enumerated() {
            print("🌐      [\(i)]: \(line)")
        }
        return modifiedManifest
    }
    
    /// Builds enriched track name with codec info from HLS if not in API
    private func buildEnrichedTrackName(apiTrack: AudioTrack, hlsTrack: HLSAudioTrack, globalIndex: Int) -> String {
        var parts: [String] = []
        
        // Add index prefix with dash separator: "01."
        parts.append(String(format: "%02d.", globalIndex))
        
        // Check what metadata we have
        let authorTitle = apiTrack.author?.title
        let hasAuthor = authorTitle != nil && !authorTitle!.isEmpty && authorTitle != "?"
        
        let typeTitle = apiTrack.type?.title
        let hasType = typeTitle != nil && !typeTitle!.isEmpty && typeTitle != "?"
        
        print("🌐       🔧 buildEnrichedTrackName: index=\(globalIndex) hasAuthor=\(hasAuthor) hasType=\(hasType)")
        
        // Author/Studio name (LostFilm, Paramount Comedy, MTV, etc.)
        if hasAuthor {
            parts.append(authorTitle!)
        }
        
        // Audio type (дубляж, двухголосый, оригинал, etc.)
        // If we have author, show type in parentheses (lowercase)
        // If no author, show type without parentheses (as main identifier)
        if hasType {
            if hasAuthor {
                parts.append("(\(typeTitle!.lowercased()))")
            } else {
                // No author - use type as main identifier (without parentheses)
                parts.append(typeTitle!)
            }
        }
        
        print("🌐       🔧 After author/type: parts.count=\(parts.count) parts=\(parts)")
        
        // If we have NEITHER type nor author, try to extract from HLS name
        if !hasType && !hasAuthor {
            print("🌐       🔧 No API metadata, trying HLS name extraction from: \"\(hlsTrack.name)\"")
            
            // Try pattern 1: "01. Studio Name (RUS)" -> "Studio Name"
            let pattern1 = #"^\d+\.\s*(.+?)\s*\([A-Z]{3}\)"#
            if let regex = try? NSRegularExpression(pattern: pattern1),
               let match = regex.firstMatch(in: hlsTrack.name, range: NSRange(hlsTrack.name.startIndex..., in: hlsTrack.name)),
               let textRange = Range(match.range(at: 1), in: hlsTrack.name) {
                let extractedText = String(hlsTrack.name[textRange]).trimmingCharacters(in: .whitespaces)
                print("🌐       🔧 Pattern1 matched: \"\(extractedText)\"")
                if !extractedText.isEmpty && !extractedText.hasPrefix("Track") && !extractedText.matches(#"^Audio\s+\d+$"#) {
                    parts.append(extractedText)
                    print("🌐       🔧 Pattern1 ACCEPTED")
                }
            } else {
                // Try pattern 2: "Track 3 (RUS)" or "русский" -> extract text before language
                let pattern2 = #"^(.+?)\s*\([A-Z]{3}\)"#
                if let regex = try? NSRegularExpression(pattern: pattern2),
                   let match = regex.firstMatch(in: hlsTrack.name, range: NSRange(hlsTrack.name.startIndex..., in: hlsTrack.name)),
                   let textRange = Range(match.range(at: 1), in: hlsTrack.name) {
                    let extractedText = String(hlsTrack.name[textRange]).trimmingCharacters(in: .whitespaces)
                    print("🌐       🔧 Pattern2 matched: \"\(extractedText)\"")
                    // Only use if it's not generic "Track N" or "Audio N"
                    if !extractedText.isEmpty && !extractedText.hasPrefix("Track") && !extractedText.matches(#"^Audio\s+\d+$"#) {
                        parts.append(extractedText)
                        print("🌐       🔧 Pattern2 ACCEPTED")
                    }
                }
            }
            
            print("🌐       🔧 After pattern extraction: parts.count=\(parts.count)")
            
            // Still no description - add language name and Default/Alternate marker
            if parts.count == 1 {
                let langName = getLanguageName(from: hlsTrack.language)
                parts.append(langName)
                print("🌐       🔧 Adding language name: \"\(langName)\"")
                
                if hlsTrack.isDefault {
                    parts.append("(Default)")
                    print("🌐       🔧 Adding (Default) marker")
                }
            }
        }
        
        // Codec - prefer API data, fallback to detection from HLS name/channels
        let codec = detectCodec(apiTrack: apiTrack, hlsTrack: hlsTrack)
        if let codecStr = codec {
            parts.append("(\(codecStr))")
        }
        
        let result = parts.joined(separator: " ")
        print("🌐       🔧 FINAL result: \"\(result)\"")
        return result.isEmpty ? "Audio \(globalIndex)" : result
    }
    
    /// Builds CHARACTERISTICS attribute - REMOVED as it doesn't help tvOS display NAME
    private func buildCharacteristics(apiTrack: AudioTrack, hlsTrack: HLSAudioTrack) -> String {
        return ""
    }
    
    /// Detects codec from API or HLS track data
    private func detectCodec(apiTrack: AudioTrack, hlsTrack: HLSAudioTrack) -> String? {
        // First check API data
        if let apiCodec = apiTrack.codec?.uppercased(), !apiCodec.isEmpty {
            return apiCodec == "AAC" ? nil : apiCodec // Don't show AAC since it's default
        }
        
        // Try to detect from HLS track name (sometimes contains codec info)
        let hlsNameLower = hlsTrack.name.lowercased()
        if hlsNameLower.contains("ac3") || hlsNameLower.contains("ac-3") {
            return "AC3"
        }
        if hlsNameLower.contains("eac3") || hlsNameLower.contains("e-ac-3") {
            return "EAC3"
        }
        if hlsNameLower.contains("aac") {
            return nil // AAC is default, don't show
        }
        
        // Check channels (AC3 typically has 6 channels, AAC has 2)
        if let channels = hlsTrack.channels {
            if channels.hasPrefix("6") {
                return "AC3" // Likely 5.1
            }
        }
        
        return nil
    }
    
    private func extractAttributeRange(from line: String, attribute: String) -> Range<String.Index>? {
        let pattern = "\(attribute)=\"[^\"]*\""
        return line.range(of: pattern, options: .regularExpression)
    }
    
    private func extractAttributeValue(from line: String, attribute: String) -> String? {
        let pattern = "\(attribute)=\"([^\"]*)\""
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: line, range: NSRange(line.startIndex..., in: line)),
              let valueRange = Range(match.range(at: 1), in: line) else {
            return nil
        }
        return String(line[valueRange])
    }
    
    private func normalizeLanguageCode(_ code: String) -> String {
        let lowered = code.lowercased()
        switch lowered {
        case "rus", "ru": return "ru"
        case "eng", "en": return "en"
        case "ukr", "uk": return "uk"
        default: return String(lowered.prefix(2))
        }
    }
    
    private func getLanguageName(from code: String) -> String {
        let normalized = normalizeLanguageCode(code)
        switch normalized {
        case "ru": return "Russian"
        case "en": return "English"
        case "uk": return "Ukrainian"
        case "ja": return "Japanese"
        case "de": return "German"
        case "fr": return "French"
        case "es": return "Spanish"
        case "it": return "Italian"
        case "pt": return "Portuguese"
        case "zh": return "Chinese"
        case "ko": return "Korean"
        default: return code.uppercased()
        }
    }
    
    // MARK: - HTTP Response Helpers
    
    private func sendSuccessResponse(connection: NWConnection, data: Data, contentType: String) {
        // Build proper HTTP response with correct line endings
        var response = Data()
        let headerString = "HTTP/1.1 200 OK\r\nContent-Type: \(contentType)\r\nContent-Length: \(data.count)\r\nAccess-Control-Allow-Origin: *\r\nConnection: close\r\n\r\n"
        response.append(headerString.data(using: .utf8)!)
        response.append(data)
        
        connection.send(content: response, completion: .contentProcessed { _ in
            connection.cancel()
        })
    }
    
    private func sendErrorResponse(connection: NWConnection, status: Int, message: String) {
        let body = message.data(using: .utf8) ?? Data()
        let headerString = "HTTP/1.1 \(status) \(message)\r\nContent-Type: text/plain\r\nContent-Length: \(body.count)\r\nConnection: close\r\n\r\n"
        var response = Data()
        response.append(headerString.data(using: .utf8)!)
        response.append(body)
        
        connection.send(content: response, completion: .contentProcessed { _ in
            connection.cancel()
        })
    }
}

// MARK: - AudioTrack Extension for HLS

extension AudioTrack {
    /// Formats the audio track for HLS manifest NAME attribute
    var formattedForHLSManifest: String {
        var parts: [String] = []
        
        // Add index prefix if available
        if let idx = index {
            parts.append(String(format: "%02d.", idx + 1))
        }
        
        // Audio type (Дубляж, Многоголосый, etc.)
        if let typeTitle = type?.title, !typeTitle.isEmpty {
            parts.append(typeTitle)
        }
        
        // Author (LostFilm, etc.)
        if let authorTitle = author?.title, !authorTitle.isEmpty {
            parts.append(authorTitle)
        }
        
        // Language code
        if let langCode = lang, !langCode.isEmpty {
            parts.append("(\(langCode.uppercased()))")
        }
        
        // Codec
        if let codecStr = codec, codecStr.lowercased() == "ac3" {
            parts.append("(AC3)")
        }
        
        let result = parts.joined(separator: " ")
        return result.isEmpty ? "Audio \(index ?? 0)" : result
    }
}

// MARK: - String Extension for Pattern Matching

extension String {
    func matches(_ pattern: String) -> Bool {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return false }
        let range = NSRange(startIndex..., in: self)
        return regex.firstMatch(in: self, range: range) != nil
    }
}
