import SwiftUI

struct KVNamespaceDetailView: View {
    @Environment(KVViewModel.self) private var kvViewModel
    let namespace: KVNamespace

    @State private var detail: KVNamespace?
    @State private var keyPage: KVNamespaceKeyPage?
    @State private var isLoading = false
    @State private var isLoadingMoreKeys = false
    @State private var errorMessage: String?
    @State private var editorDraft: KVKeyDraft?
    @State private var bulkDraft: KVBulkDraft?

    var body: some View {
        List {
            Section("Namespace") {
                LabeledContent("Title", value: detail?.title ?? namespace.title)
                LabeledContent {
                    Text(namespace.id)
                        .font(.system(.body, design: .monospaced))
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                        .truncationMode(.middle)
                } label: {
                    Text("ID")
                }
                LabeledContent(
                    "URL Encoding",
                    value: (detail?.supportsURLEncoding ?? namespace.supportsURLEncoding) == true ? "Supported" : "Standard"
                )
            }

            Section("Keys Preview") {
                if isLoading && keyPage == nil {
                    ProgressView("Loading Keys")
                } else if let errorMessage {
                    Text(errorMessage)
                        .foregroundStyle(.secondary)
                } else if let keyPage, keyPage.keys.isEmpty == false {
                    ForEach(keyPage.keys) { key in
                        NavigationLink {
                            KVNamespaceKeyValueView(
                                namespaceID: namespace.id,
                                namespaceTitle: detail?.title ?? namespace.title,
                                key: key,
                                onMutation: {
                                    Task {
                                        await loadDetail()
                                    }
                                }
                            )
                        } label: {
                            VStack(alignment: .leading, spacing: 6) {
                                Text(key.name)
                                    .font(.system(.footnote, design: .monospaced).weight(.semibold))
                                    .lineLimit(1)
                                    .truncationMode(.middle)

                                if let expirationDate = key.expirationDate {
                                    Text("Expires \(expirationDate.formatted(date: .abbreviated, time: .shortened))")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(1)
                                }

                                if let metadataSummary = key.metadataSummary {
                                    Text(metadataSummary)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(2)
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    }

                    if keyPage.hasMore {
                        Button {
                            Task {
                                await loadMoreKeys()
                            }
                        } label: {
                            if isLoadingMoreKeys {
                                ProgressView("Loading More Keys")
                            } else {
                                Label("Load More Keys", systemImage: "arrow.down.circle")
                            }
                        }
                        .disabled(isLoadingMoreKeys)
                    }
                } else {
                    Text("No keys returned for this namespace.")
                        .foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle(namespace.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu("Actions") {
                    Button("New Key") {
                        editorDraft = KVKeyDraft(
                            existingKeyName: nil,
                            keyName: "",
                            value: "",
                            metadataText: "",
                            expirationMode: .none,
                            expirationDate: Date(),
                            expirationTTLText: ""
                        )
                    }

                    Button("Bulk Write") {
                        bulkDraft = KVBulkDraft(mode: .write, payload: "")
                    }

                    Button("Bulk Delete") {
                        bulkDraft = KVBulkDraft(mode: .delete, payload: "")
                    }
                }
            }
        }
        .task(id: namespace.id) {
            await loadDetail()
        }
        .refreshable {
            await loadDetail()
        }
        .sheet(item: $editorDraft) { draft in
            NavigationStack {
                KVKeyEditorView(
                    namespaceID: namespace.id,
                    namespaceTitle: detail?.title ?? namespace.title,
                    draft: draft,
                    onSaved: {
                        Task {
                            await loadDetail()
                        }
                    }
                )
            }
        }
        .sheet(item: $bulkDraft) { draft in
            NavigationStack {
                KVBulkOperationView(
                    namespaceID: namespace.id,
                    namespaceTitle: detail?.title ?? namespace.title,
                    draft: draft,
                    onCompleted: {
                        Task {
                            await loadDetail()
                        }
                    }
                )
            }
        }
    }

    private func loadDetail() async {
        isLoading = true
        defer { isLoading = false }

        do {
            async let namespaceDetail = kvViewModel.loadKVNamespaceDetail(namespaceID: namespace.id)
            async let keys = kvViewModel.loadKVNamespaceKeys(namespaceID: namespace.id)
            detail = try await namespaceDetail
            keyPage = try await keys
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func loadMoreKeys() async {
        guard isLoadingMoreKeys == false else { return }
        guard let cursor = keyPage?.nextCursor, cursor.isEmpty == false else { return }

        isLoadingMoreKeys = true
        defer { isLoadingMoreKeys = false }

        do {
            let nextPage = try await kvViewModel.loadKVNamespaceKeys(
                namespaceID: namespace.id,
                cursor: cursor
            )
            let existingKeys = keyPage?.keys ?? []
            keyPage = KVNamespaceKeyPage(
                keys: existingKeys + nextPage.keys,
                nextCursor: nextPage.nextCursor
            )
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
