//
//  ContentView.swift
//  Ember
//

import SwiftUI
import EmberDesignSystem
import UserNotifications
import UIKit

struct ContentView: View {
    @AppStorage("hasSeenWelcome") private var hasSeenWelcome = false
    @State private var recordStore = RecordStore()

    var body: some View {
        Group {
            if hasSeenWelcome {
                MainTabView(recordStore: recordStore)
            } else {
                WelcomeView { hasSeenWelcome = true }
            }
        }
        .tint(.emberAccent)
    }
}

private struct MainTabView: View {
    let recordStore: RecordStore
    @Environment(\.scenePhase) private var scenePhase
    @State private var selectedTab = MainTab.home
    @State private var homePath = NavigationPath()

    var body: some View {
        TabView(selection: $selectedTab) {
            Tab("기록", systemImage: "flame.fill", value: MainTab.home) {
                NavigationStack(path: $homePath) {
                    HomeView(recordStore: recordStore)
                        .navigationDestination(for: UUID.self) { recordID in
                            NotificationRecordDestination(
                                recordID: recordID,
                                recordStore: recordStore
                            )
                        }
                }
            }
            Tab("보관함", systemImage: "archivebox.fill", value: MainTab.collection) {
                NavigationStack {
                    CollectionView(recordStore: recordStore)
                }
            }
            Tab("설정", systemImage: "gearshape", value: MainTab.settings) {
                NavigationStack {
                    SettingsView()
                }
            }
        }
        .task(consumePendingNotificationRoute)
        .onReceive(NotificationCenter.default.publisher(for: EmberNotificationRoute.didSelectRecord)) { _ in
            consumePendingNotificationRoute()
        }
        .onChange(of: scenePhase) { _, newValue in
            guard newValue == .active else { return }
            consumePendingNotificationRoute()
        }
    }

    private func consumePendingNotificationRoute() {
        guard let recordID = EmberNotificationRoute.consumePendingRecordID() else { return }
        selectedTab = .home
        homePath = NavigationPath()
        homePath.append(recordID)
    }
}

private enum MainTab: Hashable {
    case home
    case collection
    case settings
}

private struct NotificationRecordDestination: View {
    let recordID: UUID
    let recordStore: RecordStore

    var body: some View {
        if let record = recordStore.record(withID: recordID) {
            RecordDetailView(record: record, recordStore: recordStore)
        } else {
            ContentUnavailableView(
                "기록을 찾을 수 없어요",
                systemImage: "flame",
                description: Text("삭제되었거나 더 이상 존재하지 않는 기록이에요.")
            )
            .navigationTitle("기록")
            .navigationBarTitleDisplayMode(.inline)
            .background(Color.emberBackground)
        }
    }
}

private struct WelcomeView: View {
    let onStart: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 54)
            EmberJar(size: .welcome).padding(.bottom, 10)
            Text("Ember")
                .font(.emberBrand)
                .foregroundStyle(Color.emberTextPrimary)
            Text("내가 쓴 마음을\n필요한 순간 다시 만나요")
                .font(.emberNavigationTitle)
                .foregroundStyle(Color.emberTextPrimary)
                .multilineTextAlignment(.center)
                .lineSpacing(7)
                .padding(.top, 20)
            Text("결심과 생각을 기록하고 FocusMode에 연결하면\n집중을 시작할 때 다시 알려드려요.")
                .font(.emberBody)
                .foregroundStyle(Color.emberTextSecondary)
                .multilineTextAlignment(.center)
                .lineSpacing(6)
                .padding(.top, 42)
            Spacer()
            Button("시작하기", action: onStart).buttonStyle(.emberPrimary)
            Text("기록은 기기에 안전하게 보관돼요")
                .font(.emberCaption)
                .foregroundStyle(Color.emberTextSecondary)
                .padding(.top, 14)
        }
        .padding(.horizontal, EmberLayout.screenHorizontalPadding)
        .padding(.bottom, 26)
        .background(Color.emberBackground.ignoresSafeArea())
    }
}

private struct SettingsView: View {
    @State private var notificationStatus = UNAuthorizationStatus.notDetermined
    @State private var isFocusGuidePresented = false
    @State private var notificationErrorMessage: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // 고정 헤더
            Text("설정")
                .font(.emberScreenTitle)
                .padding(.horizontal, EmberLayout.screenHorizontalPadding)
                .padding(.top, 18)
                .padding(.bottom, 24)

            // 스크롤되는 영역
            List {
                Section("FocusMode") {
                    LabeledContent("알림", value: notificationStatusDescription)

                    if notificationStatus == .notDetermined {
                        Button("집중 모드 알림 허용") {
                            Task { await requestNotificationAuthorization() }
                        }
                    } else if notificationStatus == .denied {
                        Button("알림 설정 열기", action: openAppSettings)
                    }

                    Button("iPhone 집중 모드에 연결하기") {
                        isFocusGuidePresented = true
                    }
                }

                Section("앱 정보") {
                    LabeledContent("기록 저장", value: "이 기기")
                }
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .background(Color.emberBackground)
        }
        .background(Color.emberBackground)
        .navigationBarHidden(true)
        .task {
            await refreshNotificationStatus()
        }
        .sheet(isPresented: $isFocusGuidePresented) {
            FocusFilterGuideView()
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
                .presentationCornerRadius(28)
        }
        .alert(
            "알림을 설정할 수 없어요",
            isPresented: Binding(
                get: { notificationErrorMessage != nil },
                set: { if !$0 { notificationErrorMessage = nil } }
            )
        ) {
            Button("확인", role: .cancel) {}
        } message: {
            Text(notificationErrorMessage ?? "잠시 후 다시 시도해 주세요.")
        }
    }

    private var notificationStatusDescription: String {
        switch notificationStatus {
        case .authorized: "허용됨"
        case .provisional: "조용히 허용됨"
        case .denied: "허용 안 됨"
        case .notDetermined: "설정 필요"
        case .ephemeral: "일시 허용"
        @unknown default: "확인 필요"
        }
    }

    private func requestNotificationAuthorization() async {
        do {
            _ = try await UNUserNotificationCenter.current().requestAuthorization(
                options: [.alert, .sound]
            )
            await refreshNotificationStatus()
        } catch {
            notificationErrorMessage = error.localizedDescription
        }
    }

    private func refreshNotificationStatus() async {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        notificationStatus = settings.authorizationStatus
    }

    private func openAppSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }
}

private struct FocusFilterGuideView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text("집중 모드가 시작될 때 Ember가 연결된 기록을 다시 보여주려면 iPhone 설정에서 Focus Filter를 한 번 추가해 주세요.")
                        .font(.emberBody)
                        .foregroundStyle(Color.emberTextSecondary)

                    guideStep(
                        number: 1,
                        title: "iPhone 설정에서 집중 모드 선택",
                        description: "설정 > 집중 모드에서 Ember와 연결할 모드를 열어요."
                    )
                    guideStep(
                        number: 2,
                        title: "집중 모드 필터에 Ember 추가",
                        description: "화면 아래의 필터 추가를 누르고 Ember를 선택해요."
                    )
                    guideStep(
                        number: 3,
                        title: "다시 만날 불꽃 선택",
                        description: "이 집중 모드가 시작될 때 다시 만날 불꽃을 하나 이상 선택하고 추가해요."
                    )
                    guideStep(
                        number: 4,
                        title: "Ember 알림 허용",
                        description: "집중 모드의 알림 허용 앱에 Ember를 넣으면 시작과 함께 알림을 받을 수 있어요."
                    )
                }
                .padding(.horizontal, EmberLayout.screenHorizontalPadding)
                .padding(.vertical, 20)
            }
            .background(Color.emberBackground)
            .navigationTitle("집중 모드 연결 방법")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("완료") { dismiss() }
                }
            }
        }
    }

    private func guideStep(number: Int, title: String, description: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Text("\(number)")
                .font(.emberControl)
                .foregroundStyle(Color.white)
                .frame(width: 30, height: 30)
                .background(Color.emberAccent, in: Circle())

            VStack(alignment: .leading, spacing: 5) {
                Text(title)
                    .font(.emberBodyEmphasis)
                    .foregroundStyle(Color.emberTextPrimary)
                Text(description)
                    .font(.emberMetadata)
                    .foregroundStyle(Color.emberTextSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}
#Preview("첫 실행") { WelcomeView(onStart: {}) }
#Preview("앱") {
    MainTabView(recordStore: RecordStore(isStoredInMemoryOnly: true))
}
#Preview("설정") {
    SettingsView()
}
