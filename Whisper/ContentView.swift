//
//  ContentView.swift
//  Whisper
//

import SwiftUI
import WhisperDesignSystem
import UserNotifications
import UIKit

struct ContentView: View {
    @AppStorage("hasSeenWelcome") private var hasSeenWelcome = false
    @State private var recordStore = RecordStore()
    
    var body: some View {
        Group {
            if !recordStore.isPersistenceAvailable {
                PersistenceUnavailableView(
                    supportCode: recordStore.persistenceSupportCode,
                    diagnosticSummary: recordStore.persistenceDiagnosticSummary,
                    onRetry: { recordStore = RecordStore() }
                )
            } else if hasSeenWelcome {
                MainTabView(recordStore: recordStore)
            } else {
                WelcomeView { hasSeenWelcome = true }
            }
        }
        .tint(.whisperAccent)
    }
}

private struct PersistenceUnavailableView: View {
    let supportCode: String?
    let diagnosticSummary: String?
    let onRetry: () -> Void

    @State private var didCopyDiagnostics = false

    var body: some View {
        ContentUnavailableView {
            Label("기록을 불러올 수 없어요", systemImage: "externaldrive.badge.xmark")
        } description: {
            VStack(spacing: 8) {
                Text("작성한 기록을 보호하기 위해 저장 기능을 멈췄어요. 잠시 후 다시 시도해 주세요.")
                if let supportCode {
                    Text("지원 코드: \(supportCode)")
                        .font(.caption.monospaced())
                        .textSelection(.enabled)
                }
            }
        } actions: {
            VStack(spacing: 12) {
                Button("다시 시도", action: onRetry)
                    .buttonStyle(.whisperPrimary(size: .compact))

                if let diagnosticSummary {
                    Button(didCopyDiagnostics ? "진단 정보 복사됨" : "진단 정보 복사") {
                        UIPasteboard.general.string = diagnosticSummary
                        didCopyDiagnostics = true
                    }
                    .buttonStyle(.bordered)
                }
            }
        }
        .padding(.horizontal, WhisperLayout.screenHorizontalPadding)
        .background(Color.whisperBackground.ignoresSafeArea())
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
                        .navigationDestination(for: NotificationRecordRoute.self) { route in
                            NotificationRecordDestination(
                                route: route,
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
                    SettingsView(recordStore: recordStore)
                }
            }
        }
        .task {
            consumePendingNotificationRoute()
            await synchronizeReminderState()
        }
        .onReceive(NotificationCenter.default.publisher(for: WhisperNotificationRoute.didSelectRecord)) { _ in
            consumePendingNotificationRoute()
        }
        .onReceive(NotificationCenter.default.publisher(for: WhisperNotificationRoute.didPresentEncounter)) { notification in
            guard let encounterID = notification.object as? UUID else { return }
            _ = recordStore.markEncounterPresented(encounterID)
        }
        .onChange(of: scenePhase) { _, newValue in
            guard newValue == .active else { return }
            Task {
                consumePendingNotificationRoute()
                await synchronizeReminderState()
            }
        }
    }
    
    private func consumePendingNotificationRoute() {
        let recordID = WhisperNotificationRoute.consumePendingRecordID()
        let commitmentID = WhisperNotificationRoute.consumePendingCommitmentID()
        let encounterID = WhisperNotificationRoute.consumePendingEncounterID()

        if let recordID {
            selectedTab = .home
            homePath = NavigationPath()
            homePath.append(
                NotificationRecordRoute(
                    recordID: recordID,
                    commitmentID: commitmentID,
                    encounterID: encounterID
                )
            )
        }

        // 새 알림은 상세 화면에서 열람·반응과 다음 일정을 한 흐름으로 처리해요.
        // encounterID가 없는 이전 버전 알림만 기존 방식으로 다시 예약해요.
        if encounterID == nil, let commitmentID {
            replanOpenedCommitment(commitmentID)
        }
    }

    private func replanOpenedCommitment(_ commitmentID: UUID) {
        guard let context = recordStore.reminderPlanningContext(for: commitmentID) else { return }

        Task {
            let timing = await CommitmentAnalyzer().replanReminder(
                for: context,
                eventDescription: "사용자가 리마인드 알림을 열었습니다."
            )
            guard let plan = recordStore.rescheduleCommitment(
                commitmentID,
                reminderTiming: timing
            ) else {
                return
            }
            _ = await CommitmentReminderCoordinator.schedule(plan, in: recordStore)
        }
    }

    private func synchronizeReminderState() async {
        await CommitmentReminderCoordinator.synchronize(with: recordStore)
    }
}

private enum MainTab: Hashable {
    case home
    case collection
    case settings
}

private struct NotificationRecordRoute: Hashable {
    let recordID: UUID
    let commitmentID: UUID?
    let encounterID: UUID?
}

private struct NotificationRecordDestination: View {
    let route: NotificationRecordRoute
    let recordStore: RecordStore
    
    var body: some View {
        if let record = recordStore.record(withID: route.recordID) {
            RecordDetailView(
                record: record,
                recordStore: recordStore,
                reminderEncounterID: route.encounterID
            )
        } else {
            ContentUnavailableView(
                "기록을 찾을 수 없어요",
                systemImage: "flame",
                description: Text("삭제되었거나 더 이상 존재하지 않는 기록이에요.")
            )
            .navigationTitle("기록")
            .navigationBarTitleDisplayMode(.inline)
            .background(Color.whisperBackground)
        }
    }
}

private struct WelcomeView: View {
    let onStart: () -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 54)
            WhisperJar(size: .welcome).padding(.bottom, 10)
            Text("Whisper")
                .font(.whisperBrand)
                .foregroundStyle(Color.whisperTextPrimary)
            Text("내가 쓴 마음을\n필요한 순간 다시 만나요")
                .font(.whisperNavigationTitle)
                .foregroundStyle(Color.whisperTextPrimary)
                .multilineTextAlignment(.center)
                .lineSpacing(7)
                .padding(.top, 20)
            Text("기록 속 결심을 Whisper가 기억하고\n잊힐 만한 순간 다시 건넬게요.")
                .font(.whisperBody)
                .foregroundStyle(Color.whisperTextSecondary)
                .multilineTextAlignment(.center)
                .lineSpacing(6)
                .padding(.top, 42)
            Spacer()
            Button("시작하기", action: onStart).buttonStyle(.whisperPrimary)
        }
        .padding(.horizontal, WhisperLayout.screenHorizontalPadding)
        .padding(.bottom, 26)
        .background(Color.whisperBackground.ignoresSafeArea())
    }
}

private struct SettingsView: View {
    let recordStore: RecordStore

    @AppStorage(CommitmentReminderScheduler.showPreviewStorageKey)
    private var showCommitmentPreview = false
    @State private var notificationStatus = UNAuthorizationStatus.notDetermined
    @State private var isFocusGuidePresented = false
    @State private var notificationErrorMessage: String?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // 고정 헤더
            Text("설정")
                .font(.whisperScreenTitle)
                .padding(.horizontal, WhisperLayout.screenHorizontalPadding)
                .padding(.top, 18)
                .padding(.bottom, 24)
            
            // 스크롤되는 영역
            List {
                Section("다시 만나는 불꽃") {
                    LabeledContent("알림", value: notificationStatusDescription)
                    
                    Toggle("새 알림에 기록 내용 표시", isOn: $showCommitmentPreview)
                    
                    if notificationStatus == .notDetermined {
                        Button("다시 만나기 알림 허용") {
                            Task { await requestNotificationAuthorization() }
                        }
                    } else if notificationStatus == .denied {
                        Button("알림 설정 열기", action: openAppSettings)
                    }
                }
                
                Section("FocusMode") {
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
            .background(Color.whisperBackground)
        }
        .background(Color.whisperBackground)
        .navigationBarHidden(true)
        .task {
            await refreshNotificationStatus()
        }
        .sheet(isPresented: $isFocusGuidePresented) {
            FocusFilterGuideView()
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
            .presentationCornerRadius(28)
            .presentationBackground(.clear)
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
            let isAuthorized = try await UNUserNotificationCenter.current().requestAuthorization(
                options: [.alert, .sound]
            )
            await refreshNotificationStatus()
            if isAuthorized {
                await CommitmentReminderCoordinator.synchronize(with: recordStore)
            }
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
                    Text("집중 모드가 시작될 때 Whisper가 연결된 기록을 다시 보여주려면 iPhone 설정에서 Focus Filter를 한 번 추가해 주세요.")
                        .font(.whisperBody)
                        .foregroundStyle(Color.whisperTextSecondary)
                    
                    guideStep(
                        number: 1,
                        title: "iPhone 설정에서 집중 모드 선택",
                        description: "설정 > 집중 모드에서 Whisper와 연결할 모드를 열어요."
                    )
                    guideStep(
                        number: 2,
                        title: "집중 모드 필터에 Whisper 추가",
                        description: "화면 아래의 필터 추가를 누르고 Whisper를 선택해요."
                    )
                    guideStep(
                        number: 3,
                        title: "다시 만날 불꽃 선택",
                        description: "이 집중 모드가 시작될 때 다시 만날 불꽃을 하나 이상 선택하고 추가해요."
                    )
                    guideStep(
                        number: 4,
                        title: "Whisper 알림 허용",
                        description: "집중 모드의 알림 허용 앱에 Whisper를 넣으면 시작과 함께 알림을 받을 수 있어요."
                    )
                }
                .padding(.horizontal, WhisperLayout.screenHorizontalPadding)
                .padding(.vertical, 20)
            }
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
                .font(.whisperControl)
                .foregroundStyle(Color.white)
                .frame(width: 30, height: 30)
                .background(Color.whisperAccent, in: Circle())
            
            VStack(alignment: .leading, spacing: 5) {
                Text(title)
                    .font(.whisperBodyEmphasis)
                    .foregroundStyle(Color.whisperTextPrimary)
                
                Text(description)
                    .font(.whisperMetadata)
                    .foregroundStyle(Color.whisperTextSecondary)
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
    SettingsView(recordStore: RecordStore(isStoredInMemoryOnly: true))
}
