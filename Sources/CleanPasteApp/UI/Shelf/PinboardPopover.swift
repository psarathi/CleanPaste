import SwiftUI
import CleanPasteCore

struct PinboardEditorSheet: View {
    let title: String
    @State var name: String
    @State var selectedColor: PinboardColor
    var onCancel: () -> Void
    var onSave: (String, PinboardColor) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(title)
                .font(.system(size: 14, weight: .semibold))

            TextField("Pinboard name", text: $name)
                .textFieldStyle(.roundedBorder)
                .onSubmit {
                    submit()
                }

            VStack(alignment: .leading, spacing: 6) {
                Text("Color")
                    .font(.system(size: 11.5, weight: .medium))
                    .foregroundStyle(.secondary)

                HStack(spacing: 8) {
                    ForEach(PinboardColor.allCases) { color in
                        Button {
                            selectedColor = color
                        } label: {
                            ZStack {
                                Circle()
                                    .fill(color.swiftUIColor)
                                    .frame(width: 22, height: 22)
                                if selectedColor == color {
                                    Circle()
                                        .strokeBorder(.white, lineWidth: 2)
                                        .frame(width: 18, height: 18)
                                }
                            }
                        }
                        .buttonStyle(.plain)
                        .help(color.displayName)
                    }
                }
            }

            HStack {
                Spacer()
                Button("Cancel", role: .cancel) {
                    onCancel()
                }
                .keyboardShortcut(.escape, modifiers: [])

                Button("Save") {
                    submit()
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(16)
        .frame(width: 300)
    }

    private func submit() {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        onSave(trimmed.isEmpty ? "Untitled" : trimmed, selectedColor)
    }
}
