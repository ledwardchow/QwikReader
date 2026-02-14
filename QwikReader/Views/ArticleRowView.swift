import SwiftUI

struct ArticleRowView: View {
    let article: Article
    let feedTitle: String?
    let layout: ArticleListLayout
    var isSelected: Bool = false

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        switch layout {
        case .large:
            largeLayout
        case .magazine:
            magazineLayout
        case .compact:
            compactLayout
        }
    }

    // MARK: - Selection Colors

    private var selectionBackground: Color {
        Color.accentColor
    }

    private var selectedPrimaryText: Color {
        .white
    }

    private var selectedSecondaryText: Color {
        .white.opacity(0.7)
    }

    private var selectedAccentText: Color {
        .white.opacity(0.85)
    }

    private func titleColor(isRead: Bool) -> Color {
        if isSelected { return selectedPrimaryText }
        return isRead ? .secondary : .primary
    }

    private var summaryColor: Color {
        isSelected ? selectedSecondaryText : .secondary
    }

    private var feedTitleColor: Color {
        isSelected ? selectedAccentText : .accentColor
    }

    private var captionColor: Color {
        isSelected ? selectedSecondaryText : .secondary
    }

    private var starColor: Color {
        isSelected ? .white : .yellow
    }

    private var downloadColor: Color {
        isSelected ? .white : .green
    }

    // MARK: - Large Layout

    private var largeLayout: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let imageURL = article.imageURL {
                AsyncImage(url: imageURL) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(maxWidth: .infinity)
                            .frame(height: 180)
                            .clipped()
                    case .failure:
                        EmptyView()
                    default:
                        Rectangle()
                            .fill(Color(.systemGray5))
                            .frame(height: 180)
                            .overlay {
                                ProgressView()
                            }
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(article.title)
                    .font(.headline)
                    .fontWeight(.semibold)
                    .lineLimit(3)
                    .foregroundStyle(titleColor(isRead: article.isRead))

                if !article.displaySummary.isEmpty {
                    Text(article.displaySummary)
                        .font(.subheadline)
                        .foregroundStyle(summaryColor)
                        .lineLimit(2)
                }

                HStack(spacing: 8) {
                    if let feedTitle {
                        Text(feedTitle)
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(feedTitleColor)
                    }

                    if let author = article.author {
                        Text(author)
                            .font(.caption)
                            .foregroundStyle(captionColor)
                    }

                    Spacer()

                    HStack(spacing: 4) {
                        if article.isDownloaded {
                            Image(systemName: "arrow.down.circle.fill")
                                .font(.caption2)
                                .foregroundStyle(downloadColor)
                        }
                        if article.isStarred {
                            Image(systemName: "star.fill")
                                .font(.caption2)
                                .foregroundStyle(starColor)
                        }
                        Text(article.relativeDate)
                            .font(.caption)
                            .foregroundStyle(captionColor)
                    }
                }
            }
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(isSelected ? selectionBackground : .clear)
        )
    }

    // MARK: - Magazine / Grid Layout

    private var magazineLayout: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let imageURL = article.imageURL {
                AsyncImage(url: imageURL) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(height: 120)
                            .clipped()
                    case .failure:
                        Rectangle()
                            .fill(Color(.systemGray5))
                            .frame(height: 120)
                    default:
                        Rectangle()
                            .fill(Color(.systemGray5))
                            .frame(height: 120)
                            .overlay { ProgressView() }
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }

            Text(article.title)
                .font(.subheadline)
                .fontWeight(.semibold)
                .lineLimit(2)
                .foregroundStyle(titleColor(isRead: article.isRead))

            HStack {
                if let feedTitle {
                    Text(feedTitle)
                        .font(.caption2)
                        .foregroundColor(feedTitleColor)
                }
                Spacer()
                Text(article.relativeDate)
                    .font(.caption2)
                    .foregroundStyle(captionColor)
            }
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(isSelected ? selectionBackground : Color(.secondarySystemGroupedBackground))
        )
    }

    // MARK: - Compact Layout

    private var compactLayout: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(article.title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .lineLimit(2)
                    .foregroundStyle(titleColor(isRead: article.isRead))

                HStack(spacing: 6) {
                    if !article.isRead {
                        Circle()
                            .fill(isSelected ? Color.white : Color.accentColor)
                            .frame(width: 6, height: 6)
                    }

                    if let feedTitle {
                        Text(feedTitle)
                            .font(.caption)
                            .foregroundColor(feedTitleColor)
                    }

                    Text(article.relativeDate)
                        .font(.caption)
                        .foregroundStyle(captionColor)

                    if article.isStarred {
                        Image(systemName: "star.fill")
                            .font(.caption2)
                            .foregroundStyle(starColor)
                    }
                    if article.isDownloaded {
                        Image(systemName: "arrow.down.circle.fill")
                            .font(.caption2)
                            .foregroundStyle(downloadColor)
                    }
                }
            }

            Spacer()

            if let imageURL = article.imageURL {
                AsyncImage(url: imageURL) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 64, height: 64)
                            .clipped()
                    default:
                        Rectangle()
                            .fill(Color(.systemGray5))
                            .frame(width: 64, height: 64)
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(isSelected ? selectionBackground : .clear)
        )
    }
}

#Preview("Large") {
    ArticleRowView(
        article: PreviewFixtures.article,
        feedTitle: PreviewFixtures.feed.title,
        layout: .large
    )
    .padding()
}

#Preview("Magazine") {
    ArticleRowView(
        article: PreviewFixtures.article,
        feedTitle: PreviewFixtures.feed.title,
        layout: .magazine
    )
    .padding()
}

#Preview("Compact") {
    ArticleRowView(
        article: PreviewFixtures.article,
        feedTitle: PreviewFixtures.feed.title,
        layout: .compact
    )
    .padding()
}
