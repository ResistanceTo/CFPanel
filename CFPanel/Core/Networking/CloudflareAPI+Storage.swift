import Foundation

extension CloudflareAPI {
    func listR2Buckets(accountID: String) async throws -> [R2Bucket] {
        try await requestAllPages(
            path: "/accounts/\(accountID)/r2/buckets",
            extractItems: { (response: R2BucketList) in
                response.buckets
            }
        )
    }

    func fetchR2Bucket(accountID: String, bucketName: String) async throws -> R2BucketDetail {
        let encodedName = try encodedPathComponent(bucketName)
        return try await request(path: "/accounts/\(accountID)/r2/buckets/\(encodedName)")
    }

    func listD1Databases(accountID: String) async throws -> [D1Database] {
        try await requestAllPages(path: "/accounts/\(accountID)/d1/database")
    }

    func fetchD1Database(accountID: String, databaseID: String) async throws -> D1DatabaseDetail {
        try await request(path: "/accounts/\(accountID)/d1/database/\(databaseID)")
    }

    func listQueues(accountID: String) async throws -> [QueueSummary] {
        try await requestAllPages(path: "/accounts/\(accountID)/queues")
    }

    func fetchQueue(accountID: String, queueID: String) async throws -> QueueDetail {
        try await request(path: "/accounts/\(accountID)/queues/\(queueID)")
    }

    func listKVNamespaces(accountID: String) async throws -> [KVNamespace] {
        try await requestAllPages(path: "/accounts/\(accountID)/storage/kv/namespaces")
    }

    func fetchKVNamespace(accountID: String, namespaceID: String) async throws -> KVNamespace {
        try await request(path: "/accounts/\(accountID)/storage/kv/namespaces/\(namespaceID)")
    }

    func listKVNamespaceKeys(
        accountID: String,
        namespaceID: String,
        limit: Int = 100,
        cursor: String? = nil
    ) async throws -> KVNamespaceKeyPage {
        var components = URLComponents()
        components.path = "/accounts/\(accountID)/storage/kv/namespaces/\(namespaceID)/keys"
        components.queryItems = [
            URLQueryItem(name: "limit", value: String(limit))
        ]

        if let cursor, cursor.isEmpty == false {
            components.queryItems?.append(URLQueryItem(name: "cursor", value: cursor))
        }

        let requestPath = components.path + (components.percentEncodedQuery.map { "?\($0)" } ?? "")
        let envelope: CloudflareEnvelope<[KVNamespaceKey]> = try await requestEnvelope(
            path: requestPath
        )

        guard envelope.success else {
            let message = envelope.errors?.first?.message
                ?? envelope.messages?.first?.message
                ?? "Cloudflare returned an empty response."
            throw CloudflareAPIError.api(message)
        }

        return KVNamespaceKeyPage(
            keys: envelope.result ?? [],
            nextCursor: envelope.resultInfo?.nextCursor
        )
    }

    func fetchKVValue(
        accountID: String,
        namespaceID: String,
        keyName: String
    ) async throws -> KVValueSnapshot {
        let encodedKey = try encodedPathComponent(keyName)
        let metadata: JSONValue? = try? await request(
            path: "/accounts/\(accountID)/storage/kv/namespaces/\(namespaceID)/metadata/\(encodedKey)"
        )
        let (data, response) = try await rawRequest(
            path: "/accounts/\(accountID)/storage/kv/namespaces/\(namespaceID)/values/\(encodedKey)"
        )

        let previewData = data.prefix(KVValueSnapshot.previewByteLimit)
        let previewValue = String(data: previewData, encoding: .utf8)
        let isBinary = previewValue == nil
        let value = previewValue ?? "<binary payload: \(data.count) bytes>"
        let expirationDate = response.value(forHTTPHeaderField: "expiration")
            .flatMap(TimeInterval.init)
            .map(Date.init(timeIntervalSince1970:))

        return KVValueSnapshot(
            keyName: keyName,
            value: value,
            isValueTruncated: data.count > KVValueSnapshot.previewByteLimit,
            isBinary: isBinary,
            expiration: expirationDate,
            metadata: metadata,
            contentType: response.value(forHTTPHeaderField: "Content-Type"),
            byteCount: data.count
        )
    }

    func writeKVValue(
        accountID: String,
        namespaceID: String,
        keyName: String,
        value: String,
        metadata: JSONValue? = nil,
        expiration: Date? = nil,
        expirationTTL: Int? = nil
    ) async throws {
        let encodedKey = try encodedPathComponent(keyName)
        let path = kvValuePath(
            accountID: accountID,
            namespaceID: namespaceID,
            encodedKey: encodedKey,
            expiration: expiration,
            expirationTTL: expirationTTL
        )

        if let metadata {
            let metadataData = try encoder.encode(metadata)
            let fields = [
                MultipartFormField(
                    name: "value",
                    data: Data(value.utf8),
                    mimeType: "text/plain"
                ),
                MultipartFormField(
                    name: "metadata",
                    data: metadataData,
                    mimeType: "application/json"
                )
            ]

            try await multipartRequestWithoutResult(
                path: path,
                method: "PUT",
                fields: fields
            )
        } else {
            try await requestWithoutResultData(
                path: path,
                method: "PUT",
                contentType: "text/plain; charset=utf-8",
                bodyData: Data(value.utf8)
            )
        }
    }

    func deleteKVValue(
        accountID: String,
        namespaceID: String,
        keyName: String
    ) async throws {
        let encodedKey = try encodedPathComponent(keyName)
        try await requestWithoutResult(
            path: "/accounts/\(accountID)/storage/kv/namespaces/\(namespaceID)/values/\(encodedKey)",
            method: "DELETE"
        )
    }

    func bulkWriteKVValues(
        accountID: String,
        namespaceID: String,
        entries: [KVBulkWriteEntry]
    ) async throws -> KVBulkMutationResult {
        try await request(
            path: "/accounts/\(accountID)/storage/kv/namespaces/\(namespaceID)/bulk",
            method: "PUT",
            body: entries
        )
    }

    func bulkDeleteKVValues(
        accountID: String,
        namespaceID: String,
        keys: [String]
    ) async throws -> KVBulkMutationResult {
        try await request(
            path: "/accounts/\(accountID)/storage/kv/namespaces/\(namespaceID)/bulk/delete",
            method: "POST",
            body: keys
        )
    }

    func listVectorizeIndexes(accountID: String) async throws -> [VectorizeIndex] {
        try await requestAllPages(path: "/accounts/\(accountID)/vectorize/v2/indexes")
    }

    func fetchVectorizeIndex(accountID: String, indexName: String) async throws -> VectorizeIndex {
        let encodedName = try encodedPathComponent(indexName)
        return try await request(path: "/accounts/\(accountID)/vectorize/v2/indexes/\(encodedName)")
    }

    func listVectorizeMetadataIndexes(accountID: String, indexName: String) async throws -> [VectorizeMetadataIndex] {
        let encodedName = try encodedPathComponent(indexName)
        let response: VectorizeMetadataIndexListResponse = try await request(
            path: "/accounts/\(accountID)/vectorize/v2/indexes/\(encodedName)/metadata_index/list"
        )
        return response.metadataIndexes
    }

    func listHyperdriveConfigs(accountID: String) async throws -> [HyperdriveConfig] {
        try await requestAllPages(path: "/accounts/\(accountID)/hyperdrive/configs")
    }

    func fetchHyperdriveConfig(accountID: String, configID: String) async throws -> HyperdriveConfig {
        try await request(path: "/accounts/\(accountID)/hyperdrive/configs/\(configID)")
    }

    func kvValuePath(
        accountID: String,
        namespaceID: String,
        encodedKey: String,
        expiration: Date?,
        expirationTTL: Int?
    ) -> String {
        var components = URLComponents()
        components.path = "/accounts/\(accountID)/storage/kv/namespaces/\(namespaceID)/values/\(encodedKey)"

        var queryItems: [URLQueryItem] = []
        if let expiration {
            queryItems.append(
                URLQueryItem(name: "expiration", value: String(Int(expiration.timeIntervalSince1970)))
            )
        }
        if let expirationTTL {
            queryItems.append(
                URLQueryItem(name: "expiration_ttl", value: String(expirationTTL))
            )
        }

        components.queryItems = queryItems.isEmpty ? nil : queryItems
        return components.string ?? components.path
    }
}
