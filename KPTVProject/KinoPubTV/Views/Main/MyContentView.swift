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
    
    // Build sections list dynamically including bookmark folders
    var sections: [MyContentSection] {
        var result: [MyContentSection] = [.watching, .bookmarks]
        // Add individual bookmark folders
        for folder in viewModel.bookmarkFolders {
            result.append(.folder(folder))
        }
        result.append(.history)
        return result
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Top Menu
                TopMenuView(
                    sections: sections,
                    selectedSection: $selectedSection
                )
                
                // Main content
                contentView
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .navigationDestination(for: Item.self) { item in
                DetailView(itemID: item.id)
            }
            .task {
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

// MARK: - Top Menu View

struct TopMenuView: View {
    let sections: [MyContentSection]
    @Binding var selectedSection: MyContentSection
    
    // Split sections into main and folders
    var mainSections: [MyContentSection] {
        sections.filter { !$0.isFolder }
    }
    
    var folderSections: [MyContentSection] {
        sections.filter { $0.isFolder }
    }
    
    var body: some View {
        VStack(spacing: 20) {
            // Main row: Watching, Bookmarks, History, Library
            HStack(spacing: 12) {
                ForEach(mainSections) { section in
                    TopMenuItem(
                        section: section,
                        isSelected: selectedSection == section
                    ) {
                        selectedSection = section
                    }
                }
            }
            
            // Folders row (if any)
            if !folderSections.isEmpty {
                HStack(spacing: 12) {
                    ForEach(folderSections) { section in
                        TopMenuItem(
                            section: section,
                            isSelected: selectedSection == section
                        ) {
                            selectedSection = section
                        }
                    }
                }
            }
        }
        .padding(.vertical, 30)
        .frame(maxWidth: .infinity)
        .focusSection()
    }
}

// MARK: - Top Menu Item

struct TopMenuItem: View {
    let section: MyContentSection
    let isSelected: Bool
    let action: () -> Void
    
    @FocusState private var isFocused: Bool
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: section.icon)
                    .font(.system(size: 20))
                
                Text(section.title)
                    .font(.callout)
                    .fontWeight(isSelected ? .semibold : .regular)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 14)
            .foregroundColor(isFocused ? .black : (isSelected ? .white : .gray))
        }
        .buttonStyle(.card)
        .focused($isFocused)
    }
}

// MARK: - Watching Content View

struct WatchingContentView: View {
    @State private var viewModel = MyContentViewModel()
    
    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 50) {
                // Unwatched Serials
                if !viewModel.unwatchedSerials.isEmpty {
                    ContentGridSection(
                        title: "Сериалы (\(viewModel.unwatchedSerials.count))",
                        items: viewModel.unwatchedSerials
                    )
                }
                
                // Unwatched Movies
                if !viewModel.unwatchedMovies.isEmpty {
                    ContentGridSection(
                        title: "Фильмы (\(viewModel.unwatchedMovies.count))",
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

// MARK: - Content Grid Section

struct ContentGridSection: View {
    let title: String
    let items: [Item]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 30) {
            Text(title)
                .font(.title2)
                .fontWeight(.bold)
                .padding(.horizontal, 50)
            
            LazyVGrid(
                columns: Array(repeating: GridItem(.flexible(), spacing: 40), count: 5),
                spacing: 50
            ) {
                ForEach(items) { item in
                    VStack(alignment: .leading, spacing: 16) {
                        NavigationLink(value: item) {
                            PosterCard(item: item)
                        }
                        .buttonStyle(.card)
                        
                        ItemMetadata(item: item, width: 250)
                    }
                }
            }
            .padding(.horizontal, 50)
        }
    }
}

// MARK: - Bookmarks Content View

struct BookmarksContentView: View {
    @State private var viewModel = MyContentViewModel()
    @State private var showingCreateFolder = false
    @State private var newFolderName = ""
    @State private var selectedFolder: BookmarkFolder?
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 30) {
                Text("Мои папки")
                    .font(.title2)
                    .fontWeight(.bold)
                    .padding(.horizontal, 50)
                    .padding(.top, 30)
                
                // Folders Grid with Create button as first tile
                LazyVGrid(
                    columns: Array(repeating: GridItem(.flexible(), spacing: 40), count: 5),
                    spacing: 40
                ) {
                    // Create new folder tile
                    CreateFolderCard {
                        showingCreateFolder = true
                    }
                    
                    // Existing folders
                    ForEach(viewModel.bookmarkFolders) { folder in
                        FolderCard(
                            folder: folder,
                            itemCount: viewModel.bookmarkItems[folder.id]?.count ?? 0
                        ) {
                            selectedFolder = folder
                        }
                    }
                }
                .padding(.horizontal, 50)
                .padding(.bottom, 50)
            }
        }
        .overlay {
            if viewModel.isLoading && viewModel.bookmarkFolders.isEmpty {
                ProgressView("Загрузка...")
            }
        }
        .alert("Создать папку", isPresented: $showingCreateFolder) {
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
        .navigationDestination(isPresented: Binding(
            get: { selectedFolder != nil },
            set: { if !$0 { selectedFolder = nil } }
        )) {
            if let folder = selectedFolder {
                FolderDetailView(folder: folder)
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

// MARK: - Create Folder Card

struct CreateFolderCard: View {
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 16) {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 50))
                    .foregroundStyle(.blue)
                
                Text("Создать папку")
                    .font(.headline)
                    .foregroundStyle(.primary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .frame(height: 200)
        }
        .buttonStyle(.card)
    }
}

// MARK: - Folder Card

struct FolderCard: View {
    let folder: BookmarkFolder
    let itemCount: Int
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .top) {
                    Image(systemName: "folder.fill")
                        .font(.system(size: 50))
                        .foregroundStyle(.blue)
                    
                    Spacer()
                    
                    if itemCount > 0 {
                        Text("\(itemCount)")
                            .font(.title3)
                            .fontWeight(.semibold)
                            .foregroundStyle(.secondary)
                    }
                }
                
                Spacer()
                
                Text(folder.title)
                    .font(.headline)
                    .lineLimit(2)
                    .foregroundStyle(.primary)
            }
            .padding(24)
            .frame(maxWidth: .infinity, alignment: .leading)
            .frame(height: 200)
        }
        .buttonStyle(.card)
    }
}

// MARK: - Folder Detail View

struct FolderDetailView: View {
    let folder: BookmarkFolder
    @State private var viewModel = MyContentViewModel()
    
    var items: [Item] {
        viewModel.bookmarkItems[folder.id] ?? []
    }
    
    var body: some View {
        ScrollView {
            if !items.isEmpty {
                LazyVGrid(
                    columns: Array(repeating: GridItem(.flexible(), spacing: 40), count: 5),
                    spacing: 50
                ) {
                    ForEach(items) { item in
                        VStack(alignment: .leading, spacing: 24) {
                            NavigationLink(value: item) {
                                PosterCard(item: item)
                            }
                            .buttonStyle(.card)
                            
                            ItemMetadata(item: item, width: 250)
                        }
                    }
                }
                .padding(50)
            } else {
                ContentUnavailableView(
                    "Папка пуста",
                    systemImage: "folder",
                    description: Text("Добавьте контент в эту папку")
                )
            }
        }
        .navigationTitle(folder.title)
        .navigationDestination(for: Item.self) { item in
            DetailView(itemID: item.id)
        }
        .task {
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
                        VStack(alignment: .leading, spacing: 16) {
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
                LazyHStack(spacing: 40) {
                    ForEach(items) { historyItem in
                        VStack(alignment: .leading, spacing: 16) {
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
                .padding(.vertical, 40)
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
            if historyItem.item.isSerial, let season = historyItem.media.snumber {
                Text("S\(season)E\(historyItem.media.number ?? 0)")
                    .font(.system(size: 22, weight: .bold))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color.red)
                    .foregroundColor(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .padding(12)
            }
        }
    }
}

#Preview {
    MyContentView()
}
