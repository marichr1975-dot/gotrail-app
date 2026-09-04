import UIKit
import CoreLocation

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

    let sceneWindow = UIWindow(windowScene: windowScene)
    window = sceneWindow

    // GoTr-Ail V30.10.1 is the real application root.
    sceneWindow.rootViewController = GoTrailHomeViewController()

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

// MARK: - GoTr-Ail root coordinator

@objcMembers
final class GoTrailRootCoordinator: NSObject {
  static func showHome() {
    guard let window = MapsAppDelegate.theApp().window else { return }
    window.rootViewController = GoTrailHomeViewController()
  }

  static func showMap() {
    guard let window = MapsAppDelegate.theApp().window else { return }
    window.rootViewController = GoTrailMapHostViewController()
  }
}

// MARK: - Home V30.10.1

final class GoTrailHomeViewController: UIViewController {
  private let blue = UIColor(red: 11.0 / 255.0, green: 95.0 / 255.0, blue: 215.0 / 255.0, alpha: 1.0)
  private let green = UIColor(red: 32.0 / 255.0, green: 168.0 / 255.0, blue: 90.0 / 255.0, alpha: 1.0)
  private let darkText = UIColor(red: 23.0 / 255.0, green: 44.0 / 255.0, blue: 67.0 / 255.0, alpha: 1.0)

  override var preferredStatusBarStyle: UIStatusBarStyle { .lightContent }

  override func viewDidLoad() {
    super.viewDidLoad()
    buildInterface()
  }

  private func buildInterface() {
    view.backgroundColor = UIColor(red: 7.0 / 255.0, green: 23.0 / 255.0, blue: 37.0 / 255.0, alpha: 1.0)

    let background = UIImageView(image: UIImage(named: "gotrail_home_pelmo"))
    background.translatesAutoresizingMaskIntoConstraints = false
    background.contentMode = .scaleAspectFill
    background.clipsToBounds = true
    view.addSubview(background)

    let shade = GradientView()
    shade.translatesAutoresizingMaskIntoConstraints = false
    shade.colors = [
      UIColor(red: 0, green: 8.0 / 255.0, blue: 24.0 / 255.0, alpha: 0.13),
      UIColor(red: 0, green: 8.0 / 255.0, blue: 24.0 / 255.0, alpha: 0.40),
      UIColor(red: 7.0 / 255.0, green: 23.0 / 255.0, blue: 37.0 / 255.0, alpha: 0.94)
    ]
    view.addSubview(shade)

    let page = UIStackView()
    page.translatesAutoresizingMaskIntoConstraints = false
    page.axis = .vertical
    page.spacing = 10
    view.addSubview(page)

    let titleRow = UIStackView()
    titleRow.axis = .horizontal
    titleRow.alignment = .center

    let title = UILabel()
    title.text = "GoTr-Ail"
    title.textColor = .white
    title.font = .systemFont(ofSize: 30, weight: .bold)
    titleRow.addArrangedSubview(title)

    let version = UILabel()
    version.text = "v.30.10.1"
    version.textColor = .white
    version.font = .systemFont(ofSize: 14, weight: .bold)
    version.textAlignment = .right
    titleRow.addArrangedSubview(version)
    title.setContentHuggingPriority(.defaultLow, for: .horizontal)
    version.setContentHuggingPriority(.required, for: .horizontal)
    page.addArrangedSubview(titleRow)

    let subtitle = UILabel()
    subtitle.text = "Il tuo accompagnatore nei sentieri"
    subtitle.textColor = UIColor(red: 234.0 / 255.0, green: 244.0 / 255.0, blue: 1.0, alpha: 1.0)
    subtitle.font = .systemFont(ofSize: 13, weight: .bold)
    page.addArrangedSubview(subtitle)

    let spacer = UIView()
    spacer.setContentHuggingPriority(.defaultLow, for: .vertical)
    page.addArrangedSubview(spacer)

    let start = makeButton(title: "INIZIA", fill: green, textColor: .white)
    start.addTarget(self, action: #selector(openMap), for: .touchUpInside)
    page.addArrangedSubview(start)

    let maps = makeButton(title: "GESTIONE MAPPE", fill: blue, textColor: .white)
    maps.addTarget(self, action: #selector(openMap), for: .touchUpInside)
    page.addArrangedSubview(maps)

    let saved = makeButton(title: "PERCORSI SALVATI", fill: .white, textColor: darkText)
    saved.addTarget(self, action: #selector(openMap), for: .touchUpInside)
    page.addArrangedSubview(saved)

    NSLayoutConstraint.activate([
      background.leadingAnchor.constraint(equalTo: view.leadingAnchor),
      background.trailingAnchor.constraint(equalTo: view.trailingAnchor),
      background.topAnchor.constraint(equalTo: view.topAnchor),
      background.bottomAnchor.constraint(equalTo: view.bottomAnchor),

      shade.leadingAnchor.constraint(equalTo: view.leadingAnchor),
      shade.trailingAnchor.constraint(equalTo: view.trailingAnchor),
      shade.topAnchor.constraint(equalTo: view.topAnchor),
      shade.bottomAnchor.constraint(equalTo: view.bottomAnchor),

      page.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 18),
      page.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -18),
      page.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 24),
      page.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -18)
    ])
  }

  private func makeButton(title: String, fill: UIColor, textColor: UIColor) -> UIButton {
    let button = UIButton(type: .system)
    button.setTitle(title, for: .normal)
    button.setTitleColor(textColor, for: .normal)
    button.titleLabel?.font = .systemFont(ofSize: 16, weight: .bold)
    button.backgroundColor = fill
    button.layer.cornerRadius = 17
    button.heightAnchor.constraint(equalToConstant: 58).isActive = true
    return button
  }

  @objc private func openMap() {
    GoTrailRootCoordinator.showMap()
  }
}

// MARK: - GoTr-Ail map host

final class GoTrailMapHostViewController: UIViewController {
  private let blue = UIColor(red: 11.0 / 255.0, green: 95.0 / 255.0, blue: 215.0 / 255.0, alpha: 1.0)
  private let green = UIColor(red: 32.0 / 255.0, green: 168.0 / 255.0, blue: 90.0 / 255.0, alpha: 1.0)

  private var organicController: UINavigationController?

  override func viewDidLoad() {
    super.viewDidLoad()
    view.backgroundColor = .black
    attachOrganicMap()
    buildGoTrailControls()
  }

  private func attachOrganicMap() {
    let nav = MapsAppDelegate.theApp().mainNavigationController
    organicController = nav

    addChild(nav)
    nav.view.translatesAutoresizingMaskIntoConstraints = false
    view.addSubview(nav.view)
    NSLayoutConstraint.activate([
      nav.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
      nav.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
      nav.view.topAnchor.constraint(equalTo: view.topAnchor),
      nav.view.bottomAnchor.constraint(equalTo: view.bottomAnchor)
    ])
    nav.didMove(toParent: self)
  }

  private func buildGoTrailControls() {
    let topBar = UIView()
    topBar.translatesAutoresizingMaskIntoConstraints = false
    topBar.backgroundColor = UIColor.white.withAlphaComponent(0.96)
    topBar.layer.cornerRadius = 16
    topBar.layer.shadowOpacity = 0.17
    topBar.layer.shadowRadius = 7
    topBar.layer.shadowOffset = CGSize(width: 0, height: 2)
    view.addSubview(topBar)

    let home = UIButton(type: .system)
    home.translatesAutoresizingMaskIntoConstraints = false
    home.setImage(UIImage(systemName: "house.fill"), for: .normal)
    home.tintColor = blue
    home.addTarget(self, action: #selector(goHome), for: .touchUpInside)
    topBar.addSubview(home)

    let label = UILabel()
    label.translatesAutoresizingMaskIntoConstraints = false
    label.text = "GoTr-Ail"
    label.textColor = UIColor(red: 23.0 / 255.0, green: 44.0 / 255.0, blue: 67.0 / 255.0, alpha: 1.0)
    label.font = .systemFont(ofSize: 18, weight: .bold)
    topBar.addSubview(label)

    let analyze = UIButton(type: .system)
    analyze.translatesAutoresizingMaskIntoConstraints = false
    analyze.setTitle("ANALIZZA", for: .normal)
    analyze.setTitleColor(.white, for: .normal)
    analyze.titleLabel?.font = .systemFont(ofSize: 15, weight: .bold)
    analyze.backgroundColor = green
    analyze.layer.cornerRadius = 16
    analyze.addTarget(self, action: #selector(openAnalyze), for: .touchUpInside)
    view.addSubview(analyze)

    NSLayoutConstraint.activate([
      topBar.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 12),
      topBar.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -12),
      topBar.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 8),
      topBar.heightAnchor.constraint(equalToConstant: 52),

      home.leadingAnchor.constraint(equalTo: topBar.leadingAnchor, constant: 10),
      home.centerYAnchor.constraint(equalTo: topBar.centerYAnchor),
      home.widthAnchor.constraint(equalToConstant: 40),
      home.heightAnchor.constraint(equalToConstant: 40),

      label.leadingAnchor.constraint(equalTo: home.trailingAnchor, constant: 8),
      label.centerYAnchor.constraint(equalTo: topBar.centerYAnchor),
      label.trailingAnchor.constraint(lessThanOrEqualTo: topBar.trailingAnchor, constant: -12),

      analyze.centerXAnchor.constraint(equalTo: view.centerXAnchor),
      analyze.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -14),
      analyze.widthAnchor.constraint(equalToConstant: 156),
      analyze.heightAnchor.constraint(equalToConstant: 52)
    ])
  }

  @objc private func goHome() {
    detachOrganicMap()
    GoTrailRootCoordinator.showHome()
  }

  @objc private func openAnalyze() {
    let controller = GoTrailAnalyzeViewController()
    controller.modalPresentationStyle = .fullScreen
    present(controller, animated: true)
  }

  private func detachOrganicMap() {
    guard let nav = organicController else { return }
    nav.willMove(toParent: nil)
    nav.view.removeFromSuperview()
    nav.removeFromParent()
    organicController = nil
  }
}

// MARK: - GoTr-Ail analysis V30.10.1

private enum GoTrailPoiCategory: String {
  case hut = "Rifugi"
  case waterfall = "Cascate"
  case parking = "Parcheggi"
  case interest = "Attrazioni"

  var markerID: String {
    switch self {
    case .hut: return "GOTRAIL_HUT"
    case .waterfall: return "GOTRAIL_WATERFALL"
    case .parking: return "GOTRAIL_PARKING"
    case .interest: return "GOTRAIL_INTEREST"
    }
  }

  var style: String {
    switch self {
    case .hut: return "placemark-orange"
    case .waterfall: return "placemark-cyan"
    case .parking: return "placemark-blue"
    case .interest: return "placemark-purple"
    }
  }

  var symbol: String {
    switch self {
    case .hut: return "house.fill"
    case .waterfall: return "drop.fill"
    case .parking: return "parkingsign.circle.fill"
    case .interest: return "paintpalette.fill"
    }
  }
}

private struct GoTrailIOSPoi {
  let title: String
  let category: GoTrailPoiCategory
  let coordinate: CLLocationCoordinate2D
  let distanceKm: Double
}

final class GoTrailAnalyzeViewController: UIViewController {
  private let darkText = UIColor(red: 23.0 / 255.0, green: 44.0 / 255.0, blue: 67.0 / 255.0, alpha: 1.0)
  private let green = UIColor(red: 32.0 / 255.0, green: 168.0 / 255.0, blue: 90.0 / 255.0, alpha: 1.0)
  private let blue = UIColor(red: 11.0 / 255.0, green: 95.0 / 255.0, blue: 215.0 / 255.0, alpha: 1.0)
  private let radiusKm = 5.0

  private let progress = UIProgressView(progressViewStyle: .default)
  private let progressPercent = UILabel()
  private let status = UILabel()
  private let countLabel = UILabel()
  private let resultsStack = UIStackView()
  private let showMapButton = UIButton(type: .system)
  private var categoryRows: [GoTrailPoiCategory: UILabel] = [:]

  private var searchService: CarPlaySearchService?
  private var found: [String: GoTrailIOSPoi] = [:]
  private var queryIndex = 0
  private var center = CLLocationCoordinate2D()

  private let searches: [(String, GoTrailPoiCategory)] = [
    ("rifugio", .hut),
    ("cascata", .waterfall), ("waterfall", .waterfall),
    ("parcheggio", .parking), ("parking", .parking),
    ("scultura", .interest), ("sculpture", .interest),
    ("statua", .interest), ("statue", .interest),
    ("artwork", .interest), ("opera d'arte", .interest),
    ("arte", .interest), ("installazione", .interest),
    ("installation", .interest), ("monumento", .interest),
    ("monument", .interest), ("attrazione", .interest),
    ("attraction", .interest)
  ]

  override func viewDidLoad() {
    super.viewDidLoad()
    buildInterface()
    startAnalysis()
  }

  private func buildInterface() {
    view.backgroundColor = UIColor(red: 247.0 / 255.0, green: 249.0 / 255.0, blue: 252.0 / 255.0, alpha: 1.0)

    let scroll = UIScrollView()
    scroll.translatesAutoresizingMaskIntoConstraints = false
    view.addSubview(scroll)

    let page = UIStackView()
    page.translatesAutoresizingMaskIntoConstraints = false
    page.axis = .vertical
    page.spacing = 12
    scroll.addSubview(page)

    let header = UIStackView()
    header.axis = .horizontal
    header.alignment = .center

    let back = UIButton(type: .system)
    back.setTitle("‹", for: .normal)
    back.titleLabel?.font = .systemFont(ofSize: 34, weight: .bold)
    back.addTarget(self, action: #selector(close), for: .touchUpInside)
    back.widthAnchor.constraint(equalToConstant: 42).isActive = true
    header.addArrangedSubview(back)

    let title = UILabel()
    title.text = "Analisi zona"
    title.textColor = darkText
    title.font = .systemFont(ofSize: 26, weight: .bold)
    header.addArrangedSubview(title)
    page.addArrangedSubview(header)

    let subtitle = UILabel()
    subtitle.text = "Ricerca offline entro 5 km"
    subtitle.textColor = UIColor(red: 95.0 / 255.0, green: 108.0 / 255.0, blue: 121.0 / 255.0, alpha: 1.0)
    subtitle.font = .systemFont(ofSize: 15, weight: .medium)
    page.addArrangedSubview(subtitle)

    let progressRow = UIStackView()
    progressRow.axis = .horizontal
    progressRow.alignment = .center
    progressRow.spacing = 10
    progress.setContentHuggingPriority(.defaultLow, for: .horizontal)
    progressPercent.text = "0%"
    progressPercent.font = .monospacedDigitSystemFont(ofSize: 13, weight: .bold)
    progressRow.addArrangedSubview(progress)
    progressRow.addArrangedSubview(progressPercent)
    page.addArrangedSubview(progressRow)

    for category in [GoTrailPoiCategory.hut, .waterfall, .parking, .interest] {
      page.addArrangedSubview(makeCategoryRow(category: category))
    }

    status.numberOfLines = 0
    status.textAlignment = .center
    status.text = "Analisi delle mappe locali in corso…"
    status.textColor = UIColor(red: 95.0 / 255.0, green: 108.0 / 255.0, blue: 121.0 / 255.0, alpha: 1.0)
    status.font = .systemFont(ofSize: 13, weight: .medium)
    page.addArrangedSubview(status)

    countLabel.textAlignment = .center
    countLabel.textColor = darkText
    countLabel.font = .systemFont(ofSize: 15, weight: .bold)
    page.addArrangedSubview(countLabel)

    resultsStack.axis = .vertical
    resultsStack.spacing = 8
    page.addArrangedSubview(resultsStack)

    showMapButton.setTitle("MOSTRA ANALISI SULLA MAPPA", for: .normal)
    showMapButton.setTitleColor(.white, for: .normal)
    showMapButton.titleLabel?.font = .systemFont(ofSize: 16, weight: .bold)
    showMapButton.backgroundColor = blue
    showMapButton.layer.cornerRadius = 22
    showMapButton.heightAnchor.constraint(equalToConstant: 50).isActive = true
    showMapButton.isHidden = true
    showMapButton.addTarget(self, action: #selector(showResultsOnMap), for: .touchUpInside)
    page.addArrangedSubview(showMapButton)

    NSLayoutConstraint.activate([
      scroll.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor),
      scroll.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor),
      scroll.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
      scroll.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),

      page.leadingAnchor.constraint(equalTo: scroll.contentLayoutGuide.leadingAnchor, constant: 18),
      page.trailingAnchor.constraint(equalTo: scroll.contentLayoutGuide.trailingAnchor, constant: -18),
      page.topAnchor.constraint(equalTo: scroll.contentLayoutGuide.topAnchor, constant: 18),
      page.bottomAnchor.constraint(equalTo: scroll.contentLayoutGuide.bottomAnchor, constant: -18),
      page.widthAnchor.constraint(equalTo: scroll.frameLayoutGuide.widthAnchor, constant: -36)
    ])
  }

  private func makeCategoryRow(category: GoTrailPoiCategory) -> UIView {
    let row = UIView()
    row.backgroundColor = .white
    row.layer.cornerRadius = 15
    row.heightAnchor.constraint(equalToConstant: 64).isActive = true

    let icon = UIImageView(image: UIImage(systemName: category.symbol))
    icon.translatesAutoresizingMaskIntoConstraints = false
    icon.tintColor = darkText
    icon.contentMode = .scaleAspectFit
    row.addSubview(icon)

    let label = UILabel()
    label.translatesAutoresizingMaskIntoConstraints = false
    label.text = category.rawValue
    label.textColor = darkText
    label.font = .systemFont(ofSize: 17, weight: .bold)
    row.addSubview(label)

    let value = UILabel()
    value.translatesAutoresizingMaskIntoConstraints = false
    value.text = "••••••"
    value.textColor = green
    value.font = .systemFont(ofSize: 15, weight: .bold)
    row.addSubview(value)
    categoryRows[category] = value

    NSLayoutConstraint.activate([
      icon.leadingAnchor.constraint(equalTo: row.leadingAnchor, constant: 14),
      icon.centerYAnchor.constraint(equalTo: row.centerYAnchor),
      icon.widthAnchor.constraint(equalToConstant: 30),
      icon.heightAnchor.constraint(equalToConstant: 30),
      label.leadingAnchor.constraint(equalTo: icon.trailingAnchor, constant: 12),
      label.centerYAnchor.constraint(equalTo: row.centerYAnchor),
      value.trailingAnchor.constraint(equalTo: row.trailingAnchor, constant: -15),
      value.centerYAnchor.constraint(equalTo: row.centerYAnchor)
    ])
    return row
  }

  private func startAnalysis() {
    found.removeAll()
    queryIndex = 0
    center = FrameworkHelper.viewportCenter()
    searchService = CarPlaySearchService()
    setProgress(5)
    runNextSearch()
  }

  private func runNextSearch() {
    guard queryIndex < searches.count else {
      finishAnalysis()
      return
    }

    let item = searches[queryIndex]
    let pct = 15 + Int((70.0 * Double(queryIndex)) / Double(max(1, searches.count - 1)))
    setProgress(pct)
    status.text = "Analisi delle mappe locali in corso…"

    searchService?.searchText(item.0, forInputLocale: "it") { [weak self] results in
      guard let self else { return }
      let origin = CLLocation(latitude: center.latitude, longitude: center.longitude)
      for result in results {
        let c = result.coordinate
        guard CLLocationCoordinate2DIsValid(c) else { continue }
        let d = origin.distance(from: CLLocation(latitude: c.latitude, longitude: c.longitude)) / 1000.0
        guard d <= radiusKm else { continue }
        let title = result.title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else { continue }
        if item.1 == .hut {
          let lower = title.lowercased()
          if lower.contains("bivacco") || lower.contains("bivouac") { continue }
        }
        let key = String(format: "%.5f|%.5f|%@", c.latitude, c.longitude, title.lowercased())
        found[key] = GoTrailIOSPoi(title: title, category: item.1, coordinate: c, distanceKm: d)
      }
      queryIndex += 1
      updateCategoryCounts()
      runNextSearch()
    }
  }

  private func updateCategoryCounts() {
    for category in [GoTrailPoiCategory.hut, .waterfall, .parking, .interest] {
      let n = found.values.filter { $0.category == category }.count
      categoryRows[category]?.text = n == 0 ? "••••••" : "✓  \(n)"
    }
  }

  private func finishAnalysis() {
    setProgress(100)
    updateCategoryCounts()
    let ordered = found.values.sorted {
      if $0.category.rawValue == $1.category.rawValue { return $0.distanceKm < $1.distanceKm }
      return $0.category.rawValue < $1.category.rawValue
    }
    status.text = "Analisi completata usando le mappe locali."
    countLabel.text = "\(ordered.count) risultati entro 5 km"

    resultsStack.arrangedSubviews.forEach { $0.removeFromSuperview() }

    for category in [GoTrailPoiCategory.hut, .waterfall, .parking, .interest] {
      let group = ordered.filter { $0.category == category }
      guard !group.isEmpty else { continue }

      let header = UILabel()
      header.text = "  \(category.rawValue.uppercased())   \(group.count)"
      header.textColor = .white
      header.backgroundColor = blue
      header.font = .systemFont(ofSize: 14, weight: .bold)
      header.layer.cornerRadius = 13
      header.clipsToBounds = true
      header.heightAnchor.constraint(equalToConstant: 36).isActive = true
      resultsStack.addArrangedSubview(header)

      for poi in group {
        let row = UILabel()
        row.numberOfLines = 3
        row.text = String(format: "%@\n%@\n%.1f km dal centro della zona", poi.title, category.rawValue, poi.distanceKm)
        row.font = .systemFont(ofSize: 14, weight: .semibold)
        row.textColor = darkText
        row.backgroundColor = .white
        row.layer.cornerRadius = 10
        row.clipsToBounds = true
        row.heightAnchor.constraint(greaterThanOrEqualToConstant: 64).isActive = true
        resultsStack.addArrangedSubview(row)
      }
    }
    showMapButton.isHidden = ordered.isEmpty
  }

  private func setProgress(_ value: Int) {
    progress.setProgress(Float(value) / 100.0, animated: true)
    progressPercent.text = "\(value)%"
  }

  @objc private func showResultsOnMap() {
    let ordered = found.values.sorted { $0.distanceKm < $1.distanceKm }
    guard !ordered.isEmpty else {
      dismiss(animated: true)
      return
    }

    var components = URLComponents()
    components.scheme = "om"
    components.host = "map"
    var queryItems: [URLQueryItem] = [
      URLQueryItem(name: "v", value: "1"),
      URLQueryItem(name: "appname", value: "GoTr-Ail")
    ]
    for poi in ordered {
      queryItems.append(URLQueryItem(name: "ll", value: String(format: "%.7f,%.7f", poi.coordinate.latitude, poi.coordinate.longitude)))
      queryItems.append(URLQueryItem(name: "n", value: poi.title))
      queryItems.append(URLQueryItem(name: "id", value: poi.category.markerID))
      queryItems.append(URLQueryItem(name: "s", value: poi.category.style))
    }
    components.queryItems = queryItems
    guard let url = components.url else { return }

    dismiss(animated: true) {
      _ = DeepLinkHandler.shared.applicationDidOpenUrl(url, openInPlace: false)
    }
  }

  @objc private func close() {
    dismiss(animated: true)
  }
}

private final class GradientView: UIView {
  var colors: [UIColor] = [] {
    didSet { gradientLayer.colors = colors.map(\.cgColor) }
  }

  private var gradientLayer: CAGradientLayer {
    layer as! CAGradientLayer
  }

  override class var layerClass: AnyClass {
    CAGradientLayer.self
  }

  override init(frame: CGRect) {
    super.init(frame: frame)
    gradientLayer.startPoint = CGPoint(x: 0.5, y: 0)
    gradientLayer.endPoint = CGPoint(x: 0.5, y: 1)
    gradientLayer.locations = [0.0, 0.50, 1.0]
  }

  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
}
