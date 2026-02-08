//
//  SettingsView.swift
//  Dearly
//
//  User-facing settings for iCloud backup and app preferences
//

import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @ObservedObject var viewModel: CardsViewModel
    
    // Import state
    @State private var showingFilePicker = false
    @State private var showingImportResult = false
    @State private var importResultMessage = ""
    @State private var importSucceeded = false
    
    // iCloud sync state
    @State private var isSyncing = false
    @State private var isRestoring = false
    @State private var cloudCardCount = 0
    @State private var cloudTotalSize: Int64 = 0
    @State private var showingSyncResult = false
    @State private var syncResultMessage = ""
    @State private var syncSucceeded = false
    @State private var showingRestoreOptions = false
    @State private var showingDeleteCloudConfirmation = false
    
    // Tutorial state
    @State private var showingImportTutorial = false
    
    private let backupService = iCloudBackupService.shared
    
    var body: some View {
        NavigationStack {
            Form {
                // iCloud Backup Section
                iCloudBackupSection
                
                // Import/Export Section
                Section(header: Text("Import & Export")) {
                    Button(action: {
                        showingFilePicker = true
                    }) {
                        HStack {
                            Image(systemName: "square.and.arrow.down.fill")
                                .foregroundColor(Color(red: 0.75, green: 0.55, blue: 0.5))
                            Text("Import .dearly File")
                            Spacer()
                        }
                    }
                    
                    Button(action: {
                        showingImportTutorial = true
                    }) {
                        HStack {
                            Image(systemName: "questionmark.circle.fill")
                                .foregroundColor(Color(red: 0.5, green: 0.7, blue: 0.85))
                            Text("How to Import Cards")
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                // App Info Section
                Section(header: Text("About")) {
                    HStack {
                        Text("Cards Saved")
                        Spacer()
                        Text("\(viewModel.cards.count)")
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text("Version")
                        Spacer()
                        Text(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0")
                            .foregroundColor(.secondary)
                    }
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .preferredColorScheme(.light)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(Color(red: 0.85, green: 0.55, blue: 0.55))
                }
            }
            .fileImporter(
                isPresented: $showingFilePicker,
                allowedContentTypes: [.data],
                allowsMultipleSelection: false
            ) { result in
                handleFileImport(result: result)
            }
            .alert(importSucceeded ? "Import Successful" : "Import Failed", isPresented: $showingImportResult) {
                Button("OK") {
                    if importSucceeded {
                        viewModel.loadCards()
                    }
                }
            } message: {
                Text(importResultMessage)
            }
            .alert(syncSucceeded ? "Success" : "Error", isPresented: $showingSyncResult) {
                Button("OK") {
                    if syncSucceeded {
                        Task {
                            await loadCloudInfo()
                        }
                    }
                }
            } message: {
                Text(syncResultMessage)
            }
            .confirmationDialog("Restore Options", isPresented: $showingRestoreOptions) {
                Button("Import All Cards") {
                    performRestore(replaceExisting: false)
                }
                Button("Replace All Local Cards", role: .destructive) {
                    performRestore(replaceExisting: true)
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Import cards from iCloud. This will add \(cloudCardCount) cards to your collection.")
            }
            .confirmationDialog("Delete iCloud Backup?", isPresented: $showingDeleteCloudConfirmation) {
                Button("Delete All from iCloud", role: .destructive) {
                    deleteAllFromCloud()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This will delete all \(cloudCardCount) cards from iCloud Drive. Your local cards will not be affected.")
            }
            .sheet(isPresented: $showingImportTutorial) {
                ImportTutorialView()
            }
            .task {
                await loadCloudInfo()
            }
        }
    }
    
    // MARK: - iCloud Backup Section
    
    @ViewBuilder
    private var iCloudBackupSection: some View {
        Section(header: Text("iCloud Backup")) {
            // Status row
            HStack {
                Image(systemName: backupService.isICloudAvailable ? "icloud.fill" : "icloud.slash")
                    .foregroundColor(backupService.isICloudAvailable ? Color(red: 0.3, green: 0.6, blue: 0.9) : .red)
                    .font(.system(size: 24))
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("iCloud Backup")
                        .font(.body.weight(.medium))
                    
                    if backupService.isICloudAvailable {
                        if cloudCardCount > 0 {
                            Text("\(cloudCardCount) cards backed up • \(formatFileSize(cloudTotalSize))")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        } else {
                            Text("No backup yet")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        if let lastDate = backupService.lastSyncDate {
                            Text("Last backup: \(lastDate.formatted(date: .abbreviated, time: .shortened))")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    } else {
                        Text("Sign in to iCloud to enable backup")
                            .font(.caption)
                            .foregroundColor(.red)
                    }
                }
                
                Spacer()
            }
            .padding(.vertical, 4)
            
            // Backup Now button
            Button(action: {
                performSync()
            }) {
                HStack {
                    if isSyncing {
                        ProgressView()
                            .scaleEffect(0.8)
                    } else {
                        Image(systemName: "icloud.and.arrow.up.fill")
                            .foregroundColor(Color(red: 0.75, green: 0.55, blue: 0.5))
                    }
                    Text(isSyncing ? "Backing Up..." : "Backup Now")
                    Spacer()
                    if !isSyncing {
                        Text("\(viewModel.cards.count) cards")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .disabled(!backupService.isICloudAvailable || isSyncing || isRestoring || viewModel.cards.isEmpty)
            
            // Restore button
            Button(action: {
                showingRestoreOptions = true
            }) {
                HStack {
                    if isRestoring {
                        ProgressView()
                            .scaleEffect(0.8)
                    } else {
                        Image(systemName: "arrow.clockwise.icloud.fill")
                            .foregroundColor(Color(red: 0.5, green: 0.75, blue: 0.6))
                    }
                    Text(isRestoring ? "Restoring..." : "Restore from Backup")
                    Spacer()
                    if cloudCardCount > 0 && !isRestoring {
                        Text("\(cloudCardCount) cards")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .disabled(!backupService.isICloudAvailable || isSyncing || isRestoring || cloudCardCount == 0)
            
            // Delete from iCloud button
            if cloudCardCount > 0 {
                Button(action: {
                    showingDeleteCloudConfirmation = true
                }) {
                    HStack {
                        Image(systemName: "trash.fill")
                            .foregroundColor(.red)
                        Text("Delete iCloud Backup")
                        Spacer()
                    }
                }
                .disabled(isSyncing || isRestoring)
            }
            
            // Info text
            Text("Your cards are stored as .dearly files in iCloud Drive. You can find them in the Files app under iCloud Drive › Dearly › Cards.")
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.top, 4)
        }
    }
    
    // MARK: - iCloud Actions
    
    private func loadCloudInfo() async {
        if let info = await backupService.getCloudInfo() {
            cloudCardCount = info.cardCount
            cloudTotalSize = info.totalSize
        } else {
            cloudCardCount = 0
            cloudTotalSize = 0
        }
    }
    
    private func performSync() {
        isSyncing = true
        
        Task {
            do {
                let result = try await backupService.syncToCloud(cards: viewModel.cards)
                
                await MainActor.run {
                    if result.isSuccess {
                        syncResultMessage = "Backed up \(result.uploaded) cards to iCloud"
                        if result.skipped > 0 {
                            syncResultMessage += " (\(result.skipped) already up to date)"
                        }
                    } else {
                        syncResultMessage = "Backed up \(result.uploaded) cards, \(result.failed) failed"
                    }
                    syncSucceeded = result.isSuccess
                    isSyncing = false
                    showingSyncResult = true
                    
                    let notification = UINotificationFeedbackGenerator()
                    notification.notificationOccurred(result.isSuccess ? .success : .warning)
                }
            } catch {
                await MainActor.run {
                    syncResultMessage = error.localizedDescription
                    syncSucceeded = false
                    isSyncing = false
                    showingSyncResult = true
                }
            }
        }
    }
    
    private func performRestore(replaceExisting: Bool) {
        isRestoring = true
        
        Task {
            do {
                let result = try await backupService.restoreFromCloud(
                    modelContext: modelContext,
                    replaceExisting: replaceExisting
                )
                
                await MainActor.run {
                    viewModel.loadCards()
                    if result.isSuccess {
                        syncResultMessage = "Restored \(result.imported) cards from iCloud"
                        if result.skipped > 0 {
                            syncResultMessage += " (\(result.skipped) already existed)"
                        }
                    } else {
                        syncResultMessage = "Restored \(result.imported) cards, \(result.failed) failed"
                    }
                    syncSucceeded = result.isSuccess
                    isRestoring = false
                    showingSyncResult = true
                    
                    let notification = UINotificationFeedbackGenerator()
                    notification.notificationOccurred(.success)
                }
            } catch {
                await MainActor.run {
                    syncResultMessage = error.localizedDescription
                    syncSucceeded = false
                    isRestoring = false
                    showingSyncResult = true
                }
            }
        }
    }
    
    private func deleteAllFromCloud() {
        Task {
            do {
                try backupService.deleteAllFromCloud()
                await loadCloudInfo()
                
                await MainActor.run {
                    syncResultMessage = "Deleted all cards from iCloud"
                    syncSucceeded = true
                    showingSyncResult = true
                    
                    let impact = UIImpactFeedbackGenerator(style: .medium)
                    impact.impactOccurred()
                }
            } catch {
                await MainActor.run {
                    syncResultMessage = error.localizedDescription
                    syncSucceeded = false
                    showingSyncResult = true
                }
            }
        }
    }
    
    private func formatFileSize(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
    
    // MARK: - File Import
    
    private func handleFileImport(result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let fileURL = urls.first else {
                importResultMessage = "No file selected"
                importSucceeded = false
                showingImportResult = true
                return
            }
            
            let isSecurityScoped = fileURL.startAccessingSecurityScopedResource()
            
            defer {
                if isSecurityScoped {
                    fileURL.stopAccessingSecurityScopedResource()
                }
            }
            
            do {
                let tempURL = try copyToTempDirectory(url: fileURL)
                defer {
                    try? FileManager.default.removeItem(at: tempURL)
                }
                
                let card = try DearlyFileService.shared.importCard(from: tempURL, using: modelContext)
                importResultMessage = "Successfully imported card from \(card.sender ?? "unknown sender")"
                importSucceeded = true
                
                let notification = UINotificationFeedbackGenerator()
                notification.notificationOccurred(.success)
            } catch let error as DearlyFileError {
                importResultMessage = error.localizedDescription
                importSucceeded = false
            } catch {
                importResultMessage = "Could not access the selected file: \(error.localizedDescription)"
                importSucceeded = false
            }
            
            showingImportResult = true
            
        case .failure(let error):
            importResultMessage = error.localizedDescription
            importSucceeded = false
            showingImportResult = true
        }
    }
    
    private func copyToTempDirectory(url: URL) throws -> URL {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        let tempURL = tempDir.appendingPathComponent(url.lastPathComponent)
        try FileManager.default.copyItem(at: url, to: tempURL)
        return tempURL
    }
}

#Preview {
    SettingsView(viewModel: CardsViewModel())
        .modelContainer(for: Card.self, inMemory: true)
}
