import SwiftUI

struct DataServicesView: View {
    @Environment(DataServicesOverviewViewModel.self) private var dataServicesOverviewViewModel

    var body: some View {
        List {
            DataServicesAccountContextSection(accountID: dataServicesOverviewViewModel.resolvedAccountID)

            Section("Storage") {
                DataServiceProductLink(
                    product: .kv,
                    subtitle: "Namespaces and key previews. Open this list to load KV only."
                )
                DataServiceProductLink(
                    product: .r2,
                    subtitle: "Buckets, regions, and object lock metadata."
                )
                DataServiceProductLink(
                    product: .d1,
                    subtitle: "Databases, regions, and storage usage."
                )
            }

            Section("Pipelines & Specialized Data") {
                DataServiceProductLink(
                    product: .queues,
                    subtitle: "Queue topology, producers, and consumers."
                )
                DataServiceProductLink(
                    product: .vectorize,
                    subtitle: "Vector indexes and metadata schema."
                )
                DataServiceProductLink(
                    product: .hyperdrive,
                    subtitle: "Origin acceleration configs and caching behavior."
                )
            }
        }
        .navigationTitle("Data Services")
        .navigationDestination(for: AccountDataProduct.self) { product in
            switch product {
            case .kv:
                KVCatalogView()
            case .r2:
                R2CatalogView()
            case .d1:
                D1CatalogView()
            case .queues:
                QueuesCatalogView()
            case .vectorize:
                VectorizeCatalogView()
            case .hyperdrive:
                HyperdriveCatalogView()
            }
        }
    }
}

struct KVCatalogView: View {
    @Environment(KVViewModel.self) private var kvViewModel

    var body: some View {
        List {
            DataServiceIntroSection(text: "Namespaces and key previews.")

            if kvViewModel.isRefreshingKV && kvViewModel.kvNamespaces.isEmpty {
                Section {
                    ProgressView("Loading KV")
                }
            } else if kvViewModel.kvNamespaces.isEmpty {
                DataServiceStatusSection(message: kvViewModel.kvStatusMessage ?? "No KV namespaces found.")
            } else {
                Section("Namespaces") {
                    ForEach(kvViewModel.kvNamespaces) { namespace in
                        NavigationLink(value: namespace) {
                            KVNamespaceCatalogRow(namespace: namespace)
                        }
                    }
                }
            }
        }
        .navigationTitle("KV")
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(for: KVNamespace.self) { namespace in
            KVNamespaceDetailView(namespace: namespace)
        }
        .task(id: kvViewModel.resolvedAccountID) {
            guard let accountID = kvViewModel.resolvedAccountID else { return }
            guard kvViewModel.isLoaded(for: accountID) == false else { return }
            await kvViewModel.refreshKVCatalog()
        }
        .refreshable {
            await kvViewModel.refreshKVCatalog(force: true)
        }
    }
}

struct R2CatalogView: View {
    @Environment(R2ViewModel.self) private var r2ViewModel

    var body: some View {
        List {
            DataServiceIntroSection(text: "Buckets, regions, and object lock metadata.")

            if r2ViewModel.isRefreshingR2 && r2ViewModel.r2Buckets.isEmpty {
                Section {
                    ProgressView("Loading R2")
                }
            } else if r2ViewModel.r2Buckets.isEmpty {
                DataServiceStatusSection(message: r2ViewModel.r2StatusMessage ?? "No R2 buckets found.")
            } else {
                Section("Buckets") {
                    ForEach(r2ViewModel.r2Buckets) { bucket in
                        NavigationLink(value: bucket) {
                            R2BucketCatalogRow(bucket: bucket)
                        }
                    }
                }
            }
        }
        .navigationTitle("R2")
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(for: R2Bucket.self) { bucket in
            R2BucketDetailView(bucket: bucket)
        }
        .task(id: r2ViewModel.resolvedAccountID) {
            guard let accountID = r2ViewModel.resolvedAccountID else { return }
            guard r2ViewModel.isLoaded(for: accountID) == false else { return }
            await r2ViewModel.refreshR2Catalog()
        }
        .refreshable {
            await r2ViewModel.refreshR2Catalog(force: true)
        }
    }
}

struct D1CatalogView: View {
    @Environment(D1ViewModel.self) private var d1ViewModel

    var body: some View {
        List {
            DataServiceIntroSection(text: "Databases, regions, and storage usage.")

            if d1ViewModel.isRefreshingD1 && d1ViewModel.d1Databases.isEmpty {
                Section {
                    ProgressView("Loading D1")
                }
            } else if d1ViewModel.d1Databases.isEmpty {
                DataServiceStatusSection(message: d1ViewModel.d1StatusMessage ?? "No D1 databases found.")
            } else {
                Section("Databases") {
                    ForEach(d1ViewModel.d1Databases) { database in
                        NavigationLink(value: database) {
                            D1DatabaseCatalogRow(database: database)
                        }
                    }
                }
            }
        }
        .navigationTitle("D1")
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(for: D1Database.self) { database in
            D1DatabaseDetailView(database: database)
        }
        .task(id: d1ViewModel.resolvedAccountID) {
            guard let accountID = d1ViewModel.resolvedAccountID else { return }
            guard d1ViewModel.isLoaded(for: accountID) == false else { return }
            await d1ViewModel.refreshD1Catalog()
        }
        .refreshable {
            await d1ViewModel.refreshD1Catalog(force: true)
        }
    }
}

struct QueuesCatalogView: View {
    @Environment(QueuesViewModel.self) private var queuesViewModel

    var body: some View {
        List {
            DataServiceIntroSection(text: "Queue topology, producers, and consumers.")

            if queuesViewModel.isRefreshingQueues && queuesViewModel.queues.isEmpty {
                Section {
                    ProgressView("Loading Queues")
                }
            } else if queuesViewModel.queues.isEmpty {
                DataServiceStatusSection(message: queuesViewModel.queuesStatusMessage ?? "No Queues found.")
            } else {
                Section("Queues") {
                    ForEach(queuesViewModel.queues) { queue in
                        NavigationLink(value: queue) {
                            QueueCatalogRow(queue: queue)
                        }
                    }
                }
            }
        }
        .navigationTitle("Queues")
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(for: QueueSummary.self) { queue in
            QueueDetailView(queue: queue)
        }
        .task(id: queuesViewModel.resolvedAccountID) {
            guard let accountID = queuesViewModel.resolvedAccountID else { return }
            guard queuesViewModel.isLoaded(for: accountID) == false else { return }
            await queuesViewModel.refreshQueuesCatalog()
        }
        .refreshable {
            await queuesViewModel.refreshQueuesCatalog(force: true)
        }
    }
}

struct VectorizeCatalogView: View {
    @Environment(VectorizeViewModel.self) private var vectorizeViewModel

    var body: some View {
        List {
            DataServiceIntroSection(text: "Vector indexes and metadata schema.")

            if vectorizeViewModel.isRefreshingVectorize && vectorizeViewModel.vectorizeIndexes.isEmpty {
                Section {
                    ProgressView("Loading Vectorize")
                }
            } else if vectorizeViewModel.vectorizeIndexes.isEmpty {
                DataServiceStatusSection(message: vectorizeViewModel.vectorizeStatusMessage ?? "No Vectorize indexes found.")
            } else {
                Section("Indexes") {
                    ForEach(vectorizeViewModel.vectorizeIndexes) { index in
                        NavigationLink(value: index) {
                            VectorizeIndexCatalogRow(index: index)
                        }
                    }
                }
            }
        }
        .navigationTitle("Vectorize")
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(for: VectorizeIndex.self) { index in
            VectorizeIndexDetailView(index: index)
        }
        .task(id: vectorizeViewModel.resolvedAccountID) {
            guard let accountID = vectorizeViewModel.resolvedAccountID else { return }
            guard vectorizeViewModel.isLoaded(for: accountID) == false else { return }
            await vectorizeViewModel.refreshVectorizeCatalog()
        }
        .refreshable {
            await vectorizeViewModel.refreshVectorizeCatalog(force: true)
        }
    }
}

struct HyperdriveCatalogView: View {
    @Environment(HyperdriveViewModel.self) private var hyperdriveViewModel

    var body: some View {
        List {
            DataServiceIntroSection(text: "Origin acceleration configs and caching behavior.")

            if hyperdriveViewModel.isRefreshingHyperdrive && hyperdriveViewModel.hyperdriveConfigs.isEmpty {
                Section {
                    ProgressView("Loading Hyperdrive")
                }
            } else if hyperdriveViewModel.hyperdriveConfigs.isEmpty {
                DataServiceStatusSection(message: hyperdriveViewModel.hyperdriveStatusMessage ?? "No Hyperdrive configs found.")
            } else {
                Section("Configurations") {
                    ForEach(hyperdriveViewModel.hyperdriveConfigs) { config in
                        NavigationLink(value: config) {
                            HyperdriveConfigCatalogRow(config: config)
                        }
                    }
                }
            }
        }
        .navigationTitle("Hyperdrive")
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(for: HyperdriveConfig.self) { config in
            HyperdriveConfigDetailView(config: config)
        }
        .task(id: hyperdriveViewModel.resolvedAccountID) {
            guard let accountID = hyperdriveViewModel.resolvedAccountID else { return }
            guard hyperdriveViewModel.isLoaded(for: accountID) == false else { return }
            await hyperdriveViewModel.refreshHyperdriveCatalog()
        }
        .refreshable {
            await hyperdriveViewModel.refreshHyperdriveCatalog(force: true)
        }
    }
}
