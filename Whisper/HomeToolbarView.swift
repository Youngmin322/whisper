import SwiftUI

struct HomeToolbarView: View {
    let day: JournalDay
    let onOpenSettings: () -> Void
    let onOpenCollection: () -> Void

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 0) {
                settingsButton.frame(width: 76, alignment: .leading)
                Spacer(minLength: 8)
                dateLabel.fixedSize(horizontal: true, vertical: false)
                Spacer(minLength: 8)
                collectionButton.frame(width: 76, alignment: .trailing)
            }
            VStack(spacing: WhisperSpacing.small) {
                HStack { settingsButton; Spacer(); collectionButton }
                dateLabel
            }
        }
        .padding(.horizontal, 21)
        .padding(.top, 8)
        .padding(.bottom, 12)
    }

    private var settingsButton: some View {
        Button(action: onOpenSettings) {
            Image(systemName: "gearshape")
                .resizable()
                .scaledToFit()
                .frame(width: 22, height: 22)
                .frame(width: 48, height: 48)
                .contentShape(Rectangle())
        }
        .foregroundStyle(Color.whisperTextSecondary)
        .accessibilityLabel("설정")
        .accessibilityIdentifier("home.settingsButton")
    }

    private var collectionButton: some View {
        Button(action: onOpenCollection) {
            HStack(spacing: 4) {
                Image("BottleLineIcon")
                    .resizable().aspectRatio(contentMode: .fit)
                    .frame(width: 19, height: 23)
                    .accessibilityHidden(true)
                Text("보관함").font(.whisperControl).lineLimit(1).minimumScaleFactor(0.85)
            }
            .frame(minWidth: 76, minHeight: 48)
            .contentShape(Rectangle())
        }
        .foregroundStyle(Color.whisperTextSecondary)
        .accessibilityLabel("보관함")
        .accessibilityIdentifier("home.collectionButton")
    }

    private var dateLabel: some View {
        Text(day.shortDescription)
            .font(.whisperHandwriting(27, bold: true))
            .foregroundStyle(Color.whisperTextPrimary)
            .lineLimit(1)
            .minimumScaleFactor(0.75)
            .padding(.horizontal, 6)
            .background(alignment: .bottom) {
                Capsule().fill(Color.whisperSurfaceHighlight).frame(height: 7).offset(y: 2)
            }
            .accessibilityIdentifier("home.dateLabel")
    }
}
