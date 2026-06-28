import Foundation
import StoreKit

@MainActor
@Observable
final class StoreManager {
    static let shared = StoreManager()
    static let proProductID = "com.yourname.VoiceJournal.pro"
    
    var isPro: Bool = false
    var isLoading = false
    var product: Product?
    var errorMessage: String?
    
    // Free tier limit
    let freeDailyLimit = 3
    
    // transactions handled in init
    
    private init() {
        listenForTransactions()
        Task { await loadProduct() }
    }
    
    func loadProduct() async {
        isLoading = true
        defer { isLoading = false }
        do {
            let products = try await Product.products(for: [Self.proProductID])
            product = products.first
            if let entitlement = await Transaction.currentEntitlement(for: Self.proProductID),
               case .verified = entitlement {
                isPro = true
            }
        } catch {
            errorMessage = "Failed to load product"
        }
    }
    
    func purchase() async {
        guard let product = product else {
            errorMessage = "Product not available"
            return
        }
        isLoading = true
        defer { isLoading = false }
        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                if case .verified(let transaction) = verification {
                    await transaction.finish()
                    isPro = true
                }
            case .userCancelled:
                break
            case .pending:
                errorMessage = "Purchase pending"
            @unknown default:
                break
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
    
    func restore() async {
        isLoading = true
        defer { isLoading = false }
        do {
            try await AppStore.sync()
            if let entitlement = await Transaction.currentEntitlement(for: Self.proProductID),
               case .verified = entitlement {
                isPro = true
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
    
    private func listenForTransactions() {
        Task.detached { [weak self] in
            for await result in Transaction.updates {
                if case .verified(let transaction) = result {
                    await transaction.finish()
                    await MainActor.run { self?.isPro = true }
                }
            }
        }
    }
    
    func canRecordToday(entriesToday: Int) -> Bool {
        isPro || entriesToday < freeDailyLimit
    }
}
