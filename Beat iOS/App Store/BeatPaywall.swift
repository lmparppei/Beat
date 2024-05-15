//
//  BeatPaywall.swift
//  Beat iOS
//
//  Created by Lauri-Matti Parppei on 12.5.2024.
//  Copyright © 2024 Lauri-Matti Parppei. All rights reserved.
//

import UIKit
import SwiftUI
import StoreKit

class BeatPaywallViewController:UIHostingController<BeatPaywallView> {
	var afterClosing: (() -> Void)
	
	init(rootView:BeatPaywallView, afterClosing: @escaping () -> Void) {
		self.afterClosing = afterClosing
		super.init(rootView: rootView)
	}
	
	@MainActor required dynamic init?(coder aDecoder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}


	override func viewDidDisappear(_ animated: Bool) {
		super.viewDidDisappear(animated)
		self.afterClosing()
	}
}

struct BeatPaywallView: View {
	var dismissAction: (() -> Void)
	@State private var redeemSheetIsPresented = false
	
	var body: some View {
		ScrollView {
			ZStack {
				// Reserve space matching the scroll view's frame
				Spacer().containerRelativeFrame([.horizontal, .vertical])
				VStack(alignment: .center, spacing: 20.0) {
					GeometryReader { geometry in
						VStack(spacing: 0) {
							VStack(spacing: 20.0) {
								Image("Icon-MacOS-512x512", bundle: Bundle.main)
									.resizable()
									.scaledToFill()
									.frame(width: 120, height: 120)
								
								Text("Beat is made with love and care ❤️")
									.multilineTextAlignment(.center).font(.title2).fontWeight(.bold)
									.frame(width: geometry.size.width)
								
								Text("The full desktop version is completely free now and always. However, to cover development costs, PDF export on iOS is hidden behind paywall.\n\nFor one single-time fee, you will own Beat for iOS forever — and help keep the lights on!")
									.multilineTextAlignment(.center)
									.frame(width: geometry.size.width)
							}
						}
					}
					
					ProductView(id: BeatSubscriptionsManager.shared.productIds.first ?? "license.lifetime")
						.productViewStyle(.large)
						.storeButton(.visible, for: .redeemCode, .restorePurchases)
						.onInAppPurchaseCompletion { product, result in
							dismissAction()
						}
					
					Button {
						Task {
							do {
								try await AppStore.sync()
								let unlocked = await BeatSubscriptionsManager.shared.unlocked()
								if unlocked { dismissAction() }
							} catch {
								print(error)
							}
						}
					} label: {
						Text("Restore Purchases")
					}
					.buttonStyle(PlainButtonStyle())
					.foregroundStyle(.tint)
				}
				.frame(maxWidth: 400)
				.padding()
			}
		}.padding()
	}
}
