import SwiftUI

extension Color {
    init(hex: UInt32) {
        self.init(.sRGB,
                  red: Double((hex >> 16) & 0xFF) / 255,
                  green: Double((hex >> 8) & 0xFF) / 255,
                  blue: Double(hex & 0xFF) / 255,
                  opacity: 1)
    }
}

enum Theme {
    static let background = Color(hex: 0x000000)
    static let header = Color(hex: 0x18191A)
    static let border = Color(hex: 0x52525E)
    static let divider = Color(hex: 0x1C1C22)
    static let textPrimary = Color(hex: 0xF4F4F5)
    static let textSecondary = Color(hex: 0xC4C4CC)
    static let textMuted = Color(hex: 0x71717A)
    static let groupLabel = Color(hex: 0x6B6B78)
    static let accent = Color(hex: 0xF24B22)
    static let field = Color(hex: 0x16161C)
    static let fieldBorder = Color(hex: 0x2A2A33)
    static let button = Color(hex: 0x2A2A31)
    static let buttonHover = Color(hex: 0x34343D)
    static let track = Color(hex: 0x2A2A33)

    static func sans(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight)
    }
}

struct GroupLabel: View {
    let text: String

    var body: some View {
        Text(text.uppercased())
            .font(Theme.sans(10, .bold))
            .kerning(0.9)
            .foregroundStyle(Theme.groupLabel)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, 14)
            .padding(.bottom, 4)
    }
}

struct BocahSlider: View {
    @Binding var value: Double
    var enabled: Bool = true

    private let thumbSize: CGFloat = 16
    private let trackHeight: CGFloat = 6

    var body: some View {
        GeometryReader { geo in
            let width = geo.size.width
            let usable = max(width - thumbSize, 1)
            let fraction = min(max(value, 0), 1)
            let offset = CGFloat(fraction) * usable

            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Theme.track)
                    .frame(height: trackHeight)
                Circle()
                    .fill(Theme.accent)
                    .frame(width: thumbSize, height: thumbSize)
                    .overlay(Circle().stroke(Theme.header, lineWidth: 2))
                    .offset(x: offset)
            }
            .frame(height: thumbSize)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { gesture in
                        guard enabled else { return }
                        let x = gesture.location.x - thumbSize / 2
                        value = Double(min(max(x / usable, 0), 1))
                    }
            )
        }
        .frame(height: thumbSize)
        .opacity(enabled ? 1 : 0.4)
    }
}

struct BocahButtonStyle: ButtonStyle {
    var filled: Bool = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Theme.sans(12, .bold))
            .foregroundStyle(filled ? Color.white : Theme.textPrimary.opacity(0.92))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(filled ? Theme.accent : (configuration.isPressed ? Theme.buttonHover : Theme.button))
            )
            .contentShape(RoundedRectangle(cornerRadius: 8))
    }
}

struct IconButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(configuration.isPressed ? Color.white : Theme.textSecondary)
            .contentShape(Rectangle())
    }
}

struct BocahToggle: View {
    @Binding var isOn: Bool
    var enabled: Bool = true

    private let width: CGFloat = 38
    private let height: CGFloat = 22
    private let knob: CGFloat = 18

    var body: some View {
        ZStack(alignment: .leading) {
            Capsule()
                .fill(isOn ? Theme.accent : Color(hex: 0x3A3A44))
                .frame(width: width, height: height)
            Circle()
                .fill(Color.white)
                .frame(width: knob, height: knob)
                .offset(x: isOn ? width - knob - 2 : 2)
                .animation(.easeInOut(duration: 0.2), value: isOn)
        }
        .frame(width: width, height: height)
        .contentShape(Capsule())
        .onTapGesture { if enabled { isOn.toggle() } }
        .opacity(enabled ? 1 : 0.45)
    }
}
