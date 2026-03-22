import Flutter
import SwiftUI
import UIKit

class iOS26ActionGroupViewFactory: NSObject, FlutterPlatformViewFactory {
    private let messenger: FlutterBinaryMessenger

    init(messenger: FlutterBinaryMessenger) {
        self.messenger = messenger
        super.init()
    }

    func create(
        withFrame frame: CGRect,
        viewIdentifier viewId: Int64,
        arguments args: Any?
    ) -> FlutterPlatformView {
        iOS26ActionGroupView(
            frame: frame,
            viewIdentifier: viewId,
            arguments: args,
            binaryMessenger: messenger
        )
    }

    func createArgsCodec() -> FlutterMessageCodec & NSObjectProtocol {
        FlutterStandardMessageCodec.sharedInstance()
    }
}

class iOS26ActionGroupView: NSObject, FlutterPlatformView {
    private let containerView: UIView
    private let channel: FlutterMethodChannel
    private var items: [[String: Any]] = []
    private var foregroundColor: UIColor?
    private var isDark: Bool = false
    private var buttonHeight: CGFloat = 36
    private var iconButtonWidth: CGFloat = 40
    private var textButtonWidth: CGFloat = 68
    private var iconSize: CGFloat = 18
    private var itemSpacing: CGFloat = 0
    private var showDividers: Bool = true
    private var horizontalPadding: CGFloat = 12
    private var hostingController: UIViewController?

    init(
        frame: CGRect,
        viewIdentifier viewId: Int64,
        arguments args: Any?,
        binaryMessenger messenger: FlutterBinaryMessenger
    ) {
        containerView = UIView(frame: frame)
        channel = FlutterMethodChannel(
            name: "adaptive_platform_ui/ios26_action_group_\(viewId)",
            binaryMessenger: messenger
        )

        super.init()

        if let params = args as? [String: Any] {
            if let parsedItems = params["items"] as? [[String: Any]] {
                items = parsedItems
            }
            if let argb = params["foregroundColor"] as? Int {
                foregroundColor = UIColor(argb: argb)
            }
            isDark = params["isDark"] as? Bool ?? false
            if let value = params["buttonHeight"] as? Double {
                buttonHeight = CGFloat(value)
            }
            if let value = params["iconButtonWidth"] as? Double {
                iconButtonWidth = CGFloat(value)
            }
            if let value = params["textButtonWidth"] as? Double {
                textButtonWidth = CGFloat(value)
            }
            if let value = params["iconSize"] as? Double {
                iconSize = CGFloat(value)
            }
            if let value = params["itemSpacing"] as? Double {
                itemSpacing = CGFloat(value)
            }
            showDividers = params["showDividers"] as? Bool ?? true
            if let value = params["horizontalPadding"] as? Double {
                horizontalPadding = CGFloat(value)
            }
        }

        setupContainer()
    }

    func view() -> UIView {
        containerView
    }

    private func setupContainer() {
        containerView.backgroundColor = .clear
        containerView.isOpaque = false

        if #available(iOS 13.0, *) {
            containerView.overrideUserInterfaceStyle = isDark ? .dark : .light
        }

        if #available(iOS 26.0, *) {
            let rootView = IOS26ActionGroupRootView(
                items: items,
                foregroundColor: foregroundColor.map { Color(uiColor: $0) },
                buttonHeight: buttonHeight,
                iconButtonWidth: iconButtonWidth,
                textButtonWidth: textButtonWidth,
                iconSize: iconSize,
                itemSpacing: itemSpacing,
                showDividers: showDividers,
                horizontalPadding: horizontalPadding
            ) { [weak self] index in
                self?.channel.invokeMethod("onItemTapped", arguments: ["index": index])
            }

            let hostingController = UIHostingController(rootView: rootView)
            self.hostingController = hostingController

            let hostedView = hostingController.view!
            hostedView.translatesAutoresizingMaskIntoConstraints = false
            hostedView.backgroundColor = .clear
            hostedView.isOpaque = false

            containerView.addSubview(hostedView)
            NSLayoutConstraint.activate([
                hostedView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
                hostedView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
                hostedView.topAnchor.constraint(equalTo: containerView.topAnchor),
                hostedView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor),
            ])
            return
        }

        setupFallbackView()
    }

    private func setupFallbackView() {
        let blurView: UIVisualEffectView
        if #available(iOS 13.0, *) {
            blurView = UIVisualEffectView(effect: UIBlurEffect(style: .systemUltraThinMaterial))
            blurView.contentView.backgroundColor = UIColor.white.withAlphaComponent(isDark ? 0.03 : 0.08)
        } else {
            blurView = UIVisualEffectView(effect: UIBlurEffect(style: .light))
        }

        blurView.translatesAutoresizingMaskIntoConstraints = false
        blurView.clipsToBounds = true
        blurView.layer.cornerRadius = 24
        if #available(iOS 13.0, *) {
            blurView.layer.cornerCurve = .continuous
        }

        let stackView = UIStackView()
        stackView.translatesAutoresizingMaskIntoConstraints = false
        stackView.axis = .horizontal
        stackView.alignment = .center
        stackView.spacing = showDividers ? 0 : itemSpacing

        containerView.addSubview(blurView)
        blurView.contentView.addSubview(stackView)

        NSLayoutConstraint.activate([
            blurView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            blurView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            blurView.topAnchor.constraint(equalTo: containerView.topAnchor),
            blurView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor),
            stackView.leadingAnchor.constraint(equalTo: blurView.contentView.leadingAnchor, constant: horizontalPadding),
            stackView.trailingAnchor.constraint(equalTo: blurView.contentView.trailingAnchor, constant: -horizontalPadding),
            stackView.topAnchor.constraint(equalTo: blurView.contentView.topAnchor, constant: 6),
            stackView.bottomAnchor.constraint(equalTo: blurView.contentView.bottomAnchor, constant: -6),
        ])

        for (index, item) in items.enumerated() {
            stackView.addArrangedSubview(makeFallbackItemView(item: item, index: index))
            if index != items.count - 1 {
                let divider = UIView()
                divider.translatesAutoresizingMaskIntoConstraints = false
                divider.backgroundColor = (foregroundColor ?? .label).withAlphaComponent(isDark ? 0.18 : 0.24)
                NSLayoutConstraint.activate([
                    divider.widthAnchor.constraint(equalToConstant: 0.5),
                    divider.heightAnchor.constraint(equalToConstant: 22),
                ])
                stackView.addArrangedSubview(divider)
            }
        }
    }

    private func makeFallbackItemView(item: [String: Any], index: Int) -> UIView {
        let loading = item["loading"] as? Bool ?? false
        let enabled = item["enabled"] as? Bool ?? true

        if loading {
            let container = UIView()
            container.translatesAutoresizingMaskIntoConstraints = false
            let indicator = UIActivityIndicatorView(style: .medium)
            indicator.translatesAutoresizingMaskIntoConstraints = false
            indicator.color = foregroundColor ?? .label
            indicator.startAnimating()
            container.addSubview(indicator)
            NSLayoutConstraint.activate([
                container.widthAnchor.constraint(equalToConstant: iconButtonWidth),
                container.heightAnchor.constraint(equalToConstant: buttonHeight),
                indicator.centerXAnchor.constraint(equalTo: container.centerXAnchor),
                indicator.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            ])
            return container
        }

        let button = UIButton(type: .system)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.tag = index
        button.tintColor = foregroundColor ?? .label
        button.isEnabled = enabled

        if #available(iOS 15.0, *) {
            var config = UIButton.Configuration.plain()
            config.baseForegroundColor = foregroundColor ?? .label
            config.contentInsets = NSDirectionalEdgeInsets(top: 8, leading: 10, bottom: 8, trailing: 10)

            if let title = item["title"] as? String, !title.isEmpty {
                config.title = title
                var attributedTitle = AttributedString(title)
                attributedTitle.font = .systemFont(ofSize: 15, weight: .semibold)
                config.attributedTitle = attributedTitle
            } else if let icon = item["icon"] as? String,
                      let image = UIImage(systemName: icon)?.applyingSymbolConfiguration(
                        UIImage.SymbolConfiguration(pointSize: iconSize, weight: .semibold)
                      ) {
                config.image = image
            }

            button.configuration = config
        } else {
            if let title = item["title"] as? String, !title.isEmpty {
                button.setTitle(title, for: .normal)
            } else if let icon = item["icon"] as? String {
                button.setImage(UIImage(systemName: icon), for: .normal)
            }
        }

        button.addTarget(self, action: #selector(itemTapped(_:)), for: .touchUpInside)

        let hasTitle = (item["title"] as? String)?.isEmpty == false
        NSLayoutConstraint.activate([
            button.heightAnchor.constraint(equalToConstant: buttonHeight),
            button.widthAnchor.constraint(equalToConstant: hasTitle ? textButtonWidth : iconButtonWidth),
        ])

        return button
    }

    @objc private func itemTapped(_ sender: UIButton) {
        channel.invokeMethod("onItemTapped", arguments: ["index": sender.tag])
    }
}

@available(iOS 26.0, *)
private struct IOS26ActionGroupRootView: View {
    let items: [[String: Any]]
    let foregroundColor: Color?
    let buttonHeight: CGFloat
    let iconButtonWidth: CGFloat
    let textButtonWidth: CGFloat
    let iconSize: CGFloat
    let itemSpacing: CGFloat
    let showDividers: Bool
    let horizontalPadding: CGFloat
    let onTap: (Int) -> Void

    @Namespace private var glassNamespace

    private let unionId = "adaptive_action_group_union"

    var body: some View {
        GlassEffectContainer(spacing: showDividers ? 0 : itemSpacing) {
            HStack(spacing: showDividers ? 0 : itemSpacing) {
                ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                    itemView(item, index: index)
                    if showDividers && index != items.count - 1 {
                        Rectangle()
                            .fill((foregroundColor ?? .primary).opacity(0.22))
                            .frame(width: 0.5, height: 22)
                    }
                }
            }
            .padding(.horizontal, horizontalPadding)
            .padding(.vertical, 6)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.clear)
    }

    @ViewBuilder
    private func itemView(_ item: [String: Any], index: Int) -> some View {
        let isLoading = item["loading"] as? Bool ?? false
        let isEnabled = item["enabled"] as? Bool ?? true

        if isLoading {
            ProgressView()
                .tint(foregroundColor ?? .primary)
                .frame(width: iconButtonWidth, height: buttonHeight)
                .glassEffect()
                .glassEffectUnion(id: unionId, namespace: glassNamespace)
        } else {
            Button {
                onTap(index)
            } label: {
                Group {
                    if let title = item["title"] as? String, !title.isEmpty {
                        Text(title)
                            .font(.system(size: 15, weight: .semibold))
                            .lineLimit(1)
                    } else if let icon = item["icon"] as? String, !icon.isEmpty {
                        Image(systemName: icon)
                            .font(.system(size: iconSize, weight: .semibold))
                    }
                }
                .foregroundStyle(foregroundColor ?? .primary)
                .frame(width: itemWidth(item), height: buttonHeight)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(!isEnabled)
            .opacity(isEnabled ? 1 : 0.45)
            .glassEffect()
            .glassEffectUnion(id: unionId, namespace: glassNamespace)
        }
    }

    private func itemWidth(_ item: [String: Any]) -> CGFloat {
        if let title = item["title"] as? String, !title.isEmpty {
            return textButtonWidth
        }
        return iconButtonWidth
    }
}
