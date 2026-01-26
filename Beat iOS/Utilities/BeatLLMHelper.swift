//
//  BeatLLMHelper.swift
//  Beat iOS
//
//  Created by Lauri-Matti Parppei on 24.1.2026.
//  Copyright © 2026 Lauri-Matti Parppei. All rights reserved.
//

import FoundationModels
import Observation
import BeatCore

@available(iOS 26.0, *)

@available(iOS 26.0, *)
class BeatLLMHelper:NSObject {
	let session: LanguageModelSession
	
	let prompt = "Give me a short, concise one-line synopsis of the following film scene:\n\n"
	
	override init() {
		self.session = LanguageModelSession() {
		"""
		You are a professional screenwriter assistant. Your task is to generate short, concise one-line synopsis for a given film scene.
		"""
		}
	}
	
	func getSynopsis(scene:OutlineScene, delegate:BeatEditorDelegate) async throws -> String {
		let text = delegate.text().substring(range: scene.range())
		let query = prompt + text
		
		let stream = session.streamResponse(to: query)
		var generatedSynopsis = ""
		
		for try await partial in stream {
			generatedSynopsis += partial.content
		}
		
		return generatedSynopsis
	}
}
