import UIKit

@objc(MainSceneDelegate)
final class MainSceneDelegate: UIResponder, UIWindowSceneDelegate {
  var window: UIWindow? {
    get { MapsAppDelegate.theApp().window }
    set { MapsAppDelegate.theApp().window = newValue }
  }

  func scene(_ scene: UIScene,
             willConnectTo _: UISceneSession,
             options connectionOptions: UIScene.ConnectionOptions) {
    guard let windowScene = scene as? UIWindowScene else {
      assertionFailure("Main scene is not a UIWindowScene.")
      return
    }

    let app = MapsAppDelegate.theApp()
    let sceneWindow = UIWindow(windowScene: windowScene)
    window = sceneWindow
    sceneWindow.rootViewController = app.mainNavigationController

    for context in connectionOptions.urlContexts {
      if context.url.isFileURL {
        _ = DeepLinkHandler.shared.applicationDidOpenUrl(
          context.url, openInPlace: context.options.openInPlace)
      } else if !CarPlayService.shared.handleOpenCarPlayURL(context.url) {
        DeepLinkHandler.shared.prepareForColdLaunch(url: context.url)
      }
    }

    for userActivity in connectionOptions.userActivities
      where userActivity.activityType == NSUserActivityTypeBrowsingWeb {
      if let url = userActivity.webpageURL {
        DeepLinkHandler.shared.prepareForColdLaunch(universalLink: url)
      }
    }

    ThemeManager.invalidate()
    sceneWindow.makeKeyAndVisible()
    CarPlayService.shared.phoneSceneDidConnect()

    // GoTr-Ail V32.6: Home nativa sopra il core Organic Maps.
    DispatchQueue.main.async {
      guard app.mainNavigationController.presentedViewController == nil else { return }
      let home = GoTrailHomeViewController()
      home.modalPresentationStyle = .fullScreen
      home.modalTransitionStyle = .crossDissolve
      app.mainNavigationController.present(home, animated: false)
    }

    for userActivity in connectionOptions.userActivities
      where userActivity.activityType != NSUserActivityTypeBrowsingWeb || userActivity.webpageURL == nil {
      self.scene(scene, continue: userActivity)
    }

    if let shortcutItem = connectionOptions.shortcutItem {
      self.windowScene(windowScene,
                       performActionFor: shortcutItem,
                       completionHandler: { _ in })
    }
  }

  func sceneDidDisconnect(_: UIScene) {
    CarPlayService.shared.phoneSceneDidDisconnect()
    window = nil
  }

  func scene(_: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {
    for context in URLContexts where !CarPlayService.shared.handleOpenCarPlayURL(context.url) {
      _ = DeepLinkHandler.shared.applicationDidOpenUrl(
        context.url, openInPlace: context.options.openInPlace)
    }
  }

  func scene(_: UIScene, continue userActivity: NSUserActivity) {
    _ = MapsAppDelegate.theApp().handleUserActivity(userActivity)
  }

  func windowScene(_: UIWindowScene,
                   performActionFor shortcutItem: UIApplicationShortcutItem,
                   completionHandler: @escaping (Bool) -> Void) {
    MapsAppDelegate.theApp().handleShortcutItem(
      shortcutItem, completionHandler: completionHandler)
  }
}

// MARK: - GoTr-Ail V32.6 Home

private final class GoTrailHomeViewController: UIViewController {
  private let sky = UIColor(red: 56.0 / 255.0,
                            green: 126.0 / 255.0,
                            blue: 203.0 / 255.0,
                            alpha: 1.0)

  private let forest = UIColor(red: 18.0 / 255.0,
                               green: 42.0 / 255.0,
                               blue: 45.0 / 255.0,
                               alpha: 1.0)

  private let green = UIColor(red: 32.0 / 255.0,
                              green: 168.0 / 255.0,
                              blue: 90.0 / 255.0,
                              alpha: 1.0)

  private let blue = UIColor(red: 11.0 / 255.0,
                             green: 95.0 / 255.0,
                             blue: 215.0 / 255.0,
                             alpha: 1.0)

  private let darkText = UIColor(red: 23.0 / 255.0,
                                 green: 44.0 / 255.0,
                                 blue: 67.0 / 255.0,
                                 alpha: 1.0)

  override var preferredStatusBarStyle: UIStatusBarStyle { .lightContent }

  override func viewDidLoad() {
    super.viewDidLoad()
    buildInterface()
  }

  private func buildInterface() {
    view.backgroundColor = forest

    let scenery = UIStackView()
    scenery.translatesAutoresizingMaskIntoConstraints = false
    scenery.axis = .vertical
    scenery.spacing = 0
    view.addSubview(scenery)

    let skyFill = UIView()
    skyFill.backgroundColor = sky
    scenery.addArrangedSubview(skyFill)

    let mountain = UIImageView(image: UIImage(named: "gotrail_home_pelmo"))
    mountain.contentMode = .scaleToFill
    mountain.clipsToBounds = true
    scenery.addArrangedSubview(mountain)

    let forestFill = UIView()
    forestFill.backgroundColor = forest
    scenery.addArrangedSubview(forestFill)

    let page = UIStackView()
    page.translatesAutoresizingMaskIntoConstraints = false
    page.axis = .vertical
    page.spacing = 8
    view.addSubview(page)

    page.addArrangedSubview(makeHeader())

    let spacer = UIView()
    spacer.setContentHuggingPriority(.defaultLow, for: .vertical)
    spacer.setContentCompressionResistancePriority(.defaultLow, for: .vertical)
    page.addArrangedSubview(spacer)

    page.addArrangedSubview(makeAction(title: "INIZIA", color: green) {
      self.dismiss(animated: true)
    })
    page.addArrangedSubview(makeAction(title: "GESTIONE MAPPE", color: blue) {
      self.dismiss(animated: true)
    })
    page.addArrangedSubview(makeAction(title: "PERCORSI SALVATI", color: .white, textColor: darkText) {
      self.dismiss(animated: true)
    })

    NSLayoutConstraint.activate([
      scenery.leadingAnchor.constraint(equalTo: view.leadingAnchor),
      scenery.trailingAnchor.constraint(equalTo: view.trailingAnchor),
      scenery.topAnchor.constraint(equalTo: view.topAnchor),
      scenery.bottomAnchor.constraint(equalTo: view.bottomAnchor),

      skyFill.heightAnchor.constraint(equalTo: scenery.heightAnchor, multiplier: 0.23),
      mountain.heightAnchor.constraint(equalTo: scenery.heightAnchor, multiplier: 0.52),
      forestFill.heightAnchor.constraint(equalTo: scenery.heightAnchor, multiplier: 0.25),

      page.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
      page.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
      page.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 16),
      page.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -18)
    ])
  }

  private func makeHeader() -> UIView {
    let container = UIView()
    container.translatesAutoresizingMaskIntoConstraints = false
    container.heightAnchor.constraint(equalToConstant: 72).isActive = true

    let title = UILabel()
    title.translatesAutoresizingMaskIntoConstraints = false
    title.text = "GoTr-Ail"
    title.textColor = .white
    title.font = .systemFont(ofSize: 30, weight: .bold)

    let subtitle = UILabel()
    subtitle.translatesAutoresizingMaskIntoConstraints = false
    subtitle.text = "Il tuo accompagnatore nei sentieri"
    subtitle.textColor = UIColor.white.withAlphaComponent(0.94)
    subtitle.font = .systemFont(ofSize: 13, weight: .bold)

    let version = UILabel()
    version.translatesAutoresizingMaskIntoConstraints = false
    version.text = "v.32.6"
    version.textColor = .white
    version.font = .systemFont(ofSize: 14, weight: .bold)

    container.addSubview(title)
    container.addSubview(subtitle)
    container.addSubview(version)

    NSLayoutConstraint.activate([
      title.leadingAnchor.constraint(equalTo: container.leadingAnchor),
      title.topAnchor.constraint(equalTo: container.topAnchor),
      title.trailingAnchor.constraint(lessThanOrEqualTo: version.leadingAnchor, constant: -8),

      subtitle.leadingAnchor.constraint(equalTo: container.leadingAnchor),
      subtitle.topAnchor.constraint(equalTo: title.bottomAnchor, constant: 3),

      version.trailingAnchor.constraint(equalTo: container.trailingAnchor),
      version.topAnchor.constraint(equalTo: container.topAnchor)
    ])

    return container
  }

  private func makeAction(title: String,
                          color: UIColor,
                          textColor: UIColor = .white,
                          action: @escaping () -> Void) -> UIButton {
    let button = UIButton(type: .system)
    button.backgroundColor = color
    button.layer.cornerRadius = 17
    button.layer.masksToBounds = true
    button.heightAnchor.constraint(equalToConstant: 52).isActive = true
    button.setTitle(title, for: .normal)
    button.setTitleColor(textColor, for: .normal)
    button.titleLabel?.font = .systemFont(ofSize: 16, weight: .bold)
    button.addAction(UIAction { _ in action() }, for: .touchUpInside)
    return button
  }
}
