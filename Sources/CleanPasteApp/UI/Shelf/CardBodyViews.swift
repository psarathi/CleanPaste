import SwiftUI
import AppKit
import CleanPasteCore

struct CardBodyView: View {
    let item: ClipItem
    let storage: StorageManager

    var body: some View {
        switch item.type {
        case .text:
            TextCardBody(item: item, storage: storage)
        case .link:
            LinkCardBody(item: item, storage: storage)
        case .image:
            ImageCardBody(item: item, storage: storage)
        case .color:
            ColorCardBody(item: item)
        case .file:
            FileCardBody(item: item, storage: storage)
        }
    }
}

private struct TextCardBody: View {
    let item: ClipItem
    let storage: StorageManager
    @State private var revealSecret: Bool = false

    var body: some View {
        let content = item.textContent ?? ""
        let shouldMask = item.isSensitiveSecret && !revealSecret

        ZStack(alignment: .topLeading) {
            Group {
                if item.looksLikeCode || item.isSensitiveSecret {
                    Text(previewSnippet(content))
                        .font(.system(size: 11.5, weight: .regular, design: .monospaced))
                        .foregroundStyle(.primary.opacity(0.92))
                        .lineSpacing(2.5)
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                } else {
                    Text(previewSnippet(content))
                        .font(.system(size: 12.5, weight: .regular))
                        .foregroundStyle(.primary.opacity(0.92))
                        .lineSpacing(3)
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                }
            }
            .blur(radius: shouldMask ? 7 : 0)
            .opacity(shouldMask ? 0.45 : 1.0)

            if item.isSensitiveSecret {
                VStack(spacing: 6) {
                    if shouldMask {
                        Image(systemName: "lock.shield.fill")
                            .font(.system(size: 20))
                            .foregroundStyle(.orange)
                        Text(item.secretKind ?? "Sensitive Secret")
                            .font(.system(size: 11.5, weight: .semibold))
                            .foregroundStyle(.primary)
                        Text("Masked for privacy")
                            .font(.system(size: 10.5))
                            .foregroundStyle(.secondary)
                    }
                    Button {
                        revealSecret.toggle()
                    } label: {
                        Label(
                            revealSecret ? "Hide" : "Reveal",
                            systemImage: revealSecret ? "eye.slash" : "eye"
                        )
                        .font(.system(size: 10.5, weight: .semibold))
                        .padding(.horizontal, 9)
                        .padding(.vertical, 4)
                        .background(Capsule().fill(Color(nsColor: .controlBackgroundColor).opacity(0.92)))
                        .overlay(Capsule().strokeBorder(Color.primary.opacity(0.14), lineWidth: 0.75))
                    }
                    .buttonStyle(.plain)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: shouldMask ? .center : .bottomTrailing)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .clipped()
    }

    private func previewSnippet(_ text: String) -> String {
        if text.count > 600 {
            return String(text.prefix(600))
        }
        return text
    }
}

private struct LinkCardBody: View {
    let item: ClipItem
    let storage: StorageManager

    var body: some View {
        let previewImg = item.hasLinkPreviewImage ? storage.loadLinkPreviewImage(for: item.id) : nil
        let iconImg = item.hasLinkIcon ? storage.loadLinkIcon(for: item.id) : nil
        let host = item.linkHost ?? "Link"
        let urlDisplay = item.urlString ?? item.textContent ?? ""

        VStack(alignment: .leading, spacing: 8) {
            if let previewImg {
                Image(nsImage: previewImg)
                    .resizable()
                    .scaledToFill()
                    .frame(height: 76)
                    .frame(maxWidth: .infinity)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .strokeBorder(Color.primary.opacity(0.08), lineWidth: 0.5)
                    )
            } else {
                HStack(spacing: 10) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(Color.accentColor.opacity(0.12))
                            .frame(width: 40, height: 40)
                        if let iconImg {
                            Image(nsImage: iconImg)
                                .resizable()
                                .scaledToFit()
                                .frame(width: 24, height: 24)
                                .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
                        } else {
                            Image(systemName: "globe")
                                .font(.system(size: 18, weight: .medium))
                                .foregroundStyle(Color.accentColor)
                        }
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text(host)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                        if item.linkTitle == nil {
                            Text("Web Link")
                                .font(.system(size: 11))
                                .foregroundStyle(.tertiary)
                        }
                    }
                    Spacer()
                }
                .padding(.top, 2)
            }

            if let title = item.linkTitle, !title.isEmpty {
                HStack(alignment: .top, spacing: 6) {
                    if previewImg != nil, let iconImg {
                        Image(nsImage: iconImg)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 15, height: 15)
                            .clipShape(RoundedRectangle(cornerRadius: 3))
                            .padding(.top, 1)
                    }
                    Text(title)
                        .font(.system(size: 12.5, weight: .semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(previewImg != nil ? 2 : 3)
                        .multilineTextAlignment(.leading)
                }
            }

            Spacer(minLength: 0)

            Text(urlDisplay)
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(.secondary)
                .lineLimit(previewImg != nil ? 1 : 2)
                .truncationMode(.middle)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

private struct ImageCardBody: View {
    let item: ClipItem
    let storage: StorageManager

    var body: some View {
        let thumb = storage.loadThumbnail(for: item.id)
        ZStack {
            CheckerboardBackground()
                .opacity(0.35)

            if let thumb {
                Image(nsImage: thumb)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(6)
            } else {
                VStack(spacing: 6) {
                    Image(systemName: "photo")
                        .font(.system(size: 26))
                        .foregroundStyle(.secondary)
                    Text("Image")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipped()
    }
}

private struct ColorCardBody: View {
    let item: ClipItem

    var body: some View {
        let parsed = item.parsedColor ?? ParsedColor(red: 0.25, green: 0.55, blue: 0.95)
        let swatchColor = Color(nsColor: parsed.nsColor)
        let textColor: Color = parsed.isLight ? .black.opacity(0.84) : .white.opacity(0.95)

        ZStack {
            CheckerboardBackground()
                .opacity(parsed.alpha < 0.99 ? 0.5 : 0)

            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(swatchColor)
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .strokeBorder(Color.primary.opacity(0.10), lineWidth: 0.75)
                )

            VStack(spacing: 4) {
                Text(parsed.hexString)
                    .font(.system(size: 17, weight: .bold, design: .monospaced))
                    .foregroundStyle(textColor)
                Text(parsed.rgbString)
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundStyle(textColor.opacity(0.82))
            }
            .padding(.horizontal, 10)
        }
        .padding(10)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct FileCardBody: View {
    let item: ClipItem
    let storage: StorageManager

    var body: some View {
        let firstPath = item.filePaths.first ?? ""
        let fileURL = URL(fileURLWithPath: firstPath)
        let fileName = fileURL.lastPathComponent
        let fileIcon = storage.loadFileThumbnail(for: item.id) ?? NSWorkspace.shared.icon(forFile: firstPath)

        VStack(spacing: 8) {
            Spacer(minLength: 2)
            ZStack {
                if item.filePaths.count > 1 {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color.primary.opacity(0.06))
                        .frame(width: 60, height: 60)
                        .offset(x: 6, y: -5)
                }
                Image(nsImage: fileIcon)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 64, height: 64)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .shadow(color: .black.opacity(0.12), radius: 4, y: 2)
            }

            VStack(spacing: 3) {
                Text(fileName.isEmpty ? "File" : fileName)
                    .font(.system(size: 12.5, weight: .semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)

                if item.filePaths.count > 1 {
                    Text("+ \(item.filePaths.count - 1) more item\(item.filePaths.count - 1 == 1 ? "" : "s")")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                } else {
                    Text(fileURL.deletingLastPathComponent().path.replacingOccurrences(of: NSHomeDirectory(), with: "~"))
                        .font(.system(size: 10.5))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
            }
            Spacer(minLength: 2)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct CheckerboardBackground: View {
    var squareSize: CGFloat = 10

    var body: some View {
        Canvas { context, size in
            let cols = Int(ceil(size.width / squareSize))
            let rows = Int(ceil(size.height / squareSize))
            for r in 0..<rows {
                for c in 0..<cols {
                    if (r + c).isMultiple(of: 2) {
                        let rect = CGRect(
                            x: CGFloat(c) * squareSize,
                            y: CGFloat(r) * squareSize,
                            width: squareSize,
                            height: squareSize
                        )
                        context.fill(Path(rect), with: .color(.primary.opacity(0.08)))
                    }
                }
            }
        }
    }
}
