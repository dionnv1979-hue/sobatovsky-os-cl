import SwiftUI

struct SBCard<Content: View>: View {
    var padding: CGFloat
    var radius: CGFloat
    var fill: Color
    var stroke: Color
    let content: Content

    init(padding: CGFloat = 16, radius: CGFloat = 20, fill: Color = SB.surface,
         stroke: Color = SB.border, @ViewBuilder content: () -> Content) {
        self.padding = padding
        self.radius = radius
        self.fill = fill
        self.stroke = stroke
        self.content = content()
    }

    var body: some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: radius, style: .continuous).fill(fill))
            .overlay(RoundedRectangle(cornerRadius: radius, style: .continuous).strokeBorder(stroke, lineWidth: 1))
    }
}

struct SBPrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.sb(16, .semibold))
            .foregroundStyle(SB.primaryText)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(SB.primaryFill, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .opacity(configuration.isPressed ? 0.85 : 1)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

struct SBSecondaryButtonStyle: ButtonStyle {
    var tint: Color = SB.platinum
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.sb(15, .medium))
            .foregroundStyle(tint)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(SB.elevated, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(SB.border, lineWidth: 1))
            .opacity(configuration.isPressed ? 0.8 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

extension ButtonStyle where Self == SBPrimaryButtonStyle {
    static var sbPrimary: SBPrimaryButtonStyle { SBPrimaryButtonStyle() }
}
extension ButtonStyle where Self == SBSecondaryButtonStyle {
    static var sbSecondary: SBSecondaryButtonStyle { SBSecondaryButtonStyle() }
}

struct SBLabel: View {
    let text: String
    init(_ text: String) { self.text = text }
    var body: some View {
        Text(text).font(.sb(11, .semibold)).tracking(1.4).foregroundStyle(SB.muted)
    }
}

struct SectionTitle: View {
    let title: String
    var actionTitle: String? = nil
    var action: (() -> Void)? = nil
    var body: some View {
        HStack {
            Text(title).font(.sb(20, .semibold)).foregroundStyle(SB.white)
            Spacer()
            if let t = actionTitle, let a = action {
                Button(t) { Haptics.tap(); a() }
                    .font(.sb(14, .medium)).foregroundStyle(SB.silver)
            }
        }
    }
}

struct ScreenHeader<Trailing: View>: View {
    let title: String
    let subtitle: String
    let trailing: Trailing
    init(_ title: String, subtitle: String, @ViewBuilder trailing: () -> Trailing) {
        self.title = title
        self.subtitle = subtitle
        self.trailing = trailing()
    }
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.sb(32, .bold)).foregroundStyle(SB.white)
                    .minimumScaleFactor(0.7).lineLimit(1)
                Text(subtitle).font(.sb(14)).foregroundStyle(SB.silver)
            }
            Spacer(minLength: 8)
            trailing
        }
    }
}
extension ScreenHeader where Trailing == EmptyView {
    init(_ title: String, subtitle: String) {
        self.init(title, subtitle: subtitle) { EmptyView() }
    }
}

struct IconButton: View {
    let system: String
    let label: String
    var badge = false
    let action: () -> Void
    var body: some View {
        Button { Haptics.tap(); action() } label: {
            Image(systemName: system)
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(SB.platinum)
                .frame(width: 40, height: 40)
                .background(SB.surface, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(SB.border, lineWidth: 1))
                .overlay(alignment: .topTrailing) {
                    if badge { Circle().fill(SB.warning).frame(width: 8, height: 8).offset(x: -6, y: 6) }
                }
        }
        .accessibilityLabel(label)
    }
}

struct EmptyState: View {
    let icon: String
    let title: String
    let message: String
    var buttonTitle: String? = nil
    var action: (() -> Void)? = nil
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: icon).font(.system(size: 34, weight: .light)).foregroundStyle(SB.muted)
            Text(title).font(.sb(18, .semibold)).foregroundStyle(SB.white).multilineTextAlignment(.center)
            Text(message).font(.sb(14)).foregroundStyle(SB.silver).multilineTextAlignment(.center)
            if let b = buttonTitle, let a = action {
                Button(b) { Haptics.tap(); a() }
                    .buttonStyle(.sbPrimary).frame(maxWidth: 260).padding(.top, 6)
            }
        }
        .padding(.vertical, 28).padding(.horizontal, 16)
        .frame(maxWidth: .infinity)
    }
}

struct ProgressRing: View {
    var progress: Double
    var lineWidth: CGFloat = 10
    var tint: Color = SB.platinum
    var body: some View {
        ZStack {
            Circle().stroke(SB.elevated, lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: CGFloat(min(max(progress, 0), 1)))
                .stroke(tint, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
        }
        .animation(SBMotion.anim, value: progress)
    }
}

struct LinearBar: View {
    var value: Double
    var tint: Color = SB.platinum
    var height: CGFloat = 6
    var body: some View {
        GeometryReader { g in
            ZStack(alignment: .leading) {
                Capsule().fill(SB.elevated)
                Capsule().fill(tint)
                    .frame(width: max(0, g.size.width * CGFloat(min(max(value, 0), 1))))
            }
        }
        .frame(height: height)
        .animation(SBMotion.anim, value: value)
    }
}

struct StatTile: View {
    let icon: String
    let value: String
    let label: String
    var tint: Color = SB.silver
    var body: some View {
        SBCard(padding: 14, radius: 16) {
            VStack(alignment: .leading, spacing: 8) {
                Image(systemName: icon).font(.system(size: 16, weight: .medium)).foregroundStyle(tint)
                Text(value).font(.sb(26, .bold)).monospacedDigit().foregroundStyle(SB.white)
                    .minimumScaleFactor(0.6).lineLimit(1)
                Text(label).font(.sb(12)).foregroundStyle(SB.silver).lineLimit(1)
            }
        }
        .accessibilityElement(children: .combine)
    }
}

struct Tag: View {
    let text: String
    var tint: Color = SB.silver
    var body: some View {
        Text(text)
            .font(.sb(11, .medium)).foregroundStyle(tint)
            .padding(.horizontal, 8).padding(.vertical, 3)
            .background(tint.opacity(0.14), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .lineLimit(1)
    }
}

struct FilterChips<T: Hashable>: View {
    let items: [T]
    @Binding var selection: T
    let label: (T) -> String
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(items, id: \.self) { item in
                    let selected = item == selection
                    Button {
                        Haptics.tap()
                        withAnimation(SBMotion.anim) { selection = item }
                    } label: {
                        Text(label(item))
                            .font(.sb(14, .medium))
                            .foregroundStyle(selected ? SB.primaryText : SB.silver)
                            .padding(.horizontal, 14).padding(.vertical, 8)
                            .background(selected ? SB.primaryFill : SB.surface, in: Capsule())
                            .overlay(Capsule().strokeBorder(selected ? Color.clear : SB.border, lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(selected ? .isSelected : [])
                }
            }
            .padding(.horizontal, SB.pad)
        }
        .padding(.horizontal, -SB.pad)
    }
}

struct SBSearchField: View {
    @Binding var text: String
    var prompt = "Поиск"
    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass").foregroundStyle(SB.muted)
            TextField(prompt, text: $text)
                .font(.sb(16)).foregroundStyle(SB.white)
                .textInputAutocapitalization(.never).autocorrectionDisabled()
            if !text.isEmpty {
                Button { text = "" } label: {
                    Image(systemName: "xmark.circle.fill").foregroundStyle(SB.muted)
                }
                .accessibilityLabel("Очистить поиск")
            }
        }
        .padding(12)
        .background(SB.surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(SB.border, lineWidth: 1))
    }
}

struct SBFieldModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(.sb(16)).foregroundStyle(SB.white)
            .padding(14)
            .background(SB.elevated, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}
extension View {
    func sbField() -> some View { modifier(SBFieldModifier()) }

    /// Единый стиль форм: тёмный фон, графитовые строки.
    func sbForm() -> some View {
        self.scrollContentBackground(.hidden)
            .background(SB.background.ignoresSafeArea())
            .tint(SB.silver)
    }
}

struct SBTabBar: View {
    @EnvironmentObject var store: AppStore
    var body: some View {
        HStack(spacing: 0) {
            ForEach(AppTab.allCases) { tab in
                let selected = store.selectedTab == tab
                Button {
                    guard store.selectedTab != tab else { return }
                    Haptics.tap()
                    withAnimation(SBMotion.anim) { store.selectedTab = tab }
                } label: {
                    VStack(spacing: 4) {
                        Capsule().fill(selected ? SB.silver : Color.clear).frame(width: 22, height: 2)
                        Image(systemName: tab.icon).font(.system(size: 20, weight: .medium))
                        Text(tab.title).font(.sb(11, .medium))
                    }
                    .foregroundStyle(selected ? SB.white : SB.muted)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 6).padding(.bottom, 4)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(tab.title)
                .accessibilityAddTraits(selected ? .isSelected : [])
            }
        }
        .padding(.horizontal, 8)
        .background(SB.deep.ignoresSafeArea(edges: .bottom))
        .overlay(alignment: .top) { Rectangle().fill(SB.border).frame(height: 1) }
    }
}

struct XPToastView: View {
    let toast: XPToast
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "bolt.fill").foregroundStyle(SB.warning)
            Text("+\(toast.amount) XP").font(.sb(15, .semibold)).monospacedDigit().foregroundStyle(SB.white)
            Text(toast.title).font(.sb(13)).foregroundStyle(SB.silver).lineLimit(1)
        }
        .padding(.horizontal, 16).padding(.vertical, 10)
        .background(SB.surface, in: Capsule())
        .overlay(Capsule().strokeBorder(SB.border, lineWidth: 1))
        .shadow(color: .black.opacity(0.25), radius: 12, y: 4)
        .accessibilityElement(children: .combine)
    }
}
