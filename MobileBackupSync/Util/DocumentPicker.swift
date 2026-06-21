//
//  DocumentPicker.swift
//  MobileBackupSync
//
//  Created on 2026-06-21.
//

import SwiftUI
import UniformTypeIdentifiers

/// Wrapper für UIDocumentPickerViewController
struct DocumentPicker: UIViewControllerRepresentable {
    
    let onPick: (URL) -> Void
    let onCancel: () -> Void
    
    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let picker = UIDocumentPickerViewController(
            forOpeningContentTypes: [.folder],
            asCopy: false
        )
        picker.delegate = context.coordinator
        picker.allowsMultipleSelection = false
        picker.shouldShowFileExtensions = true
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(onPick: onPick, onCancel: onCancel)
    }
    
    class Coordinator: NSObject, UIDocumentPickerDelegate {
        let onPick: (URL) -> Void
        let onCancel: () -> Void
        
        init(onPick: @escaping (URL) -> Void, onCancel: @escaping () -> Void) {
            self.onPick = onPick
            self.onCancel = onCancel
        }
        
        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            guard let url = urls.first else { return }
            
            // Start accessing security-scoped resource
            let accessing = url.startAccessingSecurityScopedResource()
            defer {
                if accessing {
                    url.stopAccessingSecurityScopedResource()
                }
            }
            
            onPick(url)
        }
        
        func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
            onCancel()
        }
    }
}

/// Button der einen DocumentPicker öffnet
struct DocumentPickerButton: View {
    
    let label: String
    let onPick: (URL) -> Void
    
    @State private var showingPicker = false
    @State private var selectedURL: URL?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button(action: { showingPicker = true }) {
                HStack {
                    Image(systemName: "folder.badge.plus")
                    Text(label)
                }
            }
            
            if let url = selectedURL {
                HStack {
                    Image(systemName: "folder.fill")
                        .foregroundColor(.blue)
                    Text(url.lastPathComponent)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                    Button(action: { selectedURL = nil }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                }
                .padding(8)
                .background(Color.gray.opacity(0.1))
                .cornerRadius(8)
            }
        }
        .sheet(isPresented: $showingPicker) {
            DocumentPicker(
                onPick: { url in
                    selectedURL = url
                    onPick(url)
                },
                onCancel: {
                    showingPicker = false
                }
            )
        }
    }
}

/// Button für Datei-Auswahl (nicht nur Ordner)
struct FilePickerButton: View {
    
    let label: String
    let contentTypes: [UTType]
    let onPick: (URL) -> Void
    
    @State private var showingPicker = false
    @State private var selectedURL: URL?
    
    init(label: String, contentTypes: [UTType] = [.item], onPick: @escaping (URL) -> Void) {
        self.label = label
        self.contentTypes = contentTypes
        self.onPick = onPick
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button(action: { showingPicker = true }) {
                HStack {
                    Image(systemName: "doc.badge.plus")
                    Text(label)
                }
            }
            
            if let url = selectedURL {
                HStack {
                    Image(systemName: "doc.fill")
                        .foregroundColor(.blue)
                    Text(url.lastPathComponent)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                    Button(action: { selectedURL = nil }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                }
                .padding(8)
                .background(Color.gray.opacity(0.1))
                .cornerRadius(8)
            }
        }
        .sheet(isPresented: $showingPicker) {
            FilePicker(
                contentTypes: contentTypes,
                onPick: { url in
                    selectedURL = url
                    onPick(url)
                },
                onCancel: {
                    showingPicker = false
                }
            )
        }
    }
}

/// Wrapper für UIDocumentPickerViewController zum Datei-Import
struct FilePicker: UIViewControllerRepresentable {
    
    let contentTypes: [UTType]
    let onPick: (URL) -> Void
    let onCancel: () -> Void
    
    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let picker = UIDocumentPickerViewController(
            forOpeningContentTypes: contentTypes,
            asCopy: true
        )
        picker.delegate = context.coordinator
        picker.allowsMultipleSelection = false
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(onPick: onPick, onCancel: onCancel)
    }
    
    class Coordinator: NSObject, UIDocumentPickerDelegate {
        let onPick: (URL) -> Void
        let onCancel: () -> Void
        
        init(onPick: @escaping (URL) -> Void, onCancel: @escaping () -> Void) {
            self.onPick = onPick
            self.onCancel = onCancel
        }
        
        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            guard let url = urls.first else { return }
            onPick(url)
        }
        
        func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
            onCancel()
        }
    }
}
