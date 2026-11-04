import XCTest
@testable import MultiCodex

final class AccountSwitchRecommendationServiceTests: XCTestCase {
    private func account(_ name: String, current: Bool = false, fiveHourUsed: Double, hasAuth: Bool = true) -> AccountUsage {
        UsageFixtures.makeAccountUsage(
            name: name,
            isCurrent: current,
            hasAuth: hasAuth,
            usage: UsageFixtures.makeUsageSummary(
                fiveHour: UsageFixtures.makeUsageMetric(usedPercent: fiveHourUsed, periodMinutes: 300),
                weekly: UsageFixtures.makeUsageMetric(usedPercent: 10, periodMinutes: 10080)
            )
        )
    }

    func testFailoverDoesNotSwitchBetweenTwoExhaustedAccounts() {
        let accounts = [account("a", current: true, fiveHourUsed: 96), account("b", fiveHourUsed: 97)]
        XCTAssertNil(AccountSwitchRecommendationService.recommendation(for: .failover, accounts: accounts))
    }

    func testFailoverSwitchesFromExhaustedToFreshAccount() {
        let accounts = [
            account("a", current: true, fiveHourUsed: 96),
            account("b", fiveHourUsed: 97),
            account("c", fiveHourUsed: 40),
        ]
        let result = AccountSwitchRecommendationService.recommendation(for: .failover, accounts: accounts)
        XCTAssertEqual(result?.accountName, "c")
        XCTAssertEqual(result?.reason, "Near limit")
    }

    func testFailoverLeavesBrokenAccountEvenIfOnlyExhaustedCandidatesExist() {
        let accounts = [account("a", current: true, fiveHourUsed: 10, hasAuth: false), account("b", fiveHourUsed: 97)]
        let result = AccountSwitchRecommendationService.recommendation(for: .failover, accounts: accounts)
        XCTAssertEqual(result?.accountName, "b")
        XCTAssertEqual(result?.reason, "Needs login")
    }

    func testFailoverKeepsHealthyCurrentAccount() {
        let accounts = [account("a", current: true, fiveHourUsed: 50), account("b", fiveHourUsed: 0)]
        XCTAssertNil(AccountSwitchRecommendationService.recommendation(for: .failover, accounts: accounts))
    }
}
