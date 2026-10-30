//
//  ReaderBlacklistedPagesView.swift
//  Aidoku
//

import SwiftUI
import UIKit

final class ReaderBlacklistedPagesHostingController: UIHostingController<ReaderBlacklistedPagesView> {
    var onDismiss: (() -> Void)?

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        if isBeingDismissed {
            onDismiss?()
            onDismiss = nil
        }
    }
}

struct ReaderBlacklistedPagesView: View {
    var onChange: (() -> Void)?

    @State private var entries: [PageBlacklist.Entry] = PageBlacklist.shared.entries
    @State private var showRemoveAllConfirmation = false

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        PlatformNavigationStack {
            Group {
                if entries.isEmpty {
                    emptyView
                } else {
                    list
                }
            }
            .navigationTitle(NSLocalizedString("BLACKLISTED_PAGES"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(NSLocalizedString("REMOVE_ALL"), role: .destructive) {
                        showRemoveAllConfirmation = true
                    }
                    .disabled(entries.isEmpty)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    CloseButton {
                        dismiss()
                    }
                }
            }
            .alert(
                NSLocalizedString("REMOVE_ALL_BLACKLISTED_PAGES"),
                isPresented: $showRemoveAllConfirmation
            ) {
                Button(NSLocalizedString("CANCEL"), role: .cancel) {}
                Button(NSLocalizedString("REMOVE_ALL"), role: .destructive) {
                    PageBlacklist.shared.removeAll()
                    reload()
                }
            } message: {
                Text(NSLocalizedString("REMOVE_ALL_BLACKLISTED_PAGES_CONFIRM"))
            }
        }
    }

    private var list: some View {
        List {
            ForEach(entries) { entry in
                HStack(spacing: 16) {
                    thumbnail(for: entry)
                    Spacer()
                    Button {
                        remove(entry)
                    } label: {
                        Image(systemName: "trash")
                            .foregroundStyle(.red)
                    }
                    .buttonStyle(.borderless)
                }
                .padding(.vertical, 4)
            }
            .onDelete { offsets in
                for index in offsets {
                    PageBlacklist.shared.remove(id: entries[index].id)
                }
                reload()
            }
        }
    }

    @ViewBuilder
    private func thumbnail(for entry: PageBlacklist.Entry) -> some View {
        if let image = entry.thumbnail {
            Image(uiImage: image)
                .resizable()
                .aspectRatio(max(entry.aspect, 0.1), contentMode: .fit)
                .frame(height: 96)
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .strokeBorder(Color.secondary.opacity(0.3), lineWidth: 1)
                )
        } else {
            Image(systemName: "eye.slash")
                .foregroundStyle(.secondary)
                .frame(height: 96)
        }
    }

    private var emptyView: some View {
        VStack(spacing: 8) {
            Image(systemName: "eye.slash")
                .font(.system(size: 40))
                .foregroundStyle(.secondary)
            Text(NSLocalizedString("NO_BLACKLISTED_PAGES"))
                .font(.headline)
            Text(NSLocalizedString("NO_BLACKLISTED_PAGES_TEXT"))
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, 32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func remove(_ entry: PageBlacklist.Entry) {
        PageBlacklist.shared.remove(id: entry.id)
        reload()
    }

    private func reload() {
        withAnimation {
            entries = PageBlacklist.shared.entries
        }
        onChange?()
    }
}
