import Foundation

extension CloudflareAPI {
    private static let maxPageCount = 100

    func request<Response: Decodable>(
        path: String,
        method: String = "GET"
    ) async throws -> Response {
        try await request(path: path, method: method, body: Optional<EmptyRequest>.none)
    }

    func requestEnvelope<Response: Decodable>(
        path: String,
        method: String = "GET"
    ) async throws -> CloudflareEnvelope<Response> {
        let request = try authorizedRequest(
            path: path,
            method: method,
            contentType: "application/json"
        )
        let data = try await performData(for: request)
        return try decodeEnvelope(CloudflareEnvelope<Response>.self, from: data)
    }

    func requestAllPages<Item: Decodable>(
        path: String,
        queryItems: [URLQueryItem] = [],
        perPage: Int? = 100
    ) async throws -> [Item] {
        try await requestAllPages(
            path: path,
            queryItems: queryItems,
            perPage: perPage,
            extractItems: { (items: [Item]) in items }
        )
    }

    func requestAllPages<Response: Decodable, Item>(
        path: String,
        queryItems: [URLQueryItem] = [],
        perPage: Int? = 100,
        extractItems: (Response) -> [Item]
    ) async throws -> [Item] {
        var collected: [Item] = []
        var page = 1
        var cursor: String?

        while page <= Self.maxPageCount {
            var paginationItems: [URLQueryItem] = []
            if let cursor, cursor.isEmpty == false {
                paginationItems.append(URLQueryItem(name: "cursor", value: cursor))
            } else if page > 1 || perPage != nil {
                paginationItems.append(URLQueryItem(name: "page", value: String(page)))
            }
            if let perPage {
                paginationItems.append(URLQueryItem(name: "per_page", value: String(perPage)))
            }

            let requestPath = try appendingQueryItems(
                paginationItems,
                to: path,
                existing: queryItems
            )
            let envelope: CloudflareEnvelope<Response> = try await requestEnvelope(path: requestPath)
            try validateEnvelope(envelope)

            let pageItems = envelope.result.map(extractItems) ?? []
            collected.append(contentsOf: pageItems)

            let nextCursor = envelope.resultInfo?.nextCursor
            if let nextCursor, nextCursor.isEmpty == false, nextCursor != cursor {
                cursor = nextCursor
                page += 1
                continue
            }
            if cursor != nil {
                return collected
            }

            guard shouldContinuePaginating(
                page: page,
                perPage: perPage,
                collectedCount: collected.count,
                pageItemCount: pageItems.count,
                resultInfo: envelope.resultInfo
            ) else {
                return collected
            }

            page += 1
        }

        throw CloudflareAPIError.api("Pagination exceeded the safe page limit.")
    }

    func requestString(
        path: String,
        method: String = "GET"
    ) async throws -> String {
        let request = try authorizedRequest(path: path, method: method)
        let data = try await performData(for: request)

        guard let value = String(data: data, encoding: .utf8) else {
            throw CloudflareAPIError.decoding("Cloudflare returned a non-text export payload.")
        }

        return value
    }

    func rawRequest(
        path: String,
        method: String = "GET",
        contentType: String? = nil,
        bodyData: Data? = nil
    ) async throws -> (Data, HTTPURLResponse) {
        let request = try authorizedRequest(
            path: path,
            method: method,
            contentType: contentType,
            bodyData: bodyData
        )
        return try await performRaw(request: request)
    }

    func requestWithoutResultData(
        path: String,
        method: String = "GET",
        contentType: String,
        bodyData: Data
    ) async throws {
        let request = try authorizedRequest(
            path: path,
            method: method,
            contentType: contentType,
            bodyData: bodyData
        )
        let data = try await performData(for: request)
        try validateEnvelopeSuccess(from: data)
    }

    func requestWithoutResult(
        path: String,
        method: String = "GET"
    ) async throws {
        try await requestWithoutResult(path: path, method: method, body: Optional<EmptyRequest>.none)
    }

    func request<Response: Decodable, Body: Encodable>(
        path: String,
        method: String = "GET",
        body: Body? = nil
    ) async throws -> Response {
        let request = try authorizedRequest(
            path: path,
            method: method,
            contentType: "application/json",
            bodyData: try body.map(encoder.encode)
        )
        let data = try await performData(for: request)
        return try decodeResultEnvelope(from: data)
    }

    func requestWithoutResult<Body: Encodable>(
        path: String,
        method: String = "GET",
        body: Body? = nil
    ) async throws {
        let request = try authorizedRequest(
            path: path,
            method: method,
            contentType: "application/json",
            bodyData: try body.map(encoder.encode)
        )
        let data = try await performData(for: request)
        try validateEnvelopeSuccess(from: data)
    }

    func multipartRequest<Response: Decodable>(
        path: String,
        method: String = "POST",
        fields: [MultipartFormField]
    ) async throws -> Response {
        let boundary = "Boundary-\(UUID().uuidString)"
        let request = try authorizedRequest(
            path: path,
            method: method,
            contentType: "multipart/form-data; boundary=\(boundary)",
            bodyData: createMultipartBody(fields: fields, boundary: boundary)
        )
        let data = try await performData(for: request)
        return try decodeResultEnvelope(from: data)
    }

    func multipartRequestWithoutResult(
        path: String,
        method: String = "POST",
        fields: [MultipartFormField]
    ) async throws {
        let boundary = "Boundary-\(UUID().uuidString)"
        let request = try authorizedRequest(
            path: path,
            method: method,
            contentType: "multipart/form-data; boundary=\(boundary)",
            bodyData: createMultipartBody(fields: fields, boundary: boundary)
        )
        let data = try await performData(for: request)
        try validateEnvelopeSuccess(from: data)
    }

    func authorizedRequest(
        path: String,
        method: String,
        contentType: String? = nil,
        bodyData: Data? = nil
    ) throws -> URLRequest {
        let token = try validatedToken()

        var request = URLRequest(url: try endpointURL(path: path))
        request.httpMethod = method
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        if let contentType {
            request.setValue(contentType, forHTTPHeaderField: "Content-Type")
        }

        request.httpBody = bodyData
        return request
    }

    func validatedToken() throws -> String {
        guard let token, token.isEmpty == false else {
            throw CloudflareAPIError.missingToken
        }

        return token
    }

    func performData(for request: URLRequest) async throws -> Data {
        let (data, _) = try await send(request: request)
        return data
    }

    func performRaw(request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        try await send(request: request)
    }

    func send(request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        var request = request
        var attempt = 0
        var didRetryAfterOAuthRefresh = false
        let method = request.httpMethod ?? "UNKNOWN"
        let url = networkLogPath(from: request.url)

        logDebug("Sending \(method) \(url).")

        while true {
            let attemptIndex = attempt + 1
            let startedAt = Date()
            printNetworkStart(method: method, url: request.url, attempt: attemptIndex)

            do {
                let (data, response) = try await session.data(for: request)
                guard let http = response as? HTTPURLResponse else {
                    throw CloudflareAPIError.invalidResponse
                }

                let durationMilliseconds = elapsedMilliseconds(since: startedAt)
                await logHTTP(
                    request: request,
                    response: http,
                    data: data,
                    attempt: attemptIndex,
                    durationMilliseconds: durationMilliseconds
                )

                let shouldRetryResponse = shouldRetry(request: request, response: http, attempt: attempt)
                printNetworkResponse(
                    method: method,
                    url: request.url,
                    statusCode: http.statusCode,
                    byteCount: data.count,
                    durationMilliseconds: durationMilliseconds,
                    attempt: attemptIndex,
                    willRetry: shouldRetryResponse
                )

                if shouldRetryResponse {
                    attempt += 1
                    logNotice(
                        "Retrying \(method) \(url) after HTTP \(http.statusCode). Attempt \(attempt)."
                    )
                    try await Task.sleep(
                        nanoseconds: retryDelayNanoseconds(for: attempt, response: http)
                    )
                    continue
                }

                do {
                    try validateHTTP(response: http, data: data)
                } catch CloudflareAPIError.unauthorized {
                    if didRetryAfterOAuthRefresh == false,
                       let refreshedRequest = try await refreshedRequestAfterOAuthAuthorizationFailure(for: request)
                    {
                        didRetryAfterOAuthRefresh = true
                        request = refreshedRequest
                        logNotice("Retrying \(method) \(url) after refreshing OAuth access token.")
                        continue
                    }
                    throw CloudflareAPIError.unauthorized
                }
                return (data, http)
            } catch {
                if isResponseValidationError(error) == false {
                    await HTTPRequestLogStore.shared.record(
                        method: method,
                        url: request.url,
                        statusCode: nil,
                        durationMilliseconds: elapsedMilliseconds(since: startedAt),
                        attempt: attemptIndex,
                        errorMessage: networkErrorSummary(error)
                    )
                }

                let shouldRetryTransportError = shouldRetry(request: request, error: error, attempt: attempt)
                printNetworkFailure(
                    method: method,
                    url: request.url,
                    error: error,
                    durationMilliseconds: elapsedMilliseconds(since: startedAt),
                    attempt: attemptIndex,
                    willRetry: shouldRetryTransportError
                )

                guard shouldRetryTransportError else {
                    throw error
                }

                attempt += 1
                logNotice(
                    "Retrying \(method) \(url) after transport error: \(error.localizedDescription). Attempt \(attempt)."
                )
                try await Task.sleep(nanoseconds: retryDelayNanoseconds(for: attempt, response: nil))
            }
        }
    }

    func refreshedRequestAfterOAuthAuthorizationFailure(for request: URLRequest) async throws -> URLRequest? {
        guard let oauthTokenRefreshHandler else {
            OAuthDiagnostics.error("Received 401 but no OAuth refresh handler is registered.")
            return nil
        }

        OAuthDiagnostics.notice(
            "Received 401 from Cloudflare API. Attempting OAuth access token refresh for \(networkLogPath(from: request.url))."
        )

        guard let refreshedToken = try await oauthTokenRefreshHandler()?
            .trimmingCharacters(in: .whitespacesAndNewlines),
              refreshedToken.isEmpty == false
        else {
            OAuthDiagnostics.error("OAuth refresh handler returned no token after 401.")
            return nil
        }

        token = refreshedToken
        tokenVersion &+= 1
        OAuthDiagnostics.notice(
            "OAuth access token refresh succeeded after 401. New API session version=\(tokenVersion)."
        )

        var refreshedRequest = request
        refreshedRequest.setValue("Bearer \(refreshedToken)", forHTTPHeaderField: "Authorization")
        return refreshedRequest
    }

    func elapsedMilliseconds(since startedAt: Date) -> Int {
        max(0, Int(Date().timeIntervalSince(startedAt) * 1_000))
    }

    func printNetworkStart(method: String, url: URL?, attempt: Int) {
#if DEBUG
        print("[CFPanel Network] -> \(method) \(networkLogPath(from: url)) attempt=\(attempt)")
#endif
    }

    func printNetworkResponse(
        method: String,
        url: URL?,
        statusCode: Int,
        byteCount: Int,
        durationMilliseconds: Int,
        attempt: Int,
        willRetry: Bool
    ) {
#if DEBUG
        let retrySuffix = willRetry ? " retry=true" : ""
        print(
            "[CFPanel Network] <- \(statusCode) \(method) \(networkLogPath(from: url)) \(durationMilliseconds)ms bytes=\(byteCount) attempt=\(attempt)\(retrySuffix)"
        )
#endif
    }

    func printNetworkFailure(
        method: String,
        url: URL?,
        error: Error,
        durationMilliseconds: Int,
        attempt: Int,
        willRetry: Bool
    ) {
#if DEBUG
        let retrySuffix = willRetry ? " retry=true" : ""
        print(
            "[CFPanel Network] !! \(method) \(networkLogPath(from: url)) \(durationMilliseconds)ms attempt=\(attempt)\(retrySuffix) error=\(networkErrorSummary(error))"
        )
#endif
    }

    func networkLogPath(from url: URL?) -> String {
        HTTPRequestLogStore.redactedPathAndQuery(from: url)
    }

    func networkErrorSummary(_ error: Error) -> String {
        let nsError = error as NSError
        var parts = [
            "\(nsError.domain)(\(nsError.code))",
            error.localizedDescription
        ]

        if let urlError = error as? URLError {
            parts.append("URLError.\(urlError.code)")
        }

        if let underlying = nsError.userInfo[NSUnderlyingErrorKey] as? NSError {
            parts.append("underlying=\(underlying.domain)(\(underlying.code))")

            if let sslCode = underlying.userInfo["_kCFStreamErrorCodeKey"] {
                parts.append("sslCode=\(sslCode)")
            }
            if let sslDomain = underlying.userInfo["_kCFStreamErrorDomainKey"] {
                parts.append("sslDomain=\(sslDomain)")
            }
            if let originalSSLValue = underlying.userInfo["_kCFNetworkCFStreamSSLErrorOriginalValue"] {
                parts.append("sslOriginal=\(originalSSLValue)")
            }
        }

        if let failingURL = nsError.userInfo[NSURLErrorFailingURLErrorKey] as? URL {
            parts.append("failingURL=\(networkLogPath(from: failingURL))")
        }

        return parts.joined(separator: " | ")
    }

    func isResponseValidationError(_ error: Error) -> Bool {
        switch error {
        case CloudflareAPIError.rateLimited:
            return true
        case CloudflareAPIError.unauthorized:
            return true
        case CloudflareAPIError.httpStatus:
            return true
        default:
            return false
        }
    }

    func shouldRetry(request: URLRequest, response: HTTPURLResponse, attempt: Int) -> Bool {
        guard attempt < 2 else {
            return false
        }

        guard isRetryableRequest(request) else {
            return false
        }

        switch response.statusCode {
        case 429:
            return true
        case 500 ... 599:
            return true
        default:
            return false
        }
    }

    func shouldRetry(request: URLRequest, error: Error, attempt: Int) -> Bool {
        guard attempt < 2 else {
            return false
        }

        guard isRetryableRequest(request) else {
            return false
        }

        switch error {
        case CloudflareAPIError.rateLimited:
            return true
        case let CloudflareAPIError.httpStatus(code, _):
            return (500 ... 599).contains(code)
        case let urlError as URLError:
            return transientRetryableURLErrorCodes.contains(urlError.code)
        default:
            return false
        }
    }

    func retryDelayNanoseconds(for attempt: Int, response: HTTPURLResponse?) -> UInt64 {
        if let response,
           response.statusCode == 429,
           let retryAfterSeconds = retryAfterSeconds(from: response)
        {
            return secondsToNanoseconds(retryAfterSeconds)
        }

        switch attempt {
        case 1:
            return 300_000_000
        default:
            return 900_000_000
        }
    }

    func isRetryableRequest(_ request: URLRequest) -> Bool {
        guard let method = request.httpMethod?.uppercased() else {
            return false
        }

        if method == "GET" {
            return true
        }

        return method == "POST" && request.url?.path == "/client/v4/graphql"
    }

    func decodeEnvelope<T: Decodable>(_ type: T.Type, from data: Data) throws -> T {
        do {
            return try decoder.decode(type, from: data)
        } catch {
            logError("Failed to decode Cloudflare envelope into \(String(describing: type)).")
            throw CloudflareAPIError.decoding(
                "Failed to decode Cloudflare response. Enable CFPANEL_LOG_RESPONSE_BODIES=1 in the debug environment to inspect the payload."
            )
        }
    }

    func decodeResultEnvelope<Response: Decodable>(from data: Data) throws -> Response {
        let envelope = try decodeEnvelope(CloudflareEnvelope<Response>.self, from: data)

        if envelope.success, let result = envelope.result {
            return result
        }

        throw CloudflareAPIError.api(envelopeMessage(from: envelope))
    }

    func validateEnvelopeSuccess(from data: Data) throws {
        let envelope = try decodeEnvelope(CloudflareEnvelope<EmptyPayload>.self, from: data)

        guard envelope.success else {
            throw CloudflareAPIError.api(envelopeMessage(from: envelope))
        }
    }

    func validateEnvelope<Result>(_ envelope: CloudflareEnvelope<Result>) throws {
        guard envelope.success else {
            throw CloudflareAPIError.api(envelopeMessage(from: envelope))
        }
    }

    func envelopeMessage<Result: Decodable>(from envelope: CloudflareEnvelope<Result>) -> String {
        let errors = envelope.errors ?? []
        let messages = envelope.messages ?? []
        let diagnostics = (errors + messages)
            .map(\.diagnosticText)
            .filter { $0.isEmpty == false }

        guard diagnostics.isEmpty == false else {
            return "Cloudflare returned an empty response."
        }

        return diagnostics.joined(separator: "\n")
    }

    func validateHTTP(response: URLResponse, data: Data) throws {
        guard let http = response as? HTTPURLResponse else {
            throw CloudflareAPIError.invalidResponse
        }

        switch http.statusCode {
        case 200 ... 299:
            return
        case 401:
            throw CloudflareAPIError.unauthorized
        case 429:
            throw CloudflareAPIError.rateLimited
        default:
            if let payload = try? decoder.decode(CloudflareEnvelope<EmptyPayload>.self, from: data) {
                throw CloudflareAPIError.httpStatus(http.statusCode, envelopeMessage(from: payload))
            }
            let body = readableBody(from: data)
            throw CloudflareAPIError.httpStatus(
                http.statusCode,
                body.isEmpty ? "Cloudflare returned an unreadable response body." : body
            )
        }
    }

    func endpointURL(path: String) throws -> URL {
        let normalizedPath = path.hasPrefix("/") ? String(path.dropFirst()) : path

        guard let url = URL(string: normalizedPath, relativeTo: baseURL) else {
            throw CloudflareAPIError.invalidRequest
        }

        return url
    }

    func encodedPathComponent(_ value: String) throws -> String {
        guard let encoded = value.addingPercentEncoding(withAllowedCharacters: Self.urlPathComponentAllowed) else {
            throw CloudflareAPIError.invalidRequest
        }

        return encoded
    }

    func appendingQueryItems(
        _ queryItems: [URLQueryItem],
        to path: String,
        existing existingQueryItems: [URLQueryItem] = []
    ) throws -> String {
        let url = try endpointURL(path: path)

        guard var components = URLComponents(url: url, resolvingAgainstBaseURL: true) else {
            throw CloudflareAPIError.invalidRequest
        }

        var merged = components.queryItems ?? []
        merged.append(contentsOf: existingQueryItems)

        for item in queryItems {
            merged.removeAll { $0.name == item.name }
            merged.append(item)
        }

        components.queryItems = merged.isEmpty ? nil : merged

        guard let resolvedURL = components.url else {
            throw CloudflareAPIError.invalidRequest
        }

        return resolvedURL.absoluteString
    }

    func shouldContinuePaginating(
        page: Int,
        perPage: Int?,
        collectedCount: Int,
        pageItemCount: Int,
        resultInfo: CloudflareResultInfo?
    ) -> Bool {
        guard pageItemCount > 0 else {
            return false
        }

        if let totalCount = resultInfo?.totalCount {
            return collectedCount < totalCount
        }

        if let pageCount = resultInfo?.count, let perPage, pageCount < perPage {
            return false
        }

        if let returnedPerPage = resultInfo?.perPage, pageItemCount < returnedPerPage {
            return false
        }

        guard let perPage else {
            return resultInfo?.totalCount.map { collectedCount < $0 } ?? false
        }

        return pageItemCount >= perPage && page < Self.maxPageCount
    }

    func retryAfterSeconds(from response: HTTPURLResponse) -> TimeInterval? {
        guard let value = response.value(forHTTPHeaderField: "Retry-After") else {
            return nil
        }

        if let seconds = TimeInterval(value.trimmingCharacters(in: .whitespacesAndNewlines)) {
            return max(seconds, 0)
        }

        if let retryDate = Self.retryAfterDateFormatter.date(from: value) {
            return max(retryDate.timeIntervalSinceNow, 0)
        }

        return nil
    }

    func secondsToNanoseconds(_ seconds: TimeInterval) -> UInt64 {
        let boundedSeconds = min(max(seconds, 0), 60)
        return UInt64(boundedSeconds * 1_000_000_000)
    }

    func logHTTP(
        request: URLRequest,
        response: URLResponse,
        data: Data,
        attempt: Int,
        durationMilliseconds: Int
    ) async {
        await HTTPRequestLogStore.shared.record(
            method: request.httpMethod ?? "UNKNOWN",
            url: request.url,
            statusCode: (response as? HTTPURLResponse)?.statusCode,
            durationMilliseconds: durationMilliseconds,
            attempt: attempt
        )

#if DEBUG
        guard Self.verboseLoggingEnabled else { return }

        let method = request.httpMethod ?? "UNKNOWN"
        let url = networkLogPath(from: request.url)
        let status = (response as? HTTPURLResponse)?.statusCode ?? -1
        let body = loggedResponsePreview(for: request, data: data)

        logDebug("HTTP \(status) \(method) \(url) Response: \(body)")
#endif
    }

    func loggedResponsePreview(for request: URLRequest, data: Data) -> String {
        guard shouldLogResponseBody(for: request) else {
            return "<redacted; \(data.count) bytes>"
        }

        let body = readableBody(from: data)
        let maxLength = 1200
        guard body.count > maxLength else {
            return body
        }

        let truncated = body.prefix(maxLength)
        return "\(truncated)… <truncated>"
    }

    func shouldLogResponseBody(for request: URLRequest) -> Bool {
        // Response bodies frequently contain zone inventory, analytics, or KV data.
        // Keep the default debug log safe, and require an explicit local opt-in to inspect payloads.
        guard ProcessInfo.processInfo.environment["CFPANEL_LOG_RESPONSE_BODIES"] == "1" else {
            return false
        }

        guard let path = request.url?.path(percentEncoded: false) else {
            return true
        }

        let alwaysRedactedFragments = [
            "/storage/kv/",
            "/dns_records/export",
            "/tokens/verify"
        ]

        return alwaysRedactedFragments.contains(where: { path.contains($0) }) == false
    }

    func readableBody(from data: Data) -> String {
        guard data.isEmpty == false else {
            return "<empty>"
        }

        if let text = String(data: data, encoding: .utf8) {
            return text
        }

        return "<non-UTF8 body: \(data.count) bytes>"
    }

    func createMultipartBody(fields: [MultipartFormField], boundary: String) -> Data {
        var body = Data()

        for field in fields {
            body.append(Data("--\(boundary)\r\n".utf8))

            var disposition = "Content-Disposition: form-data; name=\"\(field.name)\""
            if let fileName = field.fileName {
                disposition += "; filename=\"\(fileName)\""
            }
            body.append(Data("\(disposition)\r\n".utf8))
            body.append(Data("Content-Type: \(field.mimeType)\r\n\r\n".utf8))
            body.append(field.data)
            body.append(Data("\r\n".utf8))
        }

        body.append(Data("--\(boundary)--\r\n".utf8))
        return body
    }

    nonisolated(unsafe) static let graphQLDateFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    nonisolated(unsafe) static let graphQLResponseDateFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()

    static let graphQLDayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    static let urlPathComponentAllowed: CharacterSet = {
        var charset = CharacterSet.urlPathAllowed
        charset.remove(charactersIn: "/")
        return charset
    }()

    static let retryAfterDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "EEE',' dd MMM yyyy HH':'mm':'ss z"
        return formatter
    }()

    var transientRetryableURLErrorCodes: Set<URLError.Code> {
        [
            .timedOut,
            .cannotFindHost,
            .cannotConnectToHost,
            .networkConnectionLost,
            .dnsLookupFailed,
            .notConnectedToInternet,
            .secureConnectionFailed,
            .internationalRoamingOff,
            .callIsActive,
            .dataNotAllowed
        ]
    }
}
