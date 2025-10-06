import SwiftUI

struct AttachmentMenuView<Content: View>: View {
    @Binding var config: AttachmentMenuConfig
    @ViewBuilder var content: Content
    @AttachmentMenuActionBuilder var actions: [AttachmentMenuAction]
    @State private var animateContent = false
    @State private var animateLabels = false
    @State private var activeActionID: String?

    var body: some View {
        content
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .overlay {
                Rectangle()
                    .fill(.bar)
                    .ignoresSafeArea()
                    .opacity(animateContent ? 1 : 0)
                    .allowsHitTesting(false)
            }
            .overlay {
                if animateContent {
                    Rectangle()
                        .foregroundStyle(.clear)
                        .contentShape(.rect)
                        .onDisappear {
                            config.hideSourceView = false
                            activeActionID = actions.first?.id
                        }
                }
            }
            .overlay {
                GeometryReader { proxy in
                    menuScrollView(proxy)

                    if config.hideSourceView {
                        config.sourceView
                            .scaleEffect(animateContent ? 15 : 1, anchor: .bottom)
                            .offset(x: config.sourceLocation.minX, y: config.sourceLocation.minY)
                            .opacity(animateContent ? 0.25 : 1)
                            .blur(radius: animateContent ? 130 : 0)
                            .ignoresSafeArea()
                            .allowsHitTesting(false)
                    }
                }
                .opacity(config.hideSourceView ? 1 : 0)
            }
            .onChange(of: config.showMenu) { _, newValue in
                if newValue {
                    config.hideSourceView = true
                }

                withAnimation(.smooth(duration: 0.45, extraBounce: 0)) {
                    animateContent = newValue
                }

                withAnimation(.easeInOut(duration: newValue ? 0.35 : 0.15)) {
                    animateLabels = newValue
                }
            }
    }

    @ViewBuilder
    private func menuScrollView(_ proxy: GeometryProxy) -> some View {
        ScrollView(.vertical) {
            VStack(alignment: .leading, spacing: 0) {
                ForEach(actions) { action in
                    menuActionView(action)
                }
            }
            .scrollTargetLayout()
            .padding(.horizontal, 25)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                Rectangle()
                    .foregroundStyle(.clear)
                    .frame(width: proxy.size.width, height: proxy.size.height + proxy.safeAreaInsets.top + proxy.safeAreaInsets.bottom)
                    .contentShape(.rect)
                    .onTapGesture {
                        guard config.showMenu else { return }
                        config.showMenu = false
                    }
                    .visualEffect { content, proxy in
                        content
                            .offset(
                                x: -proxy.frame(in: .global).minX,
                                y: -proxy.frame(in: .global).minY
                            )
                    }
            }
        }
        .safeAreaPadding(.vertical, 20)
        .safeAreaPadding(.top, (proxy.size.height - 70) / 2)
        .scrollPosition(id: $activeActionID, anchor: .top)
        .scrollIndicators(.hidden)
        .allowsHitTesting(config.showMenu)
    }

    @ViewBuilder
    private func menuActionView(_ action: AttachmentMenuAction) -> some View {
        let sourceLocation = config.sourceLocation

        HStack(spacing: 20) {
            Image(systemName: action.symbolImage)
                .font(.title3)
                .frame(width: 40, height: 40)
                .background {
                    Circle()
                        .fill(.background)
                        .shadow(radius: 1.5)
                }
                .scaleEffect(animateContent ? 1 : 0.6)
                .opacity(animateContent ? 1 : 0)
                .blur(radius: animateContent ? 0 : 4)

            Text(action.text)
                .font(.system(size: 19))
                .fontWeight(.medium)
                .lineLimit(1)
                .opacity(animateLabels ? 1 : 0)
                .blur(radius: animateLabels ? 0 : 4)
        }
        .visualEffect({ [animateContent] content, proxy in
            content
                .offset(
                    x: animateContent ? 0 : sourceLocation.minX - proxy.frame(in: .global).minX,
                    y: animateContent ? 0 : sourceLocation.minY - proxy.frame(in: .global).minY
                )
        })
        .frame(height: 70)
        .contentShape(.rect)
        .onTapGesture {
            action.action()
        }
    }
}

struct AttachmentMenuButton<Content: View>: View {
    @Binding var config: AttachmentMenuConfig
    @ViewBuilder var content: Content
    var onTap: () -> Void

    var body: some View {
        content
            .contentShape(.rect)
            .onTapGesture {
                onTap()
                config.sourceView = .init(content)
                config.showMenu.toggle()
            }
            .onGeometryChange(for: CGRect.self) {
                $0.frame(in: .global)
            } action: { newValue in
                config.sourceLocation = newValue
            }
            .opacity(config.hideSourceView ? 0.01 : 1)
    }
}

struct AttachmentMenuConfig {
    var symbolImage: String
    var sourceLocation: CGRect = .zero
    var showMenu: Bool = false
    var sourceView: AnyView = .init(EmptyView())
    var hideSourceView: Bool = false
}

struct AttachmentMenuAction: Identifiable {
    let id = UUID().uuidString
    var symbolImage: String
    var text: String
    var action: () -> Void = {}
}

@resultBuilder
struct AttachmentMenuActionBuilder {
    static func buildBlock(_ components: AttachmentMenuAction...) -> [AttachmentMenuAction] {
        components
    }
}

