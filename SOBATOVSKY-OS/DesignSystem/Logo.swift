import SwiftUI

/// Фирменный знак: геометрическая буква S из одной линии со скруглёнными углами.
/// Координаты совпадают с tools/make_icon.py (иконка приложения).
struct SMark: Shape {
    func path(in rect: CGRect) -> Path {
        let w = rect.width, h = rect.height
        func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
            CGPoint(x: rect.minX + x * w, y: rect.minY + y * h)
        }
        let r = 0.14 * min(w, h)
        var path = Path()
        path.move(to: p(0.78, 0.18))
        path.addArc(tangent1End: p(0.26, 0.18), tangent2End: p(0.26, 0.50), radius: r)
        path.addArc(tangent1End: p(0.26, 0.50), tangent2End: p(0.74, 0.50), radius: r)
        path.addArc(tangent1End: p(0.74, 0.50), tangent2End: p(0.74, 0.82), radius: r)
        path.addArc(tangent1End: p(0.74, 0.82), tangent2End: p(0.22, 0.82), radius: r)
        path.addLine(to: p(0.22, 0.82))
        return path
    }
}

struct LogoMark: View {
    var size: CGFloat = 24
    var color: Color = SB.platinum
    var body: some View {
        SMark()
            .stroke(color, style: StrokeStyle(lineWidth: max(2, size * 0.1), lineCap: .round, lineJoin: .round))
            .frame(width: size, height: size)
            .accessibilityHidden(true)
    }
}

struct Wordmark: View {
    var body: some View {
        HStack(spacing: 10) {
            LogoMark(size: 22)
            Text("SOBATOVSKY OS")
                .font(.sb(13, .semibold)).tracking(2)
                .foregroundStyle(SB.platinum)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("SOBATOVSKY OS")
    }
}

struct SplashView: View {
    @State private var appeared = false
    var body: some View {
        ZStack {
            Color(hex: 0x09090B).ignoresSafeArea()
            VStack(spacing: 18) {
                LogoMark(size: 96, color: Color(hex: 0xE4E4E7))
                Text("SOBATOVSKY")
                    .font(.sb(24, .bold)).tracking(6)
                    .foregroundStyle(Color(hex: 0xFAFAFA))
                Text("PERSONAL PRODUCTIVITY SYSTEM")
                    .font(.sb(11, .medium)).tracking(2)
                    .foregroundStyle(Color(hex: 0x71717A))
            }
            .opacity(appeared ? 1 : 0)
            .scaleEffect(appeared ? 1 : 0.96)
        }
        .onAppear {
            withAnimation(SBMotion.anim ?? .linear(duration: 0.01)) { appeared = true }
        }
    }
}
