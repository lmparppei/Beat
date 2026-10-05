//
//  BeatCharacterEditor.swift
//  Beat iOS
//
//  Created by Lauri-Matti Parppei on 26.9.2026.
//  Copyright © 2026 Lauri-Matti Parppei. All rights reserved.
//

import UIKit
import SwiftUI
import BeatCore

// MARK: - View controller

/// UIKit entry point. Present or push this from anywhere in your iOS app.
@objc class BeatCharacterListViewController: UIViewController {
	@objc weak var editorDelegate: BeatEditorDelegate?

	private var characterList: CharacterListModel
	private var hostingController: UIHostingController<CharacterListView>?

	@objc init(editorDelegate: BeatEditorDelegate) {
		self.characterList = CharacterListModel(editorDelegate: editorDelegate)
		self.editorDelegate = editorDelegate
		super.init(nibName: nil, bundle: nil)
	}

	required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

	override func viewDidLoad() {
		super.viewDidLoad()

		hostingController = UIHostingController(rootView: CharacterListView(model: characterList, onDone: { [weak self] in
			self?.dismiss(animated: true)
		}))
		
		
		if let hostingController {
			addChild(hostingController)
			hostingController.view.translatesAutoresizingMaskIntoConstraints = false
			view.addSubview(hostingController.view)
			
			NSLayoutConstraint.activate([
				hostingController.view.topAnchor.constraint(equalTo: view.topAnchor),
				hostingController.view.bottomAnchor.constraint(equalTo: view.bottomAnchor),
				hostingController.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
				hostingController.view.trailingAnchor.constraint(equalTo: view.trailingAnchor)
			])
			hostingController.didMove(toParent: self)
		}
	}

	// A remnant from macOS. On iOS, we can't change the screenplay while the editor is visible.
	@objc func reloadView() {
		characterList.reload()
	}
}


// MARK: - Gender

enum CharacterGender: String, CaseIterable, Identifiable {
	case unspecified, woman, man, other
	var id: String { rawValue }

	init(string: String) {
		self = CharacterGender(rawValue: string) ?? .unspecified
	}

	var title: String { NSLocalizedString("gender." + rawValue, comment: "") }

	/// Swap in your own theme colors here
	var color: Color {
		let theme = ThemeManager.shared()!
		
		switch self {
		case .woman: return Color(theme.genderWomanColor)
		case .man: return Color(theme.genderManColor)
		case .other: return Color(theme.genderOtherColor)
		case .unspecified: return Color(theme.genderUnspecifiedColor)
		}
	}
}


// MARK: - List model

@MainActor
final class CharacterListModel: ObservableObject {
	struct Entry: Identifiable {
		let id: String
		let character: BeatCharacter
		var lines: Int { Int(character.lines) }
	}

	@Published private(set) var entries: [Entry] = []
	@Published private(set) var mostLines: Int = 1

	weak var editorDelegate: BeatEditorDelegate?

	init(editorDelegate: BeatEditorDelegate) {
		self.editorDelegate = editorDelegate
		reload()
	}

	func reload() {
		guard let delegate = editorDelegate else { return }
		let data = BeatCharacterData(delegate: delegate)
		let characters = data.charactersAndLines()

		// Most lines first, alphabetical for ties
		entries = characters
			.map { Entry(id: $0.key, character: $0.value) }
			.sorted {
				if $0.lines == $1.lines { return $0.character.name < $1.character.name }
				return $0.lines > $1.lines
			}
		mostLines = max(entries.first?.lines ?? 1, 1)
	}

	func save(_ character: BeatCharacter, colorChanged: Bool = false) {
		guard let delegate = editorDelegate else { return }
		BeatCharacterData(delegate: delegate).saveCharacter(character)

		if colorChanged {
			// Recolor character cues and dialogue in the script. This is such an elegant solution in ObjC but not so much in Swift.
			let types: IndexSet = [
				Int(LineType.character.rawValue),
				Int(LineType.parenthetical.rawValue),
				Int(LineType.dialogue.rawValue),
				Int(LineType.dualDialogueCharacter.rawValue),
				Int(LineType.dualDialogueParenthetical.rawValue),
				Int(LineType.dualDialogue.rawValue)
			]
			delegate.formatting.refreshTextColors(forTypes: types, range: NSRange(location: 0, length: delegate.text().count))
		}

		reload()
	}

	/// Names of every character except the given one (for aliases)
	func otherNames(than name: String) -> [String] {
		entries.map(\.id).filter { $0 != name }.sorted()
	}
}

// MARK: - List view

struct CharacterListView: View {
	@ObservedObject var model: CharacterListModel

	var onDone:() -> Void = {}
	
	var body: some View {
		NavigationStack {
			List(model.entries) { entry in
				NavigationLink {
					CharacterEditorView(character: entry.character, model: model)
				} label: {
					CharacterRow(entry: entry, mostLines: model.mostLines)
				}
			}
			.listStyle(.plain)
			.navigationTitle(NSLocalizedString("characters.title", value: "Characters", comment: ""))
			.navigationBarTitleDisplayMode(.inline)
			.toolbar {
				ToolbarItem(placement: .confirmationAction) {
					Button(NSLocalizedString("character.editor.done", comment: ""), action: onDone)
						.fontWeight(.semibold)
				}
			}
			.overlay {
				if model.entries.isEmpty {
					Text(NSLocalizedString("characters.empty", value: "No characters yet", comment: ""))
						.foregroundStyle(.secondary)
				}
			}
		}
		.onAppear { model.reload() }
	}
}

struct CharacterRow: View {
	let entry: CharacterListModel.Entry
	let mostLines: Int

	private var nameColor: Color {
		if let c = BeatColors.color(entry.character.highlightColor) { return Color(c) }
		return .primary
	}

	var body: some View {
		HStack(spacing: 8) {
			Text(entry.character.name)
				.foregroundStyle(nameColor)
				.lineLimit(1)
				.frame(maxWidth: .infinity, alignment: .leading)
				.layoutPriority(1)

			LinesBar(character: entry.character,
					 fraction: CGFloat(entry.lines) / CGFloat(mostLines))
				.frame(width: 120, height: 24)

			Text("\(entry.lines)")
				.font(.callout.monospacedDigit())
				.foregroundStyle(.secondary)
				.frame(minWidth: 32, alignment: .trailing)
		}
		.padding(.vertical, 2)
	}
}

/// Rounded bar, same logic as the macOS row view
struct LinesBar: View {
	let character: BeatCharacter
	let fraction: CGFloat

	private var color: Color {
		if let c = BeatColors.color(character.highlightColor) { return Color(c) }
		return CharacterGender(string: character.gender).color
	}

	var body: some View {
		GeometryReader { geo in
			let width = max(geo.size.width * fraction, 2)
			let height = geo.size.height * 0.6
			RoundedRectangle(cornerRadius: 2)
				.fill(color.opacity(min(max(Double(fraction), 0.2), 1.0)))
				.frame(width: width, height: height)
				.frame(maxHeight: .infinity, alignment: .center)
		}
	}
}

// MARK: - Editor

struct CharacterEditorView: View {
	let character: BeatCharacter
	@ObservedObject var model: CharacterListModel

	@State private var gender: CharacterGender = .unspecified
	@State private var bio: String = ""
	@State private var age: String = ""
	@State private var highlightColor: String = ""
	@State private var aliases: [String] = []
	@State private var changed = false
	@State private var loaded = false
	
	private var statistics: String {
		"\(character.lines) \(NSLocalizedString("statistics.lines", comment: "lines")) • " +
		"\(character.scenes.count) \(NSLocalizedString("statistics.scenes", comment: "scenes"))"
	}

	var body: some View {
		Form {
			Section(NSLocalizedString("character.editor.gender", value: "Gender", comment: "")) {
				Picker("Gender", selection: $gender) {
					ForEach(CharacterGender.allCases) { Text($0.title).tag($0) }
				}
				.pickerStyle(.segmented)
				.labelsHidden()
			}

			Section(NSLocalizedString("character.editor.age", value: "Age", comment: "")) {
				TextField(NSLocalizedString("character.editor.age", value: "Age", comment: ""), text: $age)
			}

			Section(NSLocalizedString("character.editor.color", value: "Highlight Color", comment: "")) {
				HighlightColorPicker(selection: $highlightColor)
			}

			Section(NSLocalizedString("character.editor.bio", value: "Biography", comment: "")) {
				TextEditor(text: $bio)
					.frame(minHeight: 140)
			}

			Section(NSLocalizedString("character.editor.aliases", value: "Aliases", comment: "")) {
				ForEach(aliases, id: \.self) { Text($0) }
					.onDelete { aliases.remove(atOffsets: $0) }

				Menu {
					ForEach(model.otherNames(than: character.name), id: \.self) { name in
						Button {
							toggleAlias(name)
						} label: {
							if aliases.contains(name) {
								Label(name, systemImage: "checkmark")
							} else {
								Text(name)
							}
						}
					}
				} label: {
					Label(BeatLocalization.localizedString(forKey: "character.editor.addAlias"),
						  systemImage: "person.badge.plus")
				}
			}
		}
		.navigationTitle(character.name)
		.navigationBarTitleDisplayMode(.inline)
		.toolbar {
			ToolbarItem(placement: .principal) {
				VStack(spacing: 0) {
					Text(character.name)
						.font(.headline)
					Text(statistics)
						.font(.caption)
						.foregroundStyle(.secondary)
				}
			}
		}
		.onAppear(perform: load)
		.onDisappear(perform: save)
		.onChange(of: gender) { _, _ in changed = true }
		.onChange(of: bio) { _, _ in changed = true }
		.onChange(of: age) { _, _ in changed = true }
		.onChange(of: highlightColor) { _, _ in changed = true }
		.onChange(of: aliases) { _, _ in changed = true }
	}

	private func load() {
		guard !loaded else { return }
		
		gender = CharacterGender(string: character.gender)
		bio = character.bio
		age = character.age
		highlightColor = character.highlightColor
		aliases = character.aliases
		
		// Loading triggers onChange; reset on the next runloop pass
		DispatchQueue.main.async {
			changed = false;
			loaded = true
		}
	}

	private func toggleAlias(_ name: String) {
		if let i = aliases.firstIndex(of: name) { aliases.remove(at: i) }
		else { aliases.append(name) }
	}

	private func save() {
		guard changed else { return }
		let colorChanged = (character.highlightColor != highlightColor)

		character.gender = gender.rawValue
		character.bio = bio
		character.age = age
		character.highlightColor = highlightColor
		character.aliases = aliases
		model.save(character, colorChanged: colorChanged)
		
		model.editorDelegate?.addToChangeCount()
		
		changed = false
	}
}

// MARK: - Highlight color picker

/// Row of swatches: none, the named colors, and a custom color via the system picker.
/// `selection` is a color key ("red", "mint"...), "" for none, or "#RRGGBB" for custom.
struct HighlightColorPicker: View {
	@Binding var selection: String
	@State private var custom: Color = Color(white: 0.5)

	static let keys = ["red", "blue", "green", "pink", "brown", "cyan",
					   "orange", "magenta", "cherry", "mint", "violet"]

	private var isCustom: Bool { selection.hasPrefix("#") }

	var body: some View {
		ScrollView(.horizontal, showsIndicators: false) {
			HStack(spacing: 14) {
				swatch(key: "", color: nil)

				ForEach(Self.keys, id: \.self) { key in
					swatch(key: key, color: BeatColors.color(key).map { Color($0) })
				}

				ColorPicker("Custom", selection: customBinding, supportsOpacity: false)
					.labelsHidden()
					.padding(3)
					.overlay(Circle().stroke(Color.accentColor, lineWidth: isCustom ? 2 : 0))
			}
			.padding(.vertical, 4)
			.padding(.horizontal, 2)
		}
		.onAppear {
			if isCustom, let c = BeatColors.color(selection) { custom = Color(c) }
		}
	}

	private var customBinding: Binding<Color> {
		Binding(
			get: { custom },
			set: { newValue in
				custom = newValue
				selection = "#" + BeatColors.get8BitHex(for: UIColor(newValue))
			}
		)
	}

	@ViewBuilder
	private func swatch(key: String, color: Color?) -> some View {
		let selected = (selection == key)
		Button {
			selection = key
		} label: {
			ZStack {
				Circle().fill(color ?? Color(.secondarySystemFill))
				if color == nil {
					// "No color" marker
					Image(systemName: "slash.circle")
						.foregroundStyle(.secondary)
				}
			}
			.frame(width: 28, height: 28)
			.padding(3)
			.overlay(Circle().stroke(Color.accentColor, lineWidth: selected ? 2 : 0))
		}
		.buttonStyle(.plain) // Keeps the Form row itself from becoming one big button
		.accessibilityLabel(key.isEmpty ? "None" : key)
	}
}
