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
        _ = DeepLinkHandler.shared.applicationDidOpenUrl(context.url,
                                                         openInPlace: context.options.openInPlace)
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

    // GoTr-Ail V25 native iOS shell.
    // Organic Maps remains the map/offline engine underneath.
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
      _ = DeepLinkHandler.shared.applicationDidOpenUrl(context.url,
                                                       openInPlace: context.options.openInPlace)
    }
  }

  func scene(_: UIScene, continue userActivity: NSUserActivity) {
    _ = MapsAppDelegate.theApp().handleUserActivity(userActivity)
  }

  func windowScene(_: UIWindowScene,
                   performActionFor shortcutItem: UIApplicationShortcutItem,
                   completionHandler: @escaping (Bool) -> Void) {
    MapsAppDelegate.theApp().handleShortcutItem(shortcutItem,
                                                completionHandler: completionHandler)
  }
}

// MARK: - GoTr-Ail V25 Home

private final class GoTrailHomeViewController: UIViewController {
  private let blue = UIColor(red: 11.0 / 255.0,
                             green: 95.0 / 255.0,
                             blue: 215.0 / 255.0,
                             alpha: 1.0)

  private let green = UIColor(red: 32.0 / 255.0,
                              green: 168.0 / 255.0,
                              blue: 90.0 / 255.0,
                              alpha: 1.0)

  private let navy = UIColor(red: 7.0 / 255.0,
                             green: 23.0 / 255.0,
                             blue: 37.0 / 255.0,
                             alpha: 1.0)

  override var preferredStatusBarStyle: UIStatusBarStyle {
    .lightContent
  }

  override func viewDidLoad() {
    super.viewDidLoad()
    buildInterface()
  }

  private func buildInterface() {
    view.backgroundColor = navy

    let mountain = UILabel()
    mountain.translatesAutoresizingMaskIntoConstraints = false
    mountain.text = "▲"
    mountain.textAlignment = .center
    mountain.textColor = UIColor.white.withAlphaComponent(0.07)
    mountain.font = .systemFont(ofSize: 300, weight: .black)
    view.addSubview(mountain)

    let page = UIStackView()
    page.translatesAutoresizingMaskIntoConstraints = false
    page.axis = .vertical
    page.spacing = 10
    view.addSubview(page)

    page.addArrangedSubview(makeHeader())

    let hero = UILabel()
    hero.numberOfLines = 0
    hero.text = "La montagna,\npiù semplice."
    hero.textColor = .white
    hero.font = .systemFont(ofSize: 36, weight: .bold)
    page.addArrangedSubview(hero)

    let subtitle = UILabel()
    subtitle.numberOfLines = 0
    subtitle.text = "Rifugi, cascate, fontane e punti interessanti. Tutto sulla mappa offline."
    subtitle.textColor = UIColor.white.withAlphaComponent(0.82)
    subtitle.font = .systemFont(ofSize: 15, weight: .medium)
    page.addArrangedSubview(subtitle)

    let spacer = UIView()
    spacer.setContentHuggingPriority(.defaultLow, for: .vertical)
    page.addArrangedSubview(spacer)

    page.addArrangedSubview(makeButton(title: "INIZIA",
                                       subtitle: "Apri la mappa dalla tua posizione",
                                       symbol: "location.fill",
                                       color: green))

    page.addArrangedSubview(makeButton(title: "ANALIZZA ZONA",
                                       subtitle: "Cerca rifugi, cascate, fontane e POI",
                                       symbol: "binoculars.fill",
                                       color: blue))

    page.addArrangedSubview(makeButton(title: "MAPPE",
                                       subtitle: "Gestisci le mappe offline",
                                       symbol: "map.fill",
                                       color: UIColor(red: 0.10,
                                                      green: 0.35,
                                                      blue: 0.55,
                                                      alpha: 1.0)))

    let saved = UIButton(type: .system)
    saved.setTitle("★   PERCORSI SALVATI", for: .normal)
    saved.setTitleColor(UIColor(red: 23.0 / 255.0,
                               green: 44.0 / 255.0,
                               blue: 67.0 / 255.0,
                               alpha: 1.0),
                        for: .normal)
    saved.titleLabel?.font = .systemFont(ofSize: 13, weight: .bold)
    saved.backgroundColor = .white
    saved.layer.cornerRadius = 15
    saved.heightAnchor.constraint(equalToConstant: 46).isActive = true
    saved.addTarget(self, action: #selector(openMap), for: .touchUpInside)
    page.addArrangedSubview(saved)

    NSLayoutConstraint.activate([
      page.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 18),
      page.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -18),
      page.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 18),
      page.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -18),

      mountain.centerXAnchor.constraint(equalTo: view.centerXAnchor),
      mountain.centerYAnchor.constraint(equalTo: view.centerYAnchor, constant: -40)
    ])
  }

  private func makeHeader() -> UIView {
    let row = UIStackView()
    row.axis = .horizontal
    row.alignment = .center
    row.spacing = 10

    let logo = UILabel()
    logo.translatesAutoresizingMaskIntoConstraints = false
    logo.text = "▲"
    logo.textAlignment = .center
    logo.textColor = blue
    logo.font = .systemFont(ofSize: 25, weight: .bold)
    logo.backgroundColor = UIColor.white.withAlphaComponent(0.96)
    logo.layer.cornerRadius = 15
    logo.clipsToBounds = true
    NSLayoutConstraint.activate([
      logo.widthAnchor.constraint(equalToConstant: 50),
      logo.heightAnchor.constraint(equalToConstant: 50)
    ])
    row.addArrangedSubview(logo)

    let titles = UIStackView()
    titles.axis = .vertical
    titles.spacing = 0

    let title = UILabel()
    title.text = "GoTr-Ail"
    title.textColor = .white
    title.font = .systemFont(ofSize: 28, weight: .bold)
    titles.addArrangedSubview(title)

    let subtitle = UILabel()
    subtitle.text = "Il tuo accompagnatore nei sentieri"
    subtitle.textColor = UIColor(red: 234.0 / 255.0,
                                 green: 244.0 / 255.0,
                                 blue: 1.0,
                                 alpha: 1.0)
    subtitle.font = .systemFont(ofSize: 12, weight: .bold)
    titles.addArrangedSubview(subtitle)

    row.addArrangedSubview(titles)

    let version = UILabel()
    version.text = "v.25"
    version.textColor = .white
    version.font = .systemFont(ofSize: 15, weight: .bold)
    row.addArrangedSubview(version)

    return row
  }

  private func makeButton(title: String,
                          subtitle: String,
                          symbol: String,
                          color: UIColor) -> UIButton {
    let button = UIButton(type: .system)
    button.backgroundColor = color
    button.layer.cornerRadius = 17
    button.heightAnchor.constraint(equalToConstant: 66).isActive = true
    button.addTarget(self, action: #selector(openMap), for: .touchUpInside)

    let icon = UIImageView(image: UIImage(systemName: symbol))
    icon.translatesAutoresizingMaskIntoConstraints = false
    icon.tintColor = .white
    icon.contentMode = .scaleAspectFit
    icon.backgroundColor = UIColor.white.withAlphaComponent(0.16)
    icon.layer.cornerRadius = 20
    icon.clipsToBounds = true

    let labels = UIStackView()
    labels.translatesAutoresizingMaskIntoConstraints = false
    labels.axis = .vertical
    labels.spacing = 1
    labels.isUserInteractionEnabled = false

    let main = UILabel()
    main.text = title
    main.textColor = .white
    main.font = .systemFont(ofSize: 16, weight: .bold)
    labels.addArrangedSubview(main)

    let detail = UILabel()
    detail.text = subtitle
    detail.textColor = .white
    detail.font = .systemFont(ofSize: 11, weight: .bold)
    detail.adjustsFontSizeToFitWidth = true
    detail.minimumScaleFactor = 0.75
    labels.addArrangedSubview(detail)

    let arrow = UIImageView(image: UIImage(systemName: "chevron.right"))
    arrow.translatesAutoresizingMaskIntoConstraints = false
    arrow.tintColor = .white
    arrow.contentMode = .scaleAspectFit

    button.addSubview(icon)
    button.addSubview(labels)
    button.addSubview(arrow)

    NSLayoutConstraint.activate([
      icon.leadingAnchor.constraint(equalTo: button.leadingAnchor, constant: 13),
      icon.centerYAnchor.constraint(equalTo: button.centerYAnchor),
      icon.widthAnchor.constraint(equalToConstant: 40),
      icon.heightAnchor.constraint(equalToConstant: 40),

      labels.leadingAnchor.constraint(equalTo: icon.trailingAnchor, constant: 11),
      labels.centerYAnchor.constraint(equalTo: button.centerYAnchor),
      labels.trailingAnchor.constraint(lessThanOrEqualTo: arrow.leadingAnchor, constant: -8),

      arrow.trailingAnchor.constraint(equalTo: button.trailingAnchor, constant: -14),
      arrow.centerYAnchor.constraint(equalTo: button.centerYAnchor),
      arrow.widthAnchor.constraint(equalToConstant: 12),
      arrow.heightAnchor.constraint(equalToConstant: 20)
    ])

    return button
  }

  @objc private func openMap() {
    dismiss(animated: true)
  }
}
