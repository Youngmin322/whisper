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
                    .transition(.opacity)
            } else {
                WelcomeView { hasSeenWelcome = true }
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.28), value: hasSeenWelcome)
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
        let requestIdentifier = WhisperNotificationRoute.consumePendingRequestIdentifier()

        if let recordID {
            selectedTab = .home
            homePath = NavigationPath()
            homePath.append(
                NotificationRecordRoute(
                    recordID: recordID,
                    commitmentID: commitmentID,
                    encounterID: encounterID,
                    requestIdentifier: requestIdentifier
                )
            )
        }

        // 알림 열기는 탐색만 담당합니다. 일정 변경은 명시적인 쉬기/놓아주기에서만 해요.
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
    let requestIdentifier: String?
}

private struct NotificationRecordDestination: View {
    let route: NotificationRecordRoute
    let recordStore: RecordStore
    
    var body: some View {
        if let record = recordStore.record(withID: route.recordID) {
            RecordDetailView(
                record: record,
                recordStore: recordStore,
                reminderEncounterID: route.encounterID,
                reminderCommitmentID: route.commitmentID,
                reminderRequestIdentifier: route.requestIdentifier
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

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var hasAppeared = false
    @State private var isStarting = false
    @State private var stage = 0

    private var entranceAnimation: Animation {
        reduceMotion
            ? .easeOut(duration: 0.18)
            : .spring(duration: 0.64, bounce: 0.12)
    }

    private func verticalOffset(_ offset: CGFloat) -> CGFloat {
        reduceMotion || hasAppeared ? 0 : offset
    }
    
    var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: stage == 0 ? 54 : 30)

            ZStack {
                Circle()
                    .fill(Color.whisperAccent.opacity(stage == 1 ? 0.12 : 0))
                    .frame(width: 136, height: 136)
                    .blur(radius: 14)
                    .scaleEffect(stage == 1 ? 1 : 0.72)

                WhisperJar(size: .welcome)
                    .scaleEffect(stage == 0 ? 1.24 : 1)
                    .offset(y: stage == 0 ? 8 : -4)
            }
            .scaleEffect(hasAppeared ? 1 : 0.86)
            .opacity(hasAppeared ? 1 : 0)
            .offset(y: verticalOffset(16))
            .animation(entranceAnimation, value: hasAppeared)
            .animation(sceneAnimation, value: stage)
            .padding(.bottom, stage == 0 ? 18 : 14)

            Text("Whisper")
                .font(.custom("Pretendard-Bold", size: 22, relativeTo: .title3))
                .foregroundStyle(Color.whisperTextPrimary)
                .opacity(stage == 0 ? 1 : 0)
                .frame(height: 24)
                .animation(sceneAnimation, value: stage)

            ZStack {
                if stage == 0 {
                    onboardingMessage(
                        title: "마음을\n담아두세요",
                        description: "짧게 남겨도, 오래 적어도 괜찮아요.",
                        trustNote: nil
                    )
                    .transition(messageTransition)
                } else {
                    onboardingMessage(
                        title: "마음을,\n다시 만나요.",
                        description: "Whisper가 그 마음을 기억해두고,\n잊을 만한 순간 다시 건넬게요.",
                        trustNote: "기록은 이 기기 안에서만 처리돼요."
                    )
                    .transition(messageTransition)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 220)
            .animation(sceneAnimation, value: stage)

            Spacer()

            Button(stage == 0 ? "계속" : "시작하기", action: advance)
                .buttonStyle(.whisperPrimary)
            .padding(.horizontal, WhisperLayout.screenHorizontalPadding)
            .padding(.bottom, 26)
        }
        .opacity(isStarting ? 0 : 1)
        .scaleEffect(reduceMotion || !isStarting ? 1 : 0.985)
        .animation(.easeOut(duration: 0.18), value: isStarting)
        .background(Color.whisperBackground.ignoresSafeArea())
        .onAppear {
            hasAppeared = true
        }
    }

    private var sceneAnimation: Animation {
        reduceMotion
            ? .easeInOut(duration: 0.2)
            : .spring(duration: 0.56, bounce: 0.08)
    }

    private var messageTransition: AnyTransition {
        reduceMotion
            ? .opacity
            : .opacity.combined(with: .move(edge: .bottom))
    }

    private func onboardingMessage(
        title: String,
        description: String,
        trustNote: String?
    ) -> some View {
        VStack(spacing: 0) {
            Text(title)
                .font(.custom("Pretendard-Bold", size: 32, relativeTo: .largeTitle))
                .foregroundStyle(Color.whisperTextPrimary)
                .multilineTextAlignment(.center)
                .lineSpacing(7)

            Text(description)
                .font(.custom("Pretendard-Regular", size: 17, relativeTo: .body))
                .foregroundStyle(Color.whisperTextSecondary)
                .multilineTextAlignment(.center)
                .lineSpacing(6)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 42)

            if let trustNote {
                Label(trustNote, systemImage: "lock.fill")
                    .font(.custom("Pretendard-Medium", size: 13, relativeTo: .footnote))
                    .foregroundStyle(Color.whisperTextSecondary)
                    .padding(.top, 22)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, WhisperLayout.screenHorizontalPadding)
        .opacity(hasAppeared ? 1 : 0)
        .offset(y: verticalOffset(12))
        .animation(entranceAnimation.delay(reduceMotion ? 0 : 0.16), value: hasAppeared)
    }

    private func advance() {
        guard stage == 0 else {
            start()
            return
        }

        UISelectionFeedbackGenerator().selectionChanged()
        withAnimation(sceneAnimation) {
            stage = 1
        }
    }

    private func start() {
        guard !isStarting else { return }

        UIImpactFeedbackGenerator(style: .soft).impactOccurred()
        isStarting = true

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
            onStart()
        }
    }
}

private struct SettingsView: View {
    let recordStore: RecordStore

    @AppStorage(CommitmentReminderScheduler.showPreviewStorageKey)
    private var showCommitmentPreview = false
    @State private var notificationStatus = UNAuthorizationStatus.notDetermined
    @State private var isFocusGuidePresented = false
    @State private var notificationErrorMessage: String?
#if DEBUG
    @State private var isSchedulingDebugReminder = false
    @State private var debugReminderMessage: String?
#endif
    
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

#if DEBUG
                Section("결심 알림 테스트") {
                    Button {
                        Task { await scheduleDebugReminder() }
                    } label: {
                        HStack {
                            Text("10초 뒤 테스트 알림 보내기")
                            Spacer()
                            if isSchedulingDebugReminder {
                                ProgressView()
                            }
                        }
                    }
                    .disabled(isSchedulingDebugReminder)

                    Button("예약된 테스트 알림 취소", role: .destructive) {
                        Task { await cancelDebugReminders() }
                    }
                    .disabled(isSchedulingDebugReminder)

                    Text(
                        debugReminderMessage
                            ?? "가장 최근에 기억한 결심으로 실제 알림 흐름을 테스트해요."
                    )
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
#endif
                
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

#if DEBUG
    private func scheduleDebugReminder() async {
        isSchedulingDebugReminder = true
        defer { isSchedulingDebugReminder = false }

        switch await CommitmentReminderCoordinator.scheduleDebugReminder(
            in: recordStore
        ) {
        case let .scheduled(date):
            debugReminderMessage = "테스트 알림을 \(date.formatted(date: .omitted, time: .standard))에 보낼게요."
        case .noActiveCommitment:
            debugReminderMessage = "먼저 기록에서 결심 하나를 간직해 주세요."
        case .authorizationUnavailable:
            debugReminderMessage = "알림 권한을 허용한 뒤 다시 시도해 주세요."
            await refreshNotificationStatus()
        case .failed:
            debugReminderMessage = "테스트 알림을 예약하지 못했어요. 잠시 후 다시 시도해 주세요."
        }
    }

    private func cancelDebugReminders() async {
        isSchedulingDebugReminder = true
        defer { isSchedulingDebugReminder = false }

        if await CommitmentReminderCoordinator.cancelDebugReminders(in: recordStore) {
            debugReminderMessage = "예약된 테스트 알림을 취소했어요."
        } else {
            debugReminderMessage = "테스트 알림을 취소하지 못했어요."
        }
    }
#endif
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
