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
fileprivate let lifetimeLicense = "license.lifetime"
fileprivate let allProducts = [lifetimeLicense, "testing"]

@MainActor
class BeatSubscriptionsManager: ObservableObject {
	static public let shared = BeatSubscriptionsManager()
	
	@Published
	var productIds: [String] = []
	var purchasedProductIDs: Set<String> = []
	
	private init() {
		self.productIds = allProducts
		// Uncomment this to remove license from use
		UserDefaults.standard.removeObject(forKey: lifetimeLicense)
	}
	
	
	@MainActor
	public func unlocked() async -> Bool {
		// Set avoidPaywall as true to circumvent paywall
		if avoidPaywall { return true }
		
		// First check if we've already unlocked the app
		var unlocked = self.storedUnlockStatus()
		if unlocked { return true }
		
		// If not, check it using StoreKit API
		unlocked = await verifyTransaction()
		
		if !unlocked {
			await updatePurchasedProducts()
			
			productIds.forEach { productId in
				if purchasedProductIDs.contains(productId) {
					unlocked = true
				}
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
	func verifyTransaction() async -> Bool {
		// This code is copied straight from Apple. It's here if I want to change my business model.
		// When setting major version to 1, paywall is activated.
		do {
			let shared = try await AppTransaction.shared
			
			if case .verified(let appTransaction) = shared {
				// Hard-code the major version number in which the app's business model changed.
				let newBusinessModelMajorVersion = 100
				
				// Get the major version number of the version the customer originally purchased.
				let versionComponents = appTransaction.originalAppVersion.split(separator: ".")
				let originalMajorVersion = Int(versionComponents[0]) ?? 0
				
				if originalMajorVersion < newBusinessModelMajorVersion {
					// This customer purchased the app before the business model changed.
					// Deliver content that they're entitled to based on their app purchase.
					return true
				} else {
					// This customer purchased the app after the business model changed.
					return false
				}
			}
		}
		catch {
			print("Error in checking transaction", error)
		}
		
		return false
	}
	
	/// Returns `true` if we've stored the transaction
	@MainActor
	func storedUnlockStatus() -> Bool {
		// In other case, we'll check the stored boolean
		#if USE_ICLOUD_STORAGE
		let storage = NSUbiquitousKeyValueStore.default
		#else
		let storage = UserDefaults.standard
		#endif
		return storage.bool(forKey: lifetimeLicense)
	}
}
