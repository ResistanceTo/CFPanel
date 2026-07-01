import Foundation

extension CloudflareAPI {
    func fetchWorkersUsage(accountID: String) async throws -> WorkersUsageSnapshot {
        let now = Date()
        let calendar = Calendar(identifier: .gregorian)
        let todayStart = calendar.startOfDay(for: now)
        let monthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: now)) ?? todayStart

        let variables: JSONValue = .object([
            "accountTag": .string(accountID),
            "monthStart": .string(Self.graphQLDateFormatter.string(from: monthStart)),
            "todayStart": .string(Self.graphQLDateFormatter.string(from: todayStart)),
            "now": .string(Self.graphQLDateFormatter.string(from: now))
        ])

        async let usageResponse: GraphQLResponse<WorkersUsageGraphQLData> = graphQL(
            GraphQLRequest(
                query: """
                query WorkersUsageOverview($accountTag: string!, $monthStart: Time!, $todayStart: Time!, $now: Time!) {
                  viewer {
                    accounts(filter: { accountTag: $accountTag }) {
                      month: workersInvocationsAdaptive(
                        limit: 10000,
                        filter: { datetime_geq: $monthStart, datetime_leq: $now }
                      ) {
                        sum { requests errors subrequests }
                        quantiles { cpuTimeP50 cpuTimeP99 }
                      }
                      today: workersInvocationsAdaptive(
                        limit: 10000,
                        filter: { datetime_geq: $todayStart, datetime_leq: $now }
                      ) {
                        sum { requests }
                      }
                    }
                  }
                }
                """,
                variables: variables
            )
        )

        async let cpuResponse: GraphQLResponse<WorkersCPUTimeGraphQLData> = graphQL(
            GraphQLRequest(
                query: """
                query WorkersCPUOverview($accountTag: string!, $monthStart: Time!, $todayStart: Time!, $now: Time!) {
                  viewer {
                    accounts(filter: { accountTag: $accountTag }) {
                      month: workersInvocationsAdaptive(
                        limit: 10000,
                        filter: { datetime_geq: $monthStart, datetime_leq: $now }
                      ) {
                        sum { cpuTimeUs }
                      }
                      today: workersInvocationsAdaptive(
                        limit: 10000,
                        filter: { datetime_geq: $todayStart, datetime_leq: $now }
                      ) {
                        sum { cpuTimeUs }
                      }
                    }
                  }
                }
                """,
                variables: variables
            )
        )

        let usage = try await usageResponse
        let cpu = try await cpuResponse

        guard let account = usage.data?.viewer.accounts.first else {
            throw CloudflareAPIError.graphQL("Workers usage is unavailable for this account.")
        }

        let monthRequests = (account.month ?? []).reduce(0) { $0 + ($1.sum?.requests ?? 0) }
        let monthErrors = (account.month ?? []).reduce(0) { $0 + ($1.sum?.errors ?? 0) }
        let monthSubrequests = (account.month ?? []).reduce(0) { $0 + ($1.sum?.subrequests ?? 0) }
        let todayRequests = (account.today ?? []).reduce(0) { $0 + ($1.sum?.requests ?? 0) }
        let quantiles = account.month?.first?.quantiles

        let cpuAccount = cpu.data?.viewer.accounts.first
        let monthCPU = (cpuAccount?.month ?? []).reduce(0.0) { $0 + ($1.sum?.cpuTimeUs ?? 0) }
        let todayCPU = (cpuAccount?.today ?? []).reduce(0.0) { $0 + ($1.sum?.cpuTimeUs ?? 0) }

        return WorkersUsageSnapshot(
            requestsToday: todayRequests,
            requestsMonth: monthRequests,
            errorsMonth: monthErrors,
            subrequestsMonth: monthSubrequests,
            cpuTimeTodayUs: cpuAccount == nil ? nil : todayCPU,
            cpuTimeMonthUs: cpuAccount == nil ? nil : monthCPU,
            cpuP50Us: quantiles?.cpuTimeP50,
            cpuP99Us: quantiles?.cpuTimeP99
        )
    }
}
