//
//  BeatBackupListView.swift
//  Beat iOS
//
//  Created by Lauri-Matti Parppei on 2.7.2025.
//  Copyright © 2025 Lauri-Matti Parppei. All rights reserved.
//

import SwiftUI

struct BackupListView: View {
	let backups: [BeatBackupFile]
	var onSelect: (BeatBackupFile) -> Void
	var onDone: () -> Void

	var body: some View {
		NavigationStack {
			List(backups, id: \.self) { backup in
				Button(action: {
					onSelect(backup)
				}) {
					Text(DateFormatter.smartDate(backup.date))
				}
			}
			.navigationTitle("Backups")
			.toolbar {
				ToolbarItem(placement: .navigationBarTrailing) {
					Button("Done") {
						onDone()
					}
				}
			}
		}
	}
}

extension DateFormatter {
	static let fullDateTimeFormatter: DateFormatter = {
		let formatter = DateFormatter()
		formatter.locale = Locale(identifier: "en_US_POSIX")
		formatter.dateFormat = "d. MMM yyyy HH:mm"
		return formatter
	}()

	static let timeOnlyFormatter: DateFormatter = {
		let formatter = DateFormatter()
		formatter.locale = Locale(identifier: "en_US_POSIX")
		formatter.dateFormat = "HH:mm"
		return formatter
	}()
	
	class func smartDate(_ date:Date) -> String {
		var prefix = ""
		var formatter:DateFormatter
		
		if Calendar.current.isDateInToday(date) || Calendar.current.isDateInYesterday(date) {
			formatter = DateFormatter.timeOnlyFormatter
			prefix = Calendar.current.isDateInToday(date) ? "Today " : "Yesterday "
		} else {
			formatter = DateFormatter.fullDateTimeFormatter
		}
		
		return prefix + formatter.string(from: date)
	}
}
