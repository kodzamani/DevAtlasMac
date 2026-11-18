import SwiftUI

// Fallbacks that keep the app running on macOS 12 (Monterey). Each one uses the modern API
// when it exists and degrades quietly when it does not.

// MARK: - onChange

private struct OnChangeCompat<V: Equatable>: ViewModifier {
    let value: V
    let initial: Bool
    let action: (V, V) -> Void
    @State private var previous: V

    init(value: V, initial: Bool, action: @escaping (V, V) -> Void) {
        self.value = value
        self.initial = initial
        self.action = action
        _previous = State(initialValue: value)
    }

    func body(content: Content) -> some View {
        content
            .onChange(of: value) { newValue in
                let old = previous
                previous = newValue
                action(old, newValue)
            }
            .onAppear {
                if initial { action(value, value) }
            }
    }
}

extension View {
    func daOnChange<V: Equatable>(of value: V, initial: Bool = false, _ action: @escaping (V, V) -> Void) -> some View {
        modifier(OnChangeCompat(value: value, initial: initial, action: action))
    }

    func daOnChange<V: Equatable>(of value: V, initial: Bool = false, _ action: @escaping () -> Void) -> some View {
        modifier(OnChangeCompat(value: value, initial: initial) { _, _ in action() })
    }

    /// Numeric text morphing on macOS 13+, nothing before.
    @ViewBuilder
    func daNumericTransition() -> some View {
        if #available(macOS 13.0, *) {
            contentTransition(.numericText())
        } else {
            self
        }
    }

    /// Pointer tracking on macOS 13+, plain hover (no location) before.
    func daContinuousHover(perform: @escaping (DAHoverPhase) -> Void) -> some View {
        modifier(ContinuousHoverCompat(perform: perform))
    }
}

enum DAHoverPhase {
    case active(CGPoint)
    case ended
}

private struct ContinuousHoverCompat: ViewModifier {
    let perform: (DAHoverPhase) -> Void

    func body(content: Content) -> some View {
        if #available(macOS 13.0, *) {
            content.onContinuousHover(coordinateSpace: .local) { phase in
                switch phase {
                case .active(let point): perform(.active(point))
                case .ended: perform(.ended)
                }
            }
        } else {
            content.onHover { inside in
                perform(inside ? .active(.zero) : .ended)
            }
        }
    }
}

// MARK: - Adaptive stack

/// Horizontal when `isWide`, vertical otherwise (AnyLayout needs macOS 13).
struct AdaptiveStack<Content: View>: View {
    let isWide: Bool
    var verticalAlignment: VerticalAlignment = .center
    var horizontalAlignment: HorizontalAlignment = .leading
    let wideSpacing: CGFloat
    let narrowSpacing: CGFloat
    @ViewBuilder let content: () -> Content

    var body: some View {
        if isWide {
            HStack(alignment: verticalAlignment, spacing: wideSpacing, content: content)
        } else {
            VStack(alignment: horizontalAlignment, spacing: narrowSpacing, content: content)
        }
    }
}

// MARK: - Background prominence

private struct IncreasedProminenceKey: EnvironmentKey {
    static let defaultValue = false
}

extension EnvironmentValues {
    /// Forces glyphs to draw for a selected/prominent background (backgroundProminence needs macOS 14).
    var daIncreasedProminence: Bool {
        get { self[IncreasedProminenceKey.self] }
        set { self[IncreasedProminenceKey.self] = newValue }
    }
}

// MARK: - Bindings & buttons

func daBinding<Object: ObservableObject, Value>(_ object: Object, _ keyPath: ReferenceWritableKeyPath<Object, Value>) -> Binding<Value> {
    Binding(get: { object[keyPath: keyPath] }, set: { object[keyPath: keyPath] = $0 })
}

// Same signature as the macOS 14 SwiftUI initializer, so it shadows it and works on macOS 12.
extension Button where Label == SwiftUI.Label<Text, Image> {
    init(_ title: String, systemImage: String, action: @escaping () -> Void) {
        self.init(action: action) { SwiftUI.Label(title, systemImage: systemImage) }
    }
}

// MARK: - Window chrome

extension View {
    /// Transparent window toolbar on macOS 13+.
    @ViewBuilder
    func daHideWindowToolbarBackground() -> some View {
        if #available(macOS 13.0, *) {
            toolbarBackground(.hidden, for: .windowToolbar)
        } else {
            self
        }
    }

    /// Hides the scroll background of lists/editors on macOS 13+.
    @ViewBuilder
    func daScrollContentBackgroundHidden() -> some View {
        if #available(macOS 13.0, *) {
            scrollContentBackground(.hidden)
        } else {
            self
        }
    }

    @ViewBuilder
    func daScrollBounceBasedOnSize() -> some View {
        if #available(macOS 13.3, *) {
            scrollBounceBehavior(.basedOnSize)
        } else {
            self
        }
    }

    @ViewBuilder
    func daScrollIndicatorsHidden() -> some View {
        if #available(macOS 13.0, *) {
            scrollIndicators(.hidden)
        } else {
            self
        }
    }
}

extension View {
    /// Plain borderless menu button without a disclosure arrow.
    @ViewBuilder
    func daBorderlessMenu() -> some View {
        if #available(macOS 13.0, *) {
            menuStyle(.button).buttonStyle(.plain).menuIndicator(.hidden).fixedSize()
        } else {
            menuStyle(.borderlessButton).menuIndicator(.hidden).fixedSize()
        }
    }

    @ViewBuilder
    func daItalic() -> some View {
        if #available(macOS 13.0, *) {
            italic()
        } else {
            self
        }
    }

    @ViewBuilder
    func daListRowSeparatorHidden() -> some View {
        if #available(macOS 13.0, *) {
            listRowSeparator(.hidden)
        } else {
            self
        }
    }

    @ViewBuilder
    func daContentTransitionOpacity() -> some View {
        if #available(macOS 13.0, *) {
            contentTransition(.opacity)
        } else {
            self
        }
    }
}

extension Color {
    /// Soft top-to-bottom gradient of this color (`Color.gradient` needs macOS 13).
    var daGradient: LinearGradient {
        LinearGradient(colors: [self.opacity(0.85), self], startPoint: .top, endPoint: .bottom)
    }
}

extension Menu where Label == SwiftUI.Label<Text, Image> {
    init(_ title: String, systemImage: String, @ViewBuilder content: () -> Content) {
        self.init(content: content) { SwiftUI.Label(title, systemImage: systemImage) }
    }
}

extension View {
    /// Window toolbar: the full one on macOS 13+, a simpler one before.
    @ViewBuilder
    func daAppToolbar(viewModel: AppViewModel, statsVM: StatsViewModel, cacheVM: ProjectCacheViewModel, chatVM: ChatViewModel) -> some View {
        if #available(macOS 13.0, *) {
            toolbar { AppToolbar(viewModel: viewModel, statsVM: statsVM, cacheVM: cacheVM, chatVM: chatVM) }
        } else {
            toolbar { LegacyAppToolbar(viewModel: viewModel, statsVM: statsVM, cacheVM: cacheVM, chatVM: chatVM) }
        }
    }
}

extension View {
    @ViewBuilder
    func daScrollDisabled(_ disabled: Bool) -> some View {
        if #available(macOS 13.0, *) {
            scrollDisabled(disabled)
        } else {
            self
        }
    }

    /// Starts scrolled to the trailing edge on macOS 14+.
    @ViewBuilder
    func daDefaultScrollAnchorTrailing() -> some View {
        if #available(macOS 14.0, *) {
            defaultScrollAnchor(.trailing)
        } else {
            self
        }
    }
}

/// Rectangle with only the bottom corners rounded.
struct BottomRoundedRectangle: Shape {
    var radius: CGFloat

    func path(in rect: CGRect) -> Path {
        let r = min(radius, rect.width / 2, rect.height)
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - r))
        path.addArc(center: CGPoint(x: rect.maxX - r, y: rect.maxY - r), radius: r, startAngle: .degrees(0), endAngle: .degrees(90), clockwise: false)
        path.addLine(to: CGPoint(x: rect.minX + r, y: rect.maxY))
        path.addArc(center: CGPoint(x: rect.minX + r, y: rect.maxY - r), radius: r, startAngle: .degrees(90), endAngle: .degrees(180), clockwise: false)
        path.closeSubpath()
        return path
    }
}

/// Row context menu and double-click action for the table (macOS 13+; earlier systems have neither).
struct TableRowActions<Menu: View>: ViewModifier {
    @ViewBuilder let menu: (Set<ProjectInfo.ID>) -> Menu
    let open: (Set<ProjectInfo.ID>) -> Void

    func body(content: Content) -> some View {
        if #available(macOS 13.0, *) {
            content.contextMenu(forSelectionType: ProjectInfo.ID.self, menu: menu, primaryAction: open)
        } else {
            content
        }
    }
}

extension View {
    @ViewBuilder
    func daTracking(_ value: CGFloat) -> some View {
        if #available(macOS 13.0, *) {
            tracking(value)
        } else {
            self
        }
    }
}
