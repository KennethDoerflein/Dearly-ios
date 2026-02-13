//
//  RestorePreviewView.swift
//  Dearly
//
//  Preview and selection UI for restoring cards from a backup bundle
//

import SwiftUI

/// Card preview item for backup restore
struct RestoreCardPreview: Identifiable {
    let id: String
    let sender: String?
    let occasion: String?
    let date: String
    let thumbnail: UIImage?
}

/// View for previewing and selecting cards to restore from a backup
struct RestorePreviewView: View {
    let previews: [RestoreCardPreview]
    let onRestore: (Set<String>) -> Void
    let onCancel: () -> Void
    
    @State private var selectedIds: Set<String>
    
    init(
        previews: [RestoreCardPreview],
        onRestore: @escaping (Set<String>) -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.previews = previews
        self.onRestore = onRestore
        self.onCancel = onCancel
        self._selectedIds = State(initialValue: Set(previews.map { $0.id }))
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Header with Select All / Deselect All
                HStack {
                    Button("Select All") {
                        selectedIds = Set(previews.map { $0.id })
                    }
                    .disabled(selectedIds.count == previews.count)
                    
                    Spacer()
                    
                    Button("Deselect All") {
                        selectedIds.removeAll()
                    }
                    .disabled(selectedIds.isEmpty)
                }
                .padding(.horizontal)
                .padding(.vertical, 12)
                
                Divider()
                
                // Card grid
                ScrollView {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 100, maximum: 140))], spacing: 12) {
                        ForEach(previews) { preview in
                            CardPreviewCell(
                                preview: preview,
                                isSelected: selectedIds.contains(preview.id),
                                onToggle: {
                                    if selectedIds.contains(preview.id) {
                                        selectedIds.remove(preview.id)
                                    } else {
                                        selectedIds.insert(preview.id)
                                    }
                                }
                            )
                        }
                    }
                    .padding()
                }
                
                Divider()
                
                // Footer
                VStack(spacing: 12) {
                    Text("\(selectedIds.count) of \(previews.count) cards selected")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Button(action: {
                        onRestore(selectedIds)
                    }) {
                        Text("Restore Selected")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(selectedIds.isEmpty ? Color.gray : Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(12)
                    }
                    .disabled(selectedIds.isEmpty)
                }
                .padding()
            }
            .navigationTitle("Restore Backup")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: onCancel)
                }
            }
        }
    }
}

/// Individual card preview cell
private struct CardPreviewCell: View {
    let preview: RestoreCardPreview
    let isSelected: Bool
    let onToggle: () -> Void
    
    var body: some View {
        Button(action: onToggle) {
            VStack(spacing: 8) {
                ZStack(alignment: .topTrailing) {
                    // Thumbnail
                    if let thumbnail = preview.thumbnail {
                        Image(uiImage: thumbnail)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 100, height: 140)
                            .clipped()
                            .cornerRadius(8)
                    } else {
                        Rectangle()
                            .fill(Color.gray.opacity(0.2))
                            .frame(width: 100, height: 140)
                            .cornerRadius(8)
                            .overlay(
                                Image(systemName: "photo")
                                    .font(.largeTitle)
                                    .foregroundColor(.gray)
                            )
                    }
                    
                    // Selection indicator
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .font(.title2)
                        .foregroundColor(isSelected ? .blue : .gray)
                        .background(
                            Circle()
                                .fill(Color.white)
                                .frame(width: 22, height: 22)
                        )
                        .padding(6)
                }
                
                // Card info
                VStack(spacing: 2) {
                    Text(preview.sender ?? "Unknown")
                        .font(.caption)
                        .fontWeight(.medium)
                        .lineLimit(1)
                    
                    if let occasion = preview.occasion {
                        Text(occasion)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                }
            }
        }
        .buttonStyle(.plain)
        .opacity(isSelected ? 1.0 : 0.6)
    }
}

#Preview {
    RestorePreviewView(
        previews: [
            RestoreCardPreview(id: "1", sender: "Mom", occasion: "Birthday", date: "2025-12-25", thumbnail: nil),
            RestoreCardPreview(id: "2", sender: "Dad", occasion: "Holiday", date: "2025-12-25", thumbnail: nil),
            RestoreCardPreview(id: "3", sender: "Grandma", occasion: "Christmas", date: "2025-12-25", thumbnail: nil)
        ],
        onRestore: { ids in print("Restore: \(ids)") },
        onCancel: { print("Cancel") }
    )
}
