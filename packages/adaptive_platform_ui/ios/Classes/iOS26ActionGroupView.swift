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
    private var foregroundColor: UIColor = .white
    private var isDark: Bool = false
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
                foregroundColor: Color(uiColor: foregroundColor)
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
        stackView.spacing = 0

        containerView.addSubview(blurView)
        blurView.contentView.addSubview(stackView)

        NSLayoutConstraint.activate([
            blurView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            blurView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            blurView.topAnchor.constraint(equalTo: containerView.topAnchor),
            blurView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor),
            stackView.leadingAnchor.constraint(equalTo: blurView.contentView.leadingAnchor, constant: 12),
            stackView.trailingAnchor.constraint(equalTo: blurView.contentView.trailingAnchor, constant: -12),
            stackView.topAnchor.constraint(equalTo: blurView.contentView.topAnchor, constant: 6),
            stackView.bottomAnchor.constraint(equalTo: blurView.contentView.bottomAnchor, constant: -6),
        ])

        for (index, item) in items.enumerated() {
            stackView.addArrangedSubview(makeFallbackItemView(item: item, index: index))
            if index != items.count - 1 {
                let divider = UIView()
                divider.translatesAutoresizingMaskIntoConstraints = false
                divider.backgroundColor = foregroundColor.withAlphaComponent(isDark ? 0.18 : 0.24)
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
            indicator.color = foregroundColor
            indicator.startAnimating()
            container.addSubview(indicator)
            NSLayoutConstraint.activate([
                container.widthAnchor.constraint(equalToConstant: 40),
                container.heightAnchor.constraint(equalToConstant: 36),
                indicator.centerXAnchor.constraint(equalTo: container.centerXAnchor),
                indicator.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            ])
            return container
        }

        let button = UIButton(type: .system)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.tag = index
        button.tintColor = foregroundColor
        button.isEnabled = enabled

        if #available(iOS 15.0, *) {
            var config = UIButton.Configuration.plain()
            config.baseForegroundColor = foregroundColor
            config.contentInsets = NSDirectionalEdgeInsets(top: 8, leading: 10, bottom: 8, trailing: 10)

            if let title = item["title"] as? String, !title.isEmpty {
                config.title = title
                var attributedTitle = AttributedString(title)
                attributedTitle.font = .systemFont(ofSize: 15, weight: .semibold)
                config.attributedTitle = attributedTitle
            } else if let icon = item["icon"] as? String,
                      let image = UIImage(systemName: icon)?.applyingSymbolConfiguration(
                        UIImage.SymbolConfiguration(pointSize: 18, weight: .semibold)
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
            button.heightAnchor.constraint(equalToConstant: 36),
            button.widthAnchor.constraint(equalToConstant: hasTitle ? 68 : 40),
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
    let foregroundColor: Color
    let onTap: (Int) -> Void

    @Namespace private var glassNamespace

    private let unionId = "adaptive_action_group_union"
    private let containerSpacing: CGFloat = 24
    private let itemSpacing: CGFloat = 8

    var body: some View {
        GlassEffectContainer(spacing: containerSpacing) {
            HStack(spacing: itemSpacing) {
                ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                    itemView(item, index: index)
                }
            }
            .padding(.horizontal, 6)
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
                .tint(foregroundColor)
                .frame(width: 40, height: 36)
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
                            .font(.system(size: 18, weight: .semibold))
                    }
                }
                .foregroundStyle(foregroundColor)
                .frame(width: itemWidth(item), height: 36)
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
            return 68
        }
        return 40
    }
}
