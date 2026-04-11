import Foundation

struct PendingAccountRemovalRequest: Equatable {
    let accountName: String
    let deleteData: Bool
}
