import SwiftUI

struct RootView: View {
    @EnvironmentObject var store: AppStore
    @EnvironmentObject var focus: FocusEngine
    @Environment(\.scenePhase) private var scenePhase
    @State private var showSplash = true

    private var scheme: ColorScheme? {
        switch store.data.settings.theme {
        case .dark: return .dark
        case .light: return .light
        case .system: return nil
        }
    }

    var body: some View {
        ZStack {
            SB.background.ignoresSafeArea()

            TabView(selection: $store.selectedTab) {
                OverviewView().tag(AppTab.overview).toolbar(.hidden, for: .tabBar)
                TasksView().tag(AppTab.tasks).toolbar(.hidden, for: .tabBar)
                KnowledgeView().tag(AppTab.knowledge).toolbar(.hidden, for: .tabBar)
                FocusView().tag(AppTab.focus).toolbar(.hidden, for: .tabBar)
                ProgressScreen().tag(AppTab.progress).toolbar(.hidden, for: .tabBar)
            }
            .safeAreaInset(edge: .bottom, spacing: 0) {
                SBTabBar().ignoresSafeArea(.keyboard, edges: .bottom)
            }

            if showSplash {
                SplashView().transition(.opacity).zIndex(10)
            }
        }
        .overlay(alignment: .top) {
            if let t = store.toast {
                XPToastView(toast: t)
                    .padding(.top, 8)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .preferredColorScheme(scheme)
        .environment(\.locale, Locale(identifier: "ru_RU"))
        .task {
            focus.attach(store)
            store.scheduleNotificationSync()
            try? await Task.sleep(nanoseconds: 700_000_000)
            withAnimation(SBMotion.anim) { showSplash = false }
        }
        .onChange(of: scenePhase) { _, phase in
            switch phase {
            case .active:
                store.dayTick = Date()
                focus.tick()
            case .inactive, .background:
                store.flush()
            @unknown default:
                break
            }
        }
        .alert("Внимание", isPresented: Binding(
            get: { store.startupMessage != nil },
            set: { if !$0 { store.startupMessage = nil } })
        ) {
            Button("Понятно", role: .cancel) {}
        } message: {
            Text(store.startupMessage ?? "")
        }
    }
}
