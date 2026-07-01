import Foundation

enum DangerousOperationMessage {
    static func destructive(
        resource: String,
        name: String,
        scope: String? = nil,
        impact: String,
        irreversible: Bool = true
    ) -> String {
        var lines = [
            "Resource: \(resource)",
            "Target: \(name)"
        ]

        if let scope, scope.isEmpty == false {
            lines.append("Scope: \(scope)")
        }

        lines.append("Impact: \(impact)")

        if irreversible {
            lines.append("This action cannot be undone from CFPanel.")
        }

        return lines.joined(separator: "\n")
    }

    static func liveChange(
        resource: String,
        name: String,
        from oldValue: String,
        to newValue: String,
        impact: String
    ) -> String {
        [
            "Resource: \(resource)",
            "Target: \(name)",
            "Change: \(oldValue) -> \(newValue)",
            "Impact: \(impact)"
        ].joined(separator: "\n")
    }

    static func changeNotice(resource: String, from oldValue: String, to newValue: String) -> String {
        "\(resource) updated: \(oldValue) -> \(newValue)."
    }

    static func changeNotice(resource: String, from oldValue: Bool, to newValue: Bool) -> String {
        changeNotice(
            resource: resource,
            from: oldValue ? "Enabled" : "Disabled",
            to: newValue ? "Enabled" : "Disabled"
        )
    }
}
