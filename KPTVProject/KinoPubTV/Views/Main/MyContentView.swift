//
//  MyContentView.swift
//  KinoPubTV
//

import SwiftUI

// MARK: - My Content Sections

enum MyContentSection: Hashable, Identifiable {
    case watching
    case bookmarks
    case history
    case library
    case folder(BookmarkFolder)
    
    var id: String {
        switch self {
        case .watching: return "watching"
        case .bookmarks: return "bookmarks"
        case .history: return "history"
        case .library: return "library"
        case .folder(let folder): return "folder-\(folder.id)"
        }
    }
    
    var title: String {
        switch self {
        case .watching: return "Смотрю"
        case .bookmarks: return "Закладки"
        case .history: return "История"
        case .library: return "Библиотека"
        case .folder(let folder): return folder.title
        }
    }
    
    var icon: String {
        switch self {
        case .watching: return "play.circle"
        case .bookmarks: return "bookmark"
        case .history: return "clock"
        case .library: return "books.vertical"
        case .folder: return "folder"
        }
    }
    
    var isFolder: Bool {
        if case .folder = self { return true }
        return false
    }
}

struct MyContentView: View {
    @State private var selectedSection: MyContentSection = .watching
    @State private var viewModel = MyContentViewModel()
    @Namespace private var animation
    
    // Build sections list dynamically including bookmark folders
    var sections: [MyContentSection] {
        var result: [MyContentSection] = [.watching, .bookmarks]
        // Add individual bookmark folders
        for folder in viewModel.bookmarkFolders {
            result.append(.folder(folder))
        }
        result.append(contentsOf: [.history, .library])
        return result
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Top Tab Bar
                TabBarView(
                    sections: sections,
                    selectedSection: $selectedSection,
                    namespace: animation
                )
                .padding(.top, 60)
                
                // Main content
                contentView
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .navigationDestination(for: Item.self) { item in
                DetailView(itemID: item.id)
            }
            .task {
                // Load bookmark folders for tab bar
                await viewModel.loadBookmarks()
            }
        }
    }
    
    @ViewBuilder
    private var contentView: some View {
        switch selectedSection {
        case .watching:
            WatchingContentView()
        case .bookmarks:
            BookmarksContentView()
        case .history:
            HistoryContentView()
        case .library:
            LibraryView()
        case .folder(let folder):
            FolderContentView(folder: folder)
        }
    }
}

// MARK: - Tab Bar View

struct TabBarView: View {
    let sections: [MyContentSection]
    @Binding var selectedSection: MyContentSection
    var namespace: Namespace.ID
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 50) {
                ForEach(sections) { section in
                    TabButton(
                        title: section.title,
                        icon: section.icon,
                        isSelected: selectedSection == section,
                        namespace: namespace
                    ) {
                        withAnimation(.smooth(duration: 0.25)) {
                            selectedSection = section
                        }
                    }
                }
            }
            .padding(.horizontal, 90)
            .padding(.vertical, 30)
            .focusSection()
        }
        .frame(height: 160)
    }
}

// MARK: - Tab Button

struct TabButton: View {
    let title: String
    let icon: String
    let isSelected: Bool
    var namespace: Namespace.ID
    let action: () -> Void
    
    @FocusState private var isFocused: Bool
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 32, weight: isSelected ? .semibold : .regular))
                    .foregroundStyle(isFocused ? Color.primary : (isSelected ? Color.white : Color.secondary))
                    .frame(height: 40)
                
                Text(title)
                    .font(.system(size: 24, weight: isFocused ? .semibold : .regular))
                    .foregroundStyle(isFocused ? Color.primary : (isSelected ? Color.white : Color.secondary))
                    .lineLimit(1)
            }
            .frame(minWidth: 100)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background {
                if isFocused {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(.regularMaterial)
                } else if isSelected {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(.white.opacity(0.1))
                }
            }
            .scaleEffect(isFocused ? 1.1 : 1.0)
            .shadow(color: .black.opacity(isFocused ? 0.3 : 0), radius: 20, y: 10)
        }
        .buttonStyle(.plain)
        .focused($isFocused)
        .animation(.smooth(duration: 0.2), value: isFocused)
    }
}

// MARK: - Watching Content View

struct WatchingContentView: View {
    @State private var viewModel = MyContentViewModel()
    
    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 40) {
                // Unwatched Serials
                if !viewModel.unwatchedSerials.isEmpty {
                    ContentShelf(
                        title: RussianPlural.series(viewModel.unwatchedSerials.count),
                        items: viewModel.unwatchedSerials
                    )
                }
                
                // Unwatched Movies
                if !viewModel.unwatchedMovies.isEmpty {
                    ContentShelf(
                        title: RussianPlural.movies(viewModel.unwatchedMovies.count),
                        items: viewModel.unwatchedMovies
                    )
                }
                
                if viewModel.unwatchedSerials.isEmpty && viewModel.unwatchedMovies.isEmpty && !viewModel.isLoading {
                    ContentUnavailableView(
                        "Ничего не смотрите",
                        systemImage: "play.circle",
                        description: Text("Начните смотреть фильмы и сериалы, чтобы они появились здесь")
                    )
                    .frame(maxWidth: .infinity, minHeight: 400)
                }
            }
            .padding(.vertical, 50)
        }
        .overlay {
            if viewModel.isLoading && viewModel.unwatchedSerials.isEmpty && viewModel.unwatchedMovies.isEmpty {
                ProgressView("Загрузка...")
            }
        }
        .task {
            await viewModel.loadWatching()
        }
        .refreshable {
            await viewModel.loadWatching()
        }
    }
}

// MARK: - Bookmarks Content View

struct BookmarksContentView: View {
    @State private var viewModel = MyContentViewModel()
    @State private var showingCreateFolder = false
    @State private var newFolderName = ""
    
    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 40) {
                // Create folder button
                HStack {
                    Spacer()
                    Button {
                        showingCreateFolder = true
                    } label: {
                        Label("Создать папку", systemImage: "plus")
                    }
                }
                .padding(.horizontal, 50)
                
                if !viewModel.bookmarkFolders.isEmpty {
                    ForEach(viewModel.bookmarkFolders) { folder in
                        if let items = viewModel.bookmarkItems[folder.id], !items.isEmpty {
                            ContentShelf(
                                title: "\(folder.title) (\(folder.count ?? items.count))",
                                items: items
                            )
                        } else {
                            // Show empty folder
                            VStack(alignment: .leading, spacing: 20) {
                                Text(folder.title)
                                    .font(.title2)
                                    .fontWeight(.bold)
                                    .padding(.horizontal, 50)
                                
                                Text("Пусто")
                                    .foregroundColor(.secondary)
                                    .padding(.horizontal, 50)
                            }
                        }
                    }
                }
                
                if viewModel.bookmarkFolders.isEmpty && !viewModel.isLoading {
                    ContentUnavailableView(
                        "Нет закладок",
                        systemImage: "bookmark",
                        description: Text("Добавляйте фильмы и сериалы в закладки для быстрого доступа")
                    )
                    .frame(maxWidth: .infinity, minHeight: 400)
                }
            }
            .padding(.vertical, 50)
        }
        .overlay {
            if viewModel.isLoading && viewModel.bookmarkFolders.isEmpty {
                ProgressView("Загрузка...")
            }
        }
        .alert("Создать закладку", isPresented: $showingCreateFolder) {
            TextField("Название", text: $newFolderName)
            Button("Создать") {
                Task {
                    await viewModel.createFolder(title: newFolderName)
                    newFolderName = ""
                }
            }
            Button("Отмена", role: .cancel) {
                newFolderName = ""
            }
        }
        .task {
            await viewModel.loadBookmarks()
        }
        .refreshable {
            await viewModel.loadBookmarks()
        }
    }
}

// MARK: - Folder Content View

struct FolderContentView: View {
    let folder: BookmarkFolder
    @State private var items: [Item] = []
    @State private var isLoading = false
    
    var body: some View {
        ScrollView {
            if !items.isEmpty {
                LazyVGrid(
                    columns: Array(repeating: GridItem(.flexible(), spacing: 40), count: 5),
                    spacing: 50
                ) {
                    ForEach(items) { item in
                        VStack(alignment: .leading, spacing: 12) {
                            NavigationLink(value: item) {
                                PosterCard(item: item)
                            }
                            .buttonStyle(.card)
                            
                            ItemMetadata(item: item, width: 250)
                        }
                    }
                }
                .padding(50)
            } else if !isLoading {
                ContentUnavailableView(
                    "Папка пуста",
                    systemImage: "folder",
                    description: Text("Добавьте контент в эту папку")
                )
                .frame(maxWidth: .infinity, minHeight: 400)
            }
        }
        .overlay {
            if isLoading {
                ProgressView("Загрузка...")
            }
        }
        .task {
            await loadItems()
        }
    }
    
    private func loadItems() async {
        isLoading = true
        do {
            let token = try await AuthService.shared.getValidToken()
            let response = try await ContentService.shared.getBookmarkItems(
                folderID: folder.id,
                accessToken: token
            )
            items = response.items
        } catch {
            print("Error loading folder items: \(error)")
        }
        isLoading = false
    }
}

// MARK: - History Content View

struct HistoryContentView: View {
    @State private var viewModel = MyContentViewModel()
    
    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 40) {
                if !viewModel.history.isEmpty {
                    HistoryShelf(title: "Недавно просмотренное", items: viewModel.history) { itemID in
                        Task {
                            await viewModel.clearHistory(itemID: itemID)
                        }
                    }
                }
                
                if viewModel.history.isEmpty && !viewModel.isLoading {
                    ContentUnavailableView(
                        "История пуста",
                        systemImage: "clock",
                        description: Text("Здесь будет отображаться история просмотров")
                    )
                    .frame(maxWidth: .infinity, minHeight: 400)
                }
            }
            .padding(.vertical, 50)
        }
        .overlay {
            if viewModel.isLoading && viewModel.history.isEmpty {
                ProgressView("Загрузка...")
            }
        }
        .task {
            await viewModel.loadHistory()
        }
        .refreshable {
            await viewModel.loadHistory()
        }
    }
}

// MARK: - History Shelf

struct HistoryShelf: View {
    let title: String
    let items: [HistoryItem]
    let onDelete: (Int) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text(title)
                .font(.title2)
                .fontWeight(.bold)
                .padding(.horizontal, 50)
            
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 30) {
                    ForEach(items) { historyItem in
                        VStack(alignment: .leading, spacing: 12) {
                            NavigationLink(value: historyItem.item) {
                                HistoryCard(historyItem: historyItem)
                            }
                            .buttonStyle(.card)
                            .contextMenu {
                                Button(role: .destructive) {
                                    onDelete(historyItem.item.id)
                                } label: {
                                    Label("Удалить из истории", systemImage: "trash")
                                }
                            }
                            
                            // Metadata below card
                            VStack(alignment: .leading, spacing: 4) {
                                Text(historyItem.item.displayTitle)
                                    .font(.caption2)
                                    .fontWeight(.medium)
                                    .lineLimit(1)
                                    .foregroundColor(.primary)
                                
                                HStack(spacing: 8) {
                                    if let year = historyItem.item.year {
                                        Text(String(year))
                                            .font(.caption2)
                                            .foregroundColor(.secondary)
                                    }
                                    
                                    Text(formatDate(historyItem.lastSeen))
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }
                            }
                            .frame(width: 250, alignment: .leading)
                        }
                    }
                }
                .padding(.horizontal, 50)
                .padding(.bottom, 30)
                .focusSection()
            }
        }
    }
    
    private func formatDate(_ timestamp: Int) -> String {
        let date = Date(timeIntervalSince1970: TimeInterval(timestamp))
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        formatter.locale = Locale(identifier: "ru_RU")
        return formatter.string(from: date)
    }
}

struct HistoryCard: View {
    let historyItem: HistoryItem
    
    var body: some View {
        ZStack(alignment: .topTrailing) {
            // Poster image
            AsyncImage(url: URL.secure(string: historyItem.item.posters?.medium)) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } placeholder: {
                Rectangle()
                    .fill(Color(white: 0.15))
            }
            .frame(width: 250, height: 376)
            .clipped()
            
            // Top-right badge for episode info
            if historyItem.item.isSerial, let media = historyItem.media.snumber {
                Text("S\(media)E\(historyItem.media.number ?? 0)")
                    .font(.system(size: 12, weight: .bold))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.red)
                    .foregroundColor(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                    .padding(10)
            }
        }
    }
}

#Preview {
    MyContentView()
}
