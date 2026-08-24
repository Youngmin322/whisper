//
//  ContentView.swift
//  Ember
//

import SwiftUI
import EmberDesignSystem

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

    var body: some View {
        TabView {
            Tab("기록", systemImage: "flame.fill") {
                NavigationStack { HomeView(recordStore: recordStore) }
            }
            Tab("보관함", systemImage: "archivebox.fill") {
                NavigationStack { CollectionView(recordStore: recordStore) }
            }
            Tab("설정", systemImage: "gearshape") {
                NavigationStack { SettingsView() }
            }
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
                    NavigationLink("FocusMode 연결 관리") {
                        FocusConnectionsView()
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
    }
}
#Preview("첫 실행") { WelcomeView(onStart: {}) }
#Preview("앱") { MainTabView(recordStore: RecordStore()) }
#Preview("설정") {
    SettingsView()
}
