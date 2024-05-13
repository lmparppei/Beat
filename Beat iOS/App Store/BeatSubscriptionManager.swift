//
//  BeatSubscriptionManager.swift
//  Beat iOS
//
//  Created by Lauri-Matti Parppei on 12.5.2024.
//  Copyright © 2024 Lauri-Matti Parppei. All rights reserved.
//
/**
 
 Use this class to check if a lifetime subscription was bought via App Store.
 If you want to remove the checks, just set `avoidPaywall` as `true`.
 
 */

import Foundation
import StoreKit

fileprivate let avoidPaywall = false
fileprivate let lifetimeLicense = "lifetimeLicense"
fileprivate let allProducts = [lifetimeLicense, "testing"]

@MainActor
class BeatSubscriptionsManager: ObservableObject {
	static public let shared = BeatSubscriptionsManager()
	
	@Published
	var productIds: [String] = []
	var purchasedProductIDs: Set<String> = []
	
	private init() {
		self.productIds = allProducts
	}
	
	
	@MainActor
	public func unlocked() async -> Bool {
		// Set avoidPaywall as true to circumvent paywall
		if avoidPaywall { return true }
		
		// First check if we've already unlocked the app
		var unlocked = self.storedUnlockStatus()
		if unlocked { return true }
		
		// If not, check it using StoreKit API
		await updatePurchasedProducts()
				
		productIds.forEach { productId in
			if purchasedProductIDs.contains(productId) {
				unlocked = true
			}
		}
		
		// Make it persistent
		if unlocked {
			UserDefaults.standard.setValue(unlocked, forKey: lifetimeLicense)
		}
		
		return unlocked
	}
	
	@MainActor
	func updatePurchasedProducts() async {
		var purchasedProductIDs = Set<String>()
		for await result in Transaction.currentEntitlements {
			guard case .verified(let transaction) = result else {
				continue
			}
			if transaction.revocationDate == nil {
				purchasedProductIDs.insert(transaction.productID)
			} else {
				purchasedProductIDs.remove(transaction.productID)
			}
		}
		
		// only update if changed to avoid unnecessary published triggers
		if purchasedProductIDs != self.purchasedProductIDs {
			self.purchasedProductIDs = purchasedProductIDs
		}
	}
	
	@MainActor
	func storedUnlockStatus() -> Bool {
		// If a receipt is available, the app was purchased through App Store
		// if let receiptURL = Bundle.main.appStoreReceiptURL, receiptURL.lastPathComponent != "sandboxReceipt" {
		if let receiptURL = Bundle.main.appStoreReceiptURL {
			print("App Store receipt", receiptURL)
			return true
		}
		
		// In other case, we'll check the stored boolean
		#if USE_ICLOUD_STORAGE
		let storage = NSUbiquitousKeyValueStore.default
		#else
		let storage = UserDefaults.standard
		#endif
		return storage.bool(forKey: lifetimeLicense)
	}
}
