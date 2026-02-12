//
//  VersionHistoryView.swift
//  Dearly
//
//  Created on 1/21/26.
//

import SwiftUI

struct VersionHistoryView: View {
    @Binding var card: Card
    @Environment(\.dismiss) private var dismiss
    
    // Sort versions newest first
    private var history: [CardVersionSnapshot] {
        (card.versionHistory ?? []).sorted { $0.versionNumber > $1.versionNumber }
    }
    
    @State private var versionToRestore: CardVersionSnapshot?
    @State private var showingRestoreConfirmation = false
    
    var body: some View {
        NavigationStack {
            List {
                if history.isEmpty {
                    ContentUnavailableView(
                        "No Edit History",
                        systemImage: "clock.arrow.circlepath",
                        description: Text("Edits made to this card will appear here.")
                    )
                } else {
                    ForEach(history) { snapshot in
                        VersionRow(snapshot: snapshot, cardId: card.id)
                            .swipeActions(edge: .trailing) {
                                Button(role: .destructive) {
                                    deleteSnapshot(snapshot)
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                                
                                Button {
                                    versionToRestore = snapshot
                                    showingRestoreConfirmation = true
                                } label: {
                                    Label("Restore", systemImage: "arrow.counterclockwise")
                                }
                                .tint(.blue)
                            }
                    }
                }
            }
            .navigationTitle("Version History")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .confirmationDialog(
                "Restore Version?",
                isPresented: $showingRestoreConfirmation,
                titleVisibility: .visible,
                presenting: versionToRestore
            ) { snapshot in
                Button("Restore Version \(snapshot.versionNumber)") {
                    restoreVersion(snapshot)
                }
                Button("Cancel", role: .cancel) {
                    versionToRestore = nil
                }
            } message: { snapshot in
                Text("Current changes will be saved as a new version before restoring. Are you sure you want to restore Version \(snapshot.versionNumber)?")
            }
        }
    }
    
    private func deleteSnapshot(_ snapshot: CardVersionSnapshot) {
        card.deleteSnapshot(snapshot)
    }
    
    private func restoreVersion(_ snapshot: CardVersionSnapshot) {
        card.restore(to: snapshot)
        dismiss() // Dismiss after restore to show result
    }
}

struct VersionRow: View {
    let snapshot: CardVersionSnapshot
    let cardId: UUID
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Version \(snapshot.versionNumber)")
                    .font(.headline)
                
                Spacer()
                
                Text(snapshot.editedAt.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            if !snapshot.metadataChanges.isEmpty {
                Text("Metadata Changes:")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .padding(.top, 4)
                
                ForEach(snapshot.metadataChanges, id: \.field) { change in
                    HStack {
                        Text(change.field.rawValue)
                            .fontWeight(.medium)
                        Spacer()
                        Text(change.previousValue ?? "Empty")
                            .strikethrough()
                            .foregroundStyle(.secondary)
                        Image(systemName: "arrow.right")
                            .font(.caption2)
                        Text(change.newValue ?? "Empty")
                    }
                    .font(.caption)
                }
            }
            
            if !snapshot.imageChanges.isEmpty {
                Text("Image Changes:")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .padding(.top, 4)
                
                ForEach(snapshot.imageChanges, id: \.slot) { change in
                    HStack {
                        Text(change.slot.rawValue.capitalized)
                            .fontWeight(.medium)
                        Spacer()
                        if let url = ImageStorageService.shared.getImageURL(for: change.previousUri),
                           let image = UIImage(contentsOfFile: url.path) {
                            Image(uiImage: image)
                                .resizable()
                                .scaledToFit()
                                .frame(height: 40)
                                .cornerRadius(4)
                        } else {
                            Text("Missing Image")
                                .italic()
                        }
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }
}
