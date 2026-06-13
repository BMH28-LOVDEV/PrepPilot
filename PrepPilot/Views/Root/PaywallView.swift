import StoreKit
import SwiftUI

struct PaywallView: View {
    @Environment(AppEnvironment.self) private var environment
    @State private var purchasingProductID: String?
    @State private var message: String?

    private var store: SubscriptionStore { environment.subscriptionStore }

    var body: some View {
        PremiumBackground {
            ScrollView {
                VStack(spacing: 22) {
                    header
                    plans
                    restoreButton
                    if let message {
                        Text(message)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                }
                .padding(.vertical, 20)
                .padding(.horizontal)
            }
        }
        .navigationTitle("Premium")
        .task {
            await store.loadProducts()
        }
    }

    private var header: some View {
        VStack(spacing: 14) {
            Image(systemName: "sparkles.rectangle.stack.fill")
                .font(.system(size: 54, weight: .semibold))
                .foregroundStyle(PrepPilotTheme.studyGradient)
                .frame(width: 110, height: 110)
                .background(.thinMaterial, in: RoundedRectangle(cornerRadius: PrepPilotTheme.cornerRadius, style: .continuous))
            VStack(spacing: 6) {
                Text("PrepPilot Premium")
                    .font(.largeTitle.weight(.bold))
                    .multilineTextAlignment(.center)
                Text("Unlimited recordings, generated study materials, quizzes, study guides, and note-grounded AI chat.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
    }

    private var plans: some View {
        VStack(spacing: 12) {
            PlanCard(
                title: "Monthly",
                price: store.displayPrice(for: SubscriptionStore.monthlyProductID),
                subtitle: "Flexible access for active terms",
                isRecommended: false,
                isLoading: purchasingProductID == SubscriptionStore.monthlyProductID,
                isDisabled: product(for: SubscriptionStore.monthlyProductID) == nil || store.isPremium
            ) {
                purchase(SubscriptionStore.monthlyProductID)
            }

            PlanCard(
                title: "Yearly",
                price: store.displayPrice(for: SubscriptionStore.yearlyProductID),
                subtitle: "Best value for full-year study",
                isRecommended: true,
                isLoading: purchasingProductID == SubscriptionStore.yearlyProductID,
                isDisabled: product(for: SubscriptionStore.yearlyProductID) == nil || store.isPremium
            ) {
                purchase(SubscriptionStore.yearlyProductID)
            }
        }
    }

    private var restoreButton: some View {
        Button {
            Task {
                await store.refreshEntitlements()
                message = store.isPremium ? "Purchases restored." : "No active premium entitlement was found."
            }
        } label: {
            Label("Restore Purchases", systemImage: "arrow.clockwise")
                .font(.headline)
                .frame(maxWidth: .infinity)
                .frame(minHeight: 50)
        }
        .buttonStyle(.bordered)
        .controlSize(.large)
    }

    private func product(for id: String) -> Product? {
        store.products.first { $0.id == id }
    }

    private func purchase(_ productID: String) {
        guard let product = product(for: productID) else {
            message = "Product not loaded. Verify StoreKit configuration and App Store Connect product IDs."
            return
        }

        Task {
            purchasingProductID = productID
            defer { purchasingProductID = nil }
            do {
                let completed = try await store.purchase(product)
                message = completed ? "Premium is active." : "Purchase was not completed."
            } catch {
                message = error.localizedDescription
            }
        }
    }
}

private struct PlanCard: View {
    let title: String
    let price: String
    let subtitle: String
    let isRecommended: Bool
    let isLoading: Bool
    let isDisabled: Bool
    let action: () -> Void

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 5) {
                        Text(title)
                            .font(.title3.weight(.bold))
                        Text(subtitle)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    if isRecommended {
                        Text("Best Value")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.teal)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(.teal.opacity(0.12), in: Capsule())
                    }
                }

                Text(price)
                    .font(.title.weight(.bold))
                    .monospacedDigit()

                PrimaryActionButton(title: isDisabled ? "Unavailable" : "Choose Plan", systemImage: "creditcard", isLoading: isLoading, action: action)
                    .disabled(isDisabled || isLoading)
            }
        }
    }
}

#Preview {
    NavigationStack {
        PaywallView()
    }
    .environment(AppEnvironment())
}
