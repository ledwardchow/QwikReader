import SwiftUI

struct ArticleRowView: View {
    let article: Article
    let feedTitle: String?
    let layout: ArticleListLayout

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

    // MARK: - Large Layout (like Newsify default)

    private var largeLayout: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let imageURL = article.imageURL {
                AsyncImage(url: imageURL) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
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
                    .foregroundStyle(article.isRead ? .secondary : .primary)

                if !article.displaySummary.isEmpty {
                    Text(article.displaySummary)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }

                HStack(spacing: 8) {
                    if let feedTitle {
                        Text(feedTitle)
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(.accentColor)
                    }

                    if let author = article.author {
                        Text(author)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    HStack(spacing: 4) {
                        if article.isDownloaded {
                            Image(systemName: "arrow.down.circle.fill")
                                .font(.caption2)
                                .foregroundStyle(.green)
                        }
                        if article.isStarred {
                            Image(systemName: "star.fill")
                                .font(.caption2)
                                .foregroundStyle(.yellow)
                        }
                        Text(article.relativeDate)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .padding(.vertical, 4)
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
                .foregroundStyle(article.isRead ? .secondary : .primary)

            HStack {
                if let feedTitle {
                    Text(feedTitle)
                        .font(.caption2)
                        .foregroundColor(.accentColor)
                }
                Spacer()
                Text(article.relativeDate)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(8)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Compact Layout

    private var compactLayout: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(article.title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .lineLimit(2)
                    .foregroundStyle(article.isRead ? .secondary : .primary)

                HStack(spacing: 6) {
                    if !article.isRead {
                        Circle()
                            .fill(Color.accentColor)
                            .frame(width: 6, height: 6)
                    }

                    if let feedTitle {
                        Text(feedTitle)
                            .font(.caption)
                            .foregroundColor(.accentColor)
                    }

                    Text(article.relativeDate)
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    if article.isStarred {
                        Image(systemName: "star.fill")
                            .font(.caption2)
                            .foregroundStyle(.yellow)
                    }
                    if article.isDownloaded {
                        Image(systemName: "arrow.down.circle.fill")
                            .font(.caption2)
                            .foregroundStyle(.green)
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
        .padding(.vertical, 4)
    }
}
