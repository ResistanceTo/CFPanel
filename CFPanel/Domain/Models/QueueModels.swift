import Foundation

nonisolated struct QueueSummary: Identifiable, Hashable, Decodable, Sendable {
    let queueID: String
    let queueName: String
    let createdOn: Date?
    let modifiedOn: Date?
    let producers: [QueueProducer]
    let consumers: [QueueConsumer]
    let deliveryDelay: Int?
    let messageRetentionPeriodSecs: Int?

    var id: String { queueID }

    var producerCount: Int { producers.count }

    var consumerCount: Int { consumers.count }

    var delayTitle: String {
        guard let deliveryDelay else { return "None" }
        return deliveryDelay == 0 ? "None" : "\(deliveryDelay)s"
    }

    var retentionTitle: String {
        guard let messageRetentionPeriodSecs else { return "Default" }
        if messageRetentionPeriodSecs % 3600 == 0 {
            return "\(messageRetentionPeriodSecs / 3600)h"
        }
        if messageRetentionPeriodSecs % 60 == 0 {
            return "\(messageRetentionPeriodSecs / 60)m"
        }
        return "\(messageRetentionPeriodSecs)s"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: AnyCodingKey.self)
        queueID =
            try container.decodeIfPresent(String.self, forKey: .init("queue_id"))
            ?? container.decodeIfPresent(String.self, forKey: .init("id"))
            ?? UUID().uuidString
        queueName =
            try container.decodeIfPresent(String.self, forKey: .init("queue_name"))
            ?? container.decodeIfPresent(String.self, forKey: .init("name"))
            ?? "Unnamed Queue"
        createdOn =
            try container.decodeIfPresent(Date.self, forKey: .init("created_on"))
            ?? container.decodeIfPresent(Date.self, forKey: .init("created_at"))
        modifiedOn =
            try container.decodeIfPresent(Date.self, forKey: .init("modified_on"))
            ?? container.decodeIfPresent(Date.self, forKey: .init("updated_on"))
        producers = try container.decodeIfPresent([QueueProducer].self, forKey: .init("producers")) ?? []
        consumers = try container.decodeIfPresent([QueueConsumer].self, forKey: .init("consumers")) ?? []
        deliveryDelay =
            try container.decodeIfPresent(Int.self, forKey: .init("delivery_delay"))
            ?? container.decodeIfPresent(Int.self, forKey: .init("delivery_delay_secs"))
        messageRetentionPeriodSecs =
            try container.decodeIfPresent(Int.self, forKey: .init("message_retention_period_secs"))
            ?? container.decodeIfPresent(Int.self, forKey: .init("message_retention_secs"))
    }
}

nonisolated struct QueueDetail: Identifiable, Decodable, Sendable {
    let queueID: String
    let queueName: String
    let createdOn: Date?
    let modifiedOn: Date?
    let producers: [QueueProducer]
    let consumers: [QueueConsumer]
    let deliveryDelay: Int?
    let messageRetentionPeriodSecs: Int?
    let rawValue: JSONValue

    var id: String { queueID }

    var delayTitle: String {
        guard let deliveryDelay else { return "None" }
        return deliveryDelay == 0 ? "None" : "\(deliveryDelay)s"
    }

    var retentionTitle: String {
        guard let messageRetentionPeriodSecs else { return "Default" }
        if messageRetentionPeriodSecs % 3600 == 0 {
            return "\(messageRetentionPeriodSecs / 3600)h"
        }
        if messageRetentionPeriodSecs % 60 == 0 {
            return "\(messageRetentionPeriodSecs / 60)m"
        }
        return "\(messageRetentionPeriodSecs)s"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: AnyCodingKey.self)
        queueID =
            try container.decodeIfPresent(String.self, forKey: .init("queue_id"))
            ?? container.decodeIfPresent(String.self, forKey: .init("id"))
            ?? UUID().uuidString
        queueName =
            try container.decodeIfPresent(String.self, forKey: .init("queue_name"))
            ?? container.decodeIfPresent(String.self, forKey: .init("name"))
            ?? "Unnamed Queue"
        createdOn =
            try container.decodeIfPresent(Date.self, forKey: .init("created_on"))
            ?? container.decodeIfPresent(Date.self, forKey: .init("created_at"))
        modifiedOn =
            try container.decodeIfPresent(Date.self, forKey: .init("modified_on"))
            ?? container.decodeIfPresent(Date.self, forKey: .init("updated_on"))
        producers = try container.decodeIfPresent([QueueProducer].self, forKey: .init("producers")) ?? []
        consumers = try container.decodeIfPresent([QueueConsumer].self, forKey: .init("consumers")) ?? []
        deliveryDelay =
            try container.decodeIfPresent(Int.self, forKey: .init("delivery_delay"))
            ?? container.decodeIfPresent(Int.self, forKey: .init("delivery_delay_secs"))
        messageRetentionPeriodSecs =
            try container.decodeIfPresent(Int.self, forKey: .init("message_retention_period_secs"))
            ?? container.decodeIfPresent(Int.self, forKey: .init("message_retention_secs"))

        var rawObject: [String: JSONValue] = [:]
        for key in container.allKeys {
            rawObject[key.stringValue] = try container.decode(JSONValue.self, forKey: key)
        }
        rawValue = .object(rawObject)
    }
}

nonisolated struct QueueProducer: Identifiable, Hashable, Decodable, Sendable {
    let service: String?
    let environment: String?
    let script: String?

    var id: String {
        [service, script, environment].compactMap { $0 }.joined(separator: ":")
    }

    var title: String {
        if let service, service.isEmpty == false {
            return service
        }
        if let script, script.isEmpty == false {
            return script
        }
        return "Producer"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: AnyCodingKey.self)
        service =
            try container.decodeIfPresent(String.self, forKey: .init("service"))
            ?? container.decodeIfPresent(String.self, forKey: .init("service_name"))
        environment = try container.decodeIfPresent(String.self, forKey: .init("environment"))
        script = try container.decodeIfPresent(String.self, forKey: .init("script"))
    }
}

nonisolated struct QueueConsumer: Identifiable, Hashable, Decodable, Sendable {
    let consumerID: String?
    let type: String?
    let script: String?
    let service: String?
    let environment: String?
    let maxBatchSize: Int?
    let maxBatchTimeout: Int?
    let maxRetries: Int?
    let deadLetterQueue: String?

    var id: String {
        consumerID ?? [type, service, script, environment].compactMap { $0 }.joined(separator: ":")
    }

    var title: String {
        if let service, service.isEmpty == false {
            return service
        }
        if let script, script.isEmpty == false {
            return script
        }
        return type?.replacingOccurrences(of: "_", with: " ").localizedCapitalized ?? "Consumer"
    }

    var typeTitle: String {
        type?.replacingOccurrences(of: "_", with: " ").localizedCapitalized ?? "Unknown"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: AnyCodingKey.self)
        consumerID =
            try container.decodeIfPresent(String.self, forKey: .init("consumer_id"))
            ?? container.decodeIfPresent(String.self, forKey: .init("id"))
        type = try container.decodeIfPresent(String.self, forKey: .init("type"))
        script = try container.decodeIfPresent(String.self, forKey: .init("script"))
        service =
            try container.decodeIfPresent(String.self, forKey: .init("service"))
            ?? container.decodeIfPresent(String.self, forKey: .init("service_name"))
        environment = try container.decodeIfPresent(String.self, forKey: .init("environment"))
        maxBatchSize = try container.decodeIfPresent(Int.self, forKey: .init("max_batch_size"))
        maxBatchTimeout = try container.decodeIfPresent(Int.self, forKey: .init("max_batch_timeout"))
        maxRetries = try container.decodeIfPresent(Int.self, forKey: .init("max_retries"))
        deadLetterQueue =
            try container.decodeIfPresent(String.self, forKey: .init("dead_letter_queue"))
            ?? container.decodeIfPresent(String.self, forKey: .init("dead_letter_queue_id"))
    }
}
