import Foundation
import StoreKit

@MainActor
@Observable
final class SubscriptionStore {
    static let monthlyProductID = "com.preppilot.premium.monthly"
    static let yearlyProductID = "com.preppilot.premium.yearly"
    static let productIDs: Set<String> = [monthlyProductID, yearlyProductID]

    private var updatesTask: Task<Void, Never>?

    private(set) var products: [Product] = []
    private(set) var purchasedProductIDs: Set<String> = []
    private(set) var isPremium = false
    private(set) var isLoading = false
    private(set) var errorMessage: String?

    func start() {
        guard updatesTask == nil else { return }
        updatesTask = Task { [weak self] in
            guard let self else { return }
            for await result in Transaction.updates {
                await self.handle(result)
            }
        }
    }

    func loadProducts() async {
        isLoading = true
        defer { isLoading = false }

        do {
            products = try await Product.products(for: Self.productIDs)
            await refreshEntitlements()
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func refreshEntitlements() async {
        var active = Set<String>()
        for await result in Transaction.currentEntitlements {
            if case .verified(let transaction) = result, Self.productIDs.contains(transaction.productID) {
                active.insert(transaction.productID)
            }
        }
        purchasedProductIDs = active
        isPremium = !active.isEmpty
    }

    @discardableResult
    func purchase(_ product: Product) async throws -> Bool {
        let result = try await product.purchase()
        switch result {
        case .success(let verification):
            await handle(verification)
            return true
        case .pending, .userCancelled:
            return false
        @unknown default:
            return false
        }
    }

    func displayPrice(for productID: String) -> String {
        products.first(where: { $0.id == productID })?.displayPrice ?? fallbackPrice(for: productID)
    }

    private func handle(_ result: VerificationResult<Transaction>) async {
        guard case .verified(let transaction) = result else { return }
        if Self.productIDs.contains(transaction.productID) {
            purchasedProductIDs.insert(transaction.productID)
            isPremium = true
        }
        await transaction.finish()
    }

    private func fallbackPrice(for productID: String) -> String {
        switch productID {
        case Self.yearlyProductID: "$59.99 / year"
        default: "$7.99 / month"
        }
    }
}
