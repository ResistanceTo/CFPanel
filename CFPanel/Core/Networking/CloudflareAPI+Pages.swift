import Foundation

extension CloudflareAPI {
    func listPagesProjects(accountID: String) async throws -> [PagesProject] {
        try await requestAllPages(path: "/accounts/\(accountID)/pages/projects", perPage: nil)
    }

    func listPagesDeployments(
        accountID: String,
        projectName: String,
        environment: String? = nil
    ) async throws -> [PagesDeployment] {
        let encodedName = try encodedPathComponent(projectName)
        var queryItems: [URLQueryItem] = []
        if let environment, environment.isEmpty == false {
            queryItems.append(URLQueryItem(name: "env", value: environment))
        }

        let requestPath = try appendingQueryItems(
            [],
            to: "/accounts/\(accountID)/pages/projects/\(encodedName)/deployments",
            existing: queryItems
        )
        let envelope: CloudflareEnvelope<[PagesDeployment]> = try await requestEnvelope(path: requestPath)
        try validateEnvelope(envelope)
        return envelope.result ?? []
    }

    func listPagesDomains(accountID: String, projectName: String) async throws -> [PagesProjectDomain] {
        // The Pages domains endpoint does not accept pagination query parameters.
        let encodedName = try encodedPathComponent(projectName)
        let envelope: CloudflareEnvelope<[PagesProjectDomain]> = try await requestEnvelope(
            path: "/accounts/\(accountID)/pages/projects/\(encodedName)/domains"
        )
        try validateEnvelope(envelope)
        return envelope.result ?? []
    }

    func createPagesDomain(
        accountID: String,
        projectName: String,
        domainName: String
    ) async throws -> PagesProjectDomain {
        let encodedProject = try encodedPathComponent(projectName)
        return try await request(
            path: "/accounts/\(accountID)/pages/projects/\(encodedProject)/domains",
            method: "POST",
            body: PagesDomainCreateRequest(name: domainName)
        )
    }

    func retryPagesDomainValidation(
        accountID: String,
        projectName: String,
        domainName: String
    ) async throws -> PagesProjectDomain {
        let encodedProject = try encodedPathComponent(projectName)
        let encodedDomain = try encodedPathComponent(domainName)
        return try await request(
            path: "/accounts/\(accountID)/pages/projects/\(encodedProject)/domains/\(encodedDomain)",
            method: "PATCH"
        )
    }

    func retryPagesDeployment(
        accountID: String,
        projectName: String,
        deploymentID: String
    ) async throws -> PagesDeployment {
        let encodedProject = try encodedPathComponent(projectName)
        return try await request(
            path: "/accounts/\(accountID)/pages/projects/\(encodedProject)/deployments/\(deploymentID)/retry",
            method: "POST"
        )
    }

    func rollbackPagesDeployment(
        accountID: String,
        projectName: String,
        deploymentID: String
    ) async throws -> PagesDeployment {
        let encodedProject = try encodedPathComponent(projectName)
        return try await request(
            path: "/accounts/\(accountID)/pages/projects/\(encodedProject)/deployments/\(deploymentID)/rollback",
            method: "POST"
        )
    }

    func fetchPagesDeploymentLogs(
        accountID: String,
        projectName: String,
        deploymentID: String
    ) async throws -> PagesDeploymentLogResponse {
        let encodedProject = try encodedPathComponent(projectName)
        return try await request(
            path: "/accounts/\(accountID)/pages/projects/\(encodedProject)/deployments/\(deploymentID)/history/logs"
        )
    }

    func purgePagesBuildCache(accountID: String, projectName: String) async throws {
        let encodedProject = try encodedPathComponent(projectName)
        try await requestWithoutResult(
            path: "/accounts/\(accountID)/pages/projects/\(encodedProject)/purge_build_cache",
            method: "POST"
        )
    }

    func deletePagesDomain(
        accountID: String,
        projectName: String,
        domainName: String
    ) async throws {
        let encodedProject = try encodedPathComponent(projectName)
        let encodedDomain = try encodedPathComponent(domainName)
        try await requestWithoutResult(
            path: "/accounts/\(accountID)/pages/projects/\(encodedProject)/domains/\(encodedDomain)",
            method: "DELETE"
        )
    }

    func deletePagesDeployment(
        accountID: String,
        projectName: String,
        deploymentID: String
    ) async throws {
        let encodedProject = try encodedPathComponent(projectName)
        try await requestWithoutResult(
            path: "/accounts/\(accountID)/pages/projects/\(encodedProject)/deployments/\(deploymentID)",
            method: "DELETE"
        )
    }

    func deletePagesProject(accountID: String, projectName: String) async throws {
        let encodedProject = try encodedPathComponent(projectName)
        try await requestWithoutResult(
            path: "/accounts/\(accountID)/pages/projects/\(encodedProject)",
            method: "DELETE"
        )
    }
}
