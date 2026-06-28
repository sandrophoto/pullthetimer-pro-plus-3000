import Cocoa
import SwiftUI
import UserNotifications
import ServiceManagement
import Sparkle

// MARK: - Mises à jour (Sparkle + appcast sur GitHub — même logique que les autres apps)
final class Updater {
    static let shared = Updater()
    private let controller: SPUStandardUpdaterController
    private init() {
        controller = SPUStandardUpdaterController(
            startingUpdater: true, updaterDelegate: nil, userDriverDelegate: nil)
    }
    func checkForUpdates() { controller.updater.checkForUpdates() }
    var automaticallyChecks: Bool {
        get { controller.updater.automaticallyChecksForUpdates }
        set { controller.updater.automaticallyChecksForUpdates = newValue }
    }
    var lastCheck: Date? { controller.updater.lastUpdateCheckDate }
    var currentVersion: String { Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "—" }
}

// MARK: - Géométrie : une fine ligne verticale terminée par un bout arrondi
//
// Reste strictement dans l'axe. La tige (largeur 2·sw) descend droite depuis le haut
// puis s'évase doucement vers un bulbe rond de rayon R (« un peu plus large ») en bas.
// Plus on tire (longueur grande), plus sw et R diminuent → la forme paraît fine.
func pinPath(top T: CGPoint, bottom B: CGPoint, stemHalf sw: CGFloat, bulbR R: CGFloat) -> NSBezierPath {
    let cx = T.x
    let C = CGPoint(x: cx, y: B.y + R)          // centre du bulbe arrondi
    let eqY = C.y                                // équateur du bulbe
    let flareY = eqY + R                         // début de l'évasement
    let p = NSBezierPath()
    p.move(to: CGPoint(x: cx - sw, y: T.y))
    p.line(to: CGPoint(x: cx - sw, y: flareY))
    p.curve(to: CGPoint(x: cx - R, y: eqY),
            controlPoint1: CGPoint(x: cx - sw, y: eqY + R * 0.45),
            controlPoint2: CGPoint(x: cx - R,  y: eqY + R * 0.55))
    p.appendArc(withCenter: C, radius: R, startAngle: 180, endAngle: 360, clockwise: false)
    p.curve(to: CGPoint(x: cx + sw, y: flareY),
            controlPoint1: CGPoint(x: cx + R,  y: eqY + R * 0.55),
            controlPoint2: CGPoint(x: cx + sw, y: eqY + R * 0.45))
    p.line(to: CGPoint(x: cx + sw, y: T.y))
    p.close()
    return p
}

// MARK: - Icône de la barre de menu : un disque plein de couleur.
// `fill` = niveau de couleur (1 = plein). Baisse quand on tire la ligne (l'encre du
// disque « passe » dans la ligne) et pendant le décompte.
func barIcon(fill f: CGFloat, phase: CGFloat = 0, mono: Bool = false) -> NSImage {
    let s: CGFloat = 18
    let r: CGFloat = 6.5
    let img = NSImage(size: NSSize(width: s, height: s))
    img.lockFocus()
    let circle = NSBezierPath(ovalIn: NSRect(x: s/2 - r, y: s/2 - r, width: r*2, height: r*2))
    // En N&B : noir + gabarit (la barre de menu le teinte en noir/blanc selon le thème)
    let accent = mono ? NSColor.black : NSColor.controlAccentColor
    // Liseré du disque complet (la partie « vidée » reste suggérée)
    accent.withAlphaComponent(0.35).setStroke()
    circle.lineWidth = 1.2
    circle.stroke()
    // Niveau de couleur, rempli par le bas, avec une petite vague en surface
    if f > 0 {
        NSGraphicsContext.saveGraphicsState()
        circle.addClip()
        accent.setFill()
        let level = (s/2 - r) + 2*r*min(f, 1)
        let amp: CGFloat = f >= 1 ? 0 : 1.1            // plein = surface plate
        let liquid = NSBezierPath()
        liquid.move(to: NSPoint(x: 0, y: 0))
        liquid.line(to: NSPoint(x: 0, y: level))
        var x: CGFloat = 0
        while x <= s { liquid.line(to: NSPoint(x: x, y: level + amp * sin(x * 0.95 + phase))); x += 1 }
        liquid.line(to: NSPoint(x: s, y: 0))
        liquid.close()
        liquid.fill()
        NSGraphicsContext.restoreGraphicsState()
    }
    img.unlockFocus()
    img.isTemplate = mono
    return img
}

// MARK: - Icône du Dock : squircle bleu + disque blanc qui se vide (même effet + vague)
func dockIcon(fill f: CGFloat, phase: CGFloat = 0) -> NSImage {
    let size: CGFloat = 256
    let img = NSImage(size: NSSize(width: size, height: size))
    img.lockFocus()

    let inset = size * 0.06
    let bg = NSRect(x: 0, y: 0, width: size, height: size).insetBy(dx: inset, dy: inset)
    let squircle = NSBezierPath(roundedRect: bg, xRadius: bg.width * 0.2237, yRadius: bg.width * 0.2237)
    NSGradient(colorsAndLocations:
        (NSColor(srgbRed: 0.26, green: 0.62, blue: 1.00, alpha: 1), 0.0),
        (NSColor(srgbRed: 0.13, green: 0.45, blue: 0.98, alpha: 1), 0.55),
        (NSColor(srgbRed: 0.07, green: 0.30, blue: 0.86, alpha: 1), 1.0))!.draw(in: squircle, angle: -90)

    let r = size * 0.27
    let c = CGPoint(x: size/2, y: size/2)
    let disk = NSBezierPath(ovalIn: NSRect(x: c.x - r, y: c.y - r, width: r*2, height: r*2))
    NSColor.white.withAlphaComponent(0.4).setStroke(); disk.lineWidth = size * 0.012; disk.stroke()
    if f > 0 {
        NSGraphicsContext.saveGraphicsState()
        disk.addClip()
        NSColor.white.setFill()
        let level = (c.y - r) + 2*r*min(f, 1)
        let amp: CGFloat = f >= 1 ? 0 : r * 0.10
        let liquid = NSBezierPath()
        liquid.move(to: NSPoint(x: 0, y: 0))
        liquid.line(to: NSPoint(x: 0, y: level))
        var x: CGFloat = 0
        while x <= size { liquid.line(to: NSPoint(x: x, y: level + amp * sin(x * 0.07 + phase))); x += 3 }
        liquid.line(to: NSPoint(x: size, y: 0)); liquid.close(); liquid.fill()
        NSGraphicsContext.restoreGraphicsState()
    }
    img.unlockFocus()
    return img
}

// MARK: - Overlay (flat design) : la forme est un aplat de couleur unie
final class OverlayView: NSView {
    enum Mode { case idle, dragging, detaching }
    var mode: Mode = .idle
    var apexScreen = CGPoint.zero
    var targetScreen = CGPoint.zero
    var minutes = 1
    var mono = false                    // mode N&B
    var monoColor: NSColor = .white     // couleur unique fixée au début du geste (N&B)
    var onDetached: (() -> Void)?

    private var bulb = CGPoint.zero
    private var vyS: CGFloat = 0
    private var detachT: CGFloat = 0
    private var anim: Timer?
    private var geo = Geo()
    private var cancelZone = false
    let cancelLen: CGFloat = 6           // sous cette longueur, on est en zone d'annulation

    struct Geo { var path = NSBezierPath(); var bulb = CGPoint.zero; var R: CGFloat = 1; var alpha: CGFloat = 1 }

    override var isFlipped: Bool { false }

    private func vp(_ s: CGPoint) -> CGPoint {
        guard let w = window else { return s }
        return CGPoint(x: s.x - w.frame.origin.x, y: s.y - w.frame.origin.y)
    }
    private func clamp(_ v: CGFloat, _ lo: CGFloat, _ hi: CGFloat) -> CGFloat { min(hi, max(lo, v)) }

    func begin(apex: CGPoint, target: CGPoint) {
        apexScreen = apex; targetScreen = target; mode = .dragging
        let a = vp(apex)
        bulb = CGPoint(x: a.x, y: a.y - 2)
        vyS = 0; detachT = 0
        anim?.invalidate()
        anim = Timer(timeInterval: 1.0/60.0, repeats: true) { [weak self] _ in self?.step() }
        RunLoop.main.add(anim!, forMode: .common)
        refresh()
    }
    func release() { if mode == .dragging { mode = .detaching } }
    func cancel() {
        anim?.invalidate(); anim = nil; mode = .idle; needsDisplay = true
    }

    private func step() {
        let dt: CGFloat = 1.0/60.0
        if mode == .dragging {
            let t = vp(targetScreen)
            let a: CGFloat = 1 - exp(-dt / 0.055)
            let ny = bulb.y + (t.y - bulb.y) * a
            vyS += ((ny - bulb.y)/dt - vyS) * 0.3
            bulb = CGPoint(x: t.x, y: ny)                  // x suit directement (axe)
        } else if mode == .detaching {
            detachT += dt / 0.42
            vyS *= 0.9
            if detachT >= 1 {
                anim?.invalidate(); anim = nil; mode = .idle; needsDisplay = true
                onDetached?(); onDetached = nil; return
            }
        }
        refresh()
    }

    private func computeGeo() -> Geo {
        let apex = vp(apexScreen)
        var top = apex
        var bot = CGPoint(x: apex.x, y: bulb.y)            // strictement dans l'axe
        bot.y -= clamp(max(0, -vyS) * 0.03, 0, 26)         // léger étirement en tirant

        let L = max(top.y - bot.y, 1)
        var sw = clamp(3.2 - L * 0.0075, 0.9, 3.2) * clamp(1 - abs(vyS) * 0.0004, 0.72, 1)
        var R  = clamp(min(sw * 2.3, L * 0.34), 2.2, 11)

        var alpha: CGFloat = 1
        cancelZone = (mode == .dragging) && (L < cancelLen)
        if cancelZone { alpha *= 0.35 }                    // s'estompe près de l'icône → annulation
        if mode == .detaching {
            let e = 1 - pow(1 - detachT, 3)
            alpha = 1 - e
            sw *= (1 - e); R *= (1 - e * 0.7)
            top.y = apex.y + (bot.y - apex.y) * e
            top.y -= e * 14; bot.y -= e * 14
        }
        sw = max(sw, 0.4); R = max(R, 1)
        if top.y - bot.y < R * 2.2 { bot.y = top.y - R * 2.2 }
        return Geo(path: pinPath(top: top, bottom: bot, stemHalf: sw, bulbR: R),
                   bulb: bot, R: R, alpha: alpha)
    }

    private func refresh() {
        geo = computeGeo()
        needsDisplay = true
    }

    override func draw(_ dirtyRect: NSRect) {
        guard mode != .idle else { return }
        let a = geo.alpha
        let path = geo.path

        // Flat design : une seule couleur unie, fixée pour tout le tir (jamais de
        // dégradé/contour qui ferait « changer » la couleur en s'amincissant).
        let lineColor = mono ? monoColor : NSColor.controlAccentColor
        lineColor.withAlphaComponent(a).setFill()
        path.fill()

        guard mode == .dragging, !cancelZone else { return }
        let label = minutes >= 60 ? String(format: "%dh%02d", minutes/60, minutes%60) : "\(minutes)"
        let unit = minutes >= 60 ? "" : " min"
        var big: [NSAttributedString.Key: Any] = [.font: NSFont.systemFont(ofSize: 30, weight: .regular), .foregroundColor: lineColor]
        var small: [NSAttributedString.Key: Any] = [.font: NSFont.systemFont(ofSize: 15, weight: .regular), .foregroundColor: lineColor]
        if mono {                          // ombre de la teinte opposée pour rester lisible
            let sh = NSShadow()
            sh.shadowColor = (monoColor == NSColor.white ? NSColor.black : NSColor.white).withAlphaComponent(0.8)
            sh.shadowBlurRadius = 4; sh.shadowOffset = .zero
            big[.shadow] = sh; small[.shadow] = sh
        }
        let main = NSMutableAttributedString(string: label, attributes: big)
        main.append(NSAttributedString(string: unit, attributes: small))
        let sz = main.size()
        main.draw(at: NSPoint(x: geo.bulb.x + geo.R + 22, y: geo.bulb.y + geo.R - sz.height/2))
    }
}

// MARK: - Réglages persistés
final class Settings: ObservableObject {
    private let d = UserDefaults.standard
    var onLoginChange: ((Bool) -> Void)?
    var onDockChange: ((Bool) -> Void)?
    var onTrayColorChange: (() -> Void)?

    @Published var trayColor: Bool { didSet { d.set(trayColor, forKey: "trayColor"); onTrayColorChange?() } }
    @Published var showInDock: Bool { didSet { d.set(showInDock, forKey: "showInDock"); onDockChange?(showInDock) } }
    @Published var openAtLogin: Bool { didSet { d.set(openAtLogin, forKey: "openAtLogin"); onLoginChange?(openAtLogin) } }
    @Published var alarmOn: Bool { didSet { d.set(alarmOn, forKey: "alarmOn") } }
    @Published var soundName: String { didSet { d.set(soundName, forKey: "soundName") } }
    @Published var timeFormat: Int { didSet { d.set(timeFormat, forKey: "timeFormat") } }  // 0 = m:ss, 1 = h:mm:ss
    @Published var repeatEnabled: Bool { didSet { d.set(repeatEnabled, forKey: "repeatEnabled") } }
    @Published var repeatInfinite: Bool { didSet { d.set(repeatInfinite, forKey: "repeatInfinite") } }
    @Published var repeatCount: Int { didSet { d.set(repeatCount, forKey: "repeatCount") } }   // nombre total de cycles

    @Published var actNotify: Bool { didSet { d.set(actNotify, forKey: "actNotify") } }
    @Published var notifyText: String { didSet { d.set(notifyText, forKey: "notifyText") } }
    @Published var actLaunchApp: Bool { didSet { d.set(actLaunchApp, forKey: "actLaunchApp") } }
    @Published var launchAppPath: String { didSet { d.set(launchAppPath, forKey: "launchAppPath") } }
    @Published var actQuitApp: Bool { didSet { d.set(actQuitApp, forKey: "actQuitApp") } }
    @Published var quitAppName: String { didSet { d.set(quitAppName, forKey: "quitAppName") } }
    @Published var quitAppBundleId: String { didSet { d.set(quitAppBundleId, forKey: "quitAppBundleId") } }
    @Published var actOpenURL: Bool { didSet { d.set(actOpenURL, forKey: "actOpenURL") } }
    @Published var urlString: String { didSet { d.set(urlString, forKey: "urlString") } }
    @Published var actSleep: Bool { didSet { d.set(actSleep, forKey: "actSleep") } }
    @Published var actShutdown: Bool { didSet { d.set(actShutdown, forKey: "actShutdown") } }

    init() {
        trayColor     = d.object(forKey: "trayColor") == nil ? true : d.bool(forKey: "trayColor")
        showInDock    = d.bool(forKey: "showInDock")
        openAtLogin   = d.bool(forKey: "openAtLogin")
        alarmOn       = d.object(forKey: "alarmOn") == nil ? true : d.bool(forKey: "alarmOn")
        let savedSound = d.string(forKey: "soundName") ?? "Glass"
        soundName     = systemSounds.contains(savedSound) ? savedSound : "Glass"
        repeatEnabled = d.bool(forKey: "repeatEnabled")
        repeatInfinite = d.bool(forKey: "repeatInfinite")
        repeatCount   = max(2, d.integer(forKey: "repeatCount"))
        actNotify     = d.object(forKey: "actNotify") == nil ? true : d.bool(forKey: "actNotify")
        notifyText    = d.string(forKey: "notifyText") ?? "Minuteur terminé"
        timeFormat    = d.integer(forKey: "timeFormat")
        actLaunchApp  = d.bool(forKey: "actLaunchApp")
        launchAppPath = d.string(forKey: "launchAppPath") ?? ""
        actQuitApp    = d.bool(forKey: "actQuitApp")
        quitAppName   = d.string(forKey: "quitAppName") ?? ""
        quitAppBundleId = d.string(forKey: "quitAppBundleId") ?? ""
        actOpenURL    = d.bool(forKey: "actOpenURL")
        urlString     = d.string(forKey: "urlString") ?? "https://"
        actSleep      = d.bool(forKey: "actSleep")
        actShutdown   = d.bool(forKey: "actShutdown")
    }
}

let appDisplayName = "PullTheTimer Pro Plus 3000"

// MARK: - AppleScript exécuté DEPUIS l'app (TCC attribué à l'app, pas à osascript)
// Renvoie (sortie, messageDErreur). Le 1er envoi vers une app déclenche le prompt
// d'autorisation d'automatisation ; un refus renvoie une erreur (-1743).
func appleScript(_ source: String) -> (out: String?, error: String?) {
    var err: NSDictionary?
    let result = NSAppleScript(source: source)?.executeAndReturnError(&err)
    if let err = err {
        let msg = (err[NSAppleScript.errorMessage] as? String) ?? "\(err)"
        NSLog("AppleScript error: \(err)")
        return (nil, msg)
    }
    return (result?.stringValue ?? "", nil)
}
@discardableResult
func runAppleScript(_ source: String) -> String? { appleScript(source).out }
func asEscape(_ s: String) -> String {
    s.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\"")
}

let systemSounds = ["Glass", "Ping", "Hero", "Submarine", "Funk",
                    "Bottle", "Frog", "Morse", "Purr", "Sosumi", "Tink"]

// MARK: - Fenêtre Options (SwiftUI — style barre latérale + cartes)
struct RunningApp: Identifiable, Hashable { let id: String; let name: String }

// Flou « behind-window » (le bureau transparaît, façon Réglages translucides)
struct VEffect: NSViewRepresentable {
    var material: NSVisualEffectView.Material = .sidebar
    func makeNSView(context: Context) -> NSVisualEffectView {
        let v = NSVisualEffectView(); v.material = material; v.blendingMode = .behindWindow; v.state = .active; return v
    }
    func updateNSView(_ v: NSVisualEffectView, context: Context) { v.material = material }
}

// Petite tuile d'icône colorée (SF Symbol blanc sur dégradé)
struct IconTile: View {
    let symbol: String; let color: Color; var size: CGFloat = 24
    var body: some View {
        RoundedRectangle(cornerRadius: size * 0.28, style: .continuous).fill(color.gradient)
            .frame(width: size, height: size)
            .overlay(Image(systemName: symbol).font(.system(size: size * 0.5, weight: .semibold)).foregroundStyle(.white))
            .shadow(color: color.opacity(0.45), radius: 2, y: 1)
    }
}

enum SettingsPane: Hashable, CaseIterable {
    case general, appearance, repeatT, alarm, notif, actions, system, updates, about
    var title: String {
        switch self {
        case .general: "Général"; case .appearance: "Apparence"; case .repeatT: "Répétition"
        case .alarm: "Alarme"; case .notif: "Notification"; case .actions: "Actions"
        case .system: "Système"; case .updates: "Mise à jour"; case .about: "À propos" }
    }
    var symbol: String {
        switch self {
        case .general: "gearshape.fill"; case .appearance: "paintbrush.fill"; case .repeatT: "repeat"
        case .alarm: "bell.fill"; case .notif: "app.badge.fill"; case .actions: "bolt.fill"
        case .system: "power"; case .updates: "arrow.triangle.2.circlepath"; case .about: "info.circle.fill" }
    }
    var color: Color {
        switch self {
        case .general: .gray; case .appearance: .purple; case .repeatT: .blue
        case .alarm: .orange; case .notif: .red; case .actions: .yellow
        case .system: .pink; case .updates: .green; case .about: .teal }
    }
}

struct SettingsView: View {
    @ObservedObject var settings: Settings
    var onTestSound: () -> Void
    var onTestTriggers: () -> Void
    @State private var autoCheck = Updater.shared.automaticallyChecks
    @State private var pane: SettingsPane = .general

    var runningApps: [RunningApp] {
        NSWorkspace.shared.runningApplications
            .filter { $0.activationPolicy == .regular && $0.bundleIdentifier != nil && $0.bundleIdentifier != "com.tigre.pullthetimer" }
            .map { RunningApp(id: $0.bundleIdentifier!, name: $0.localizedName ?? $0.bundleIdentifier!) }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    var body: some View {
        HStack(spacing: 0) {
            sidebar
            Rectangle().fill(.white.opacity(0.08)).frame(width: 1)
            detail
        }
        .frame(width: 772, height: 562)
        .tint(Color(red: 0.20, green: 0.80, blue: 0.62))
        .background(VEffect(material: .underWindowBackground))
    }

    // MARK: Barre latérale
    private var sidebar: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 4) {
                sideRow(.general)
                sideGroup("Minuteur", [.appearance, .repeatT])
                sideGroup("Fin du minuteur", [.alarm, .notif, .actions, .system])
                sideGroup("Application", [.updates, .about])
            }
            .padding(.horizontal, 12).padding(.vertical, 16)
        }
        .frame(width: 234)
        .background(VEffect(material: .sidebar))
    }
    private func sideGroup(_ title: String, _ items: [SettingsPane]) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title.uppercased()).font(.system(size: 11, weight: .semibold)).tracking(0.6)
                .foregroundStyle(.secondary).padding(.leading, 8).padding(.top, 14).padding(.bottom, 2)
            ForEach(items, id: \.self) { sideRow($0) }
        }
    }
    private func sideRow(_ p: SettingsPane) -> some View {
        Button { pane = p } label: {
            HStack(spacing: 10) {
                IconTile(symbol: p.symbol, color: p.color)
                Text(p.title).font(.system(size: 13.5, weight: .medium)).foregroundStyle(.primary)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 8).padding(.vertical, 6)
            .background(RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(pane == p ? Color.primary.opacity(0.13) : .clear))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: Panneau de détail
    private var detail: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                HStack(spacing: 12) {
                    IconTile(symbol: pane.symbol, color: pane.color, size: 30)
                    Text(pane.title).font(.system(size: 24, weight: .bold))
                }
                paneContent
            }
            .padding(28).frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    @ViewBuilder private var paneContent: some View {
        switch pane {
        case .general: generalPane
        case .appearance: appearancePane
        case .repeatT: repeatPane
        case .alarm: alarmPane
        case .notif: notifPane
        case .actions: actionsPane
        case .system: systemPane
        case .updates: updatesPane
        case .about: aboutPane
        }
    }

    // MARK: Briques d'UI
    private var rdiv: some View { Rectangle().fill(.white.opacity(0.07)).frame(height: 1).padding(.leading, 16) }
    private func card<C: View>(@ViewBuilder _ c: () -> C) -> some View {
        VStack(spacing: 0) { c() }
            .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(.white.opacity(0.05)))
            .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(.white.opacity(0.07)))
    }
    private func row<C: View>(_ title: String, _ sub: String? = nil, @ViewBuilder _ control: () -> C) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.system(size: 14))
                if let sub { Text(sub).font(.caption).foregroundStyle(.secondary) }
            }
            Spacer(minLength: 10)
            control()
        }
        .padding(.horizontal, 16).padding(.vertical, 11)
    }
    private func subHead(_ t: String) -> some View {
        Text(t.uppercased()).font(.system(size: 11, weight: .semibold)).tracking(0.6)
            .foregroundStyle(.secondary).padding(.leading, 4)
    }
    private func sw(_ on: Binding<Bool>) -> some View { Toggle("", isOn: on).labelsHidden().toggleStyle(.switch) }

    // MARK: Panes
    @ViewBuilder private var generalPane: some View {
        VStack(alignment: .leading, spacing: 14) {
            card {
                row("Ouvrir au démarrage") { sw($settings.openAtLogin) }
                rdiv
                row("Garder l'icône dans le Dock") { sw($settings.showInDock) }
            }
        }
    }
    @ViewBuilder private var appearancePane: some View {
        VStack(alignment: .leading, spacing: 14) {
            card {
                row("Icône de la barre de menu") {
                    Picker("", selection: $settings.trayColor) { Text("Couleur").tag(true); Text("Noir et blanc").tag(false) }
                        .labelsHidden().frame(width: 150)
                }
                rdiv
                row("Affichage du temps") {
                    Picker("", selection: $settings.timeFormat) { Text("23m45s").tag(0); Text("01h23m45s").tag(1) }
                        .labelsHidden().frame(width: 130)
                }
            }
        }
    }
    @ViewBuilder private var repeatPane: some View {
        VStack(alignment: .leading, spacing: 14) {
            card {
                row("Répéter le minuteur") { sw($settings.repeatEnabled) }
                if settings.repeatEnabled {
                    rdiv
                    row("Répéter à l'infini") { sw($settings.repeatInfinite) }
                    if !settings.repeatInfinite {
                        rdiv
                        row("Nombre de répétitions") {
                            HStack(spacing: 8) {
                                Text("\(settings.repeatCount)").monospacedDigit().foregroundStyle(.secondary)
                                Stepper("", value: $settings.repeatCount, in: 2...99).labelsHidden()
                            }
                        }
                    }
                }
            }
        }
    }
    @ViewBuilder private var alarmPane: some View {
        VStack(alignment: .leading, spacing: 14) {
            card {
                row("Alarme sonore") { sw($settings.alarmOn) }
                if settings.alarmOn {
                    rdiv
                    row("Son") {
                        HStack(spacing: 8) {
                            Picker("", selection: $settings.soundName) { ForEach(systemSounds, id: \.self) { Text($0).tag($0) } }
                                .labelsHidden().frame(width: 120)
                            Button("Tester", action: onTestSound)
                        }
                    }
                }
            }
        }
    }
    @ViewBuilder private var notifPane: some View {
        VStack(alignment: .leading, spacing: 14) {
            card {
                row("Afficher une notification") { sw($settings.actNotify) }
                if settings.actNotify {
                    rdiv
                    row("Message") { TextField("Minuteur terminé", text: $settings.notifyText).frame(width: 220) }
                }
            }
        }
    }
    @ViewBuilder private var actionsPane: some View {
        VStack(alignment: .leading, spacing: 14) {
            card {
                row("Lancer une application") { sw($settings.actLaunchApp) }
                if settings.actLaunchApp {
                    rdiv
                    row(settings.launchAppPath.isEmpty ? "Aucune app choisie" : (settings.launchAppPath as NSString).lastPathComponent) {
                        Button("Choisir…", action: chooseApp)
                    }
                }
                rdiv
                row("Ouvrir une page web") { sw($settings.actOpenURL) }
                if settings.actOpenURL {
                    rdiv
                    row("Adresse") { TextField("https://…", text: $settings.urlString).frame(width: 220) }
                }
                rdiv
                row("Fermer une application") { sw($settings.actQuitApp) }
                if settings.actQuitApp {
                    rdiv
                    row("Application") {
                        Picker("", selection: $settings.quitAppBundleId) {
                            Text("Choisir…").tag("")
                            ForEach(runningApps) { Text($0.name).tag($0.id) }
                            if !settings.quitAppBundleId.isEmpty && !runningApps.contains(where: { $0.id == settings.quitAppBundleId }) {
                                Text(settings.quitAppName.isEmpty ? settings.quitAppBundleId : settings.quitAppName).tag(settings.quitAppBundleId)
                            }
                        }
                        .labelsHidden().frame(width: 180)
                        .onChange(of: settings.quitAppBundleId) { id in
                            settings.quitAppName = runningApps.first { $0.id == id }?.name ?? settings.quitAppName
                        }
                    }
                }
            }
            Button("Tester les déclencheurs maintenant", action: onTestTriggers)
            Text("Le test exécute ces actions (sauf veille / extinction).")
                .font(.caption).foregroundStyle(.secondary)
        }
    }
    @ViewBuilder private var systemPane: some View {
        VStack(alignment: .leading, spacing: 14) {
            card {
                row("Mettre l'ordinateur en veille") { sw($settings.actSleep) }
                rdiv
                row("Éteindre l'ordinateur") { sw($settings.actShutdown) }
            }
            if settings.actSleep || settings.actShutdown {
                Text("⚠︎ La première fois, macOS demandera l'autorisation d'automatiser « System Events ».")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
    }
    @ViewBuilder private var updatesPane: some View {
        VStack(alignment: .leading, spacing: 14) {
            card {
                row("Application") { Text(appDisplayName).foregroundStyle(.secondary) }
                rdiv
                row("Version") { Text(Updater.shared.currentVersion).foregroundStyle(.secondary) }
            }
            subHead("Mises à jour automatiques")
            card {
                row("Vérifier chaque jour") {
                    sw($autoCheck).onChange(of: autoCheck) { Updater.shared.automaticallyChecks = $0 }
                }
                rdiv
                row("Dernière vérification") { Text(lastCheckText).foregroundStyle(.secondary) }
            }
            Button("Rechercher les mises à jour maintenant…") { Updater.shared.checkForUpdates() }
            Text("Téléchargées et installées automatiquement depuis GitHub (signées et vérifiées).")
                .font(.caption).foregroundStyle(.secondary)
        }
    }
    @ViewBuilder private var aboutPane: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 16) {
                Image(nsImage: NSApp.applicationIconImage).resizable().frame(width: 84, height: 84)
                    .shadow(color: .black.opacity(0.3), radius: 8, y: 4)
                VStack(alignment: .leading, spacing: 5) {
                    Text(appDisplayName).font(.system(size: 18, weight: .bold))
                    Text("Minuteur à tirer · barre de menu").font(.callout).foregroundStyle(.secondary)
                    Text("Version \(Updater.shared.currentVersion)").font(.caption).foregroundStyle(.secondary)
                }
            }
            card {
                row("Réalisé par") {
                    Text("STUPIDS STUDIO").font(.system(size: 14, weight: .heavy))
                        .foregroundStyle(LinearGradient(colors: [Color(red:0.95,green:0.2,blue:0.2), Color(red:1,green:0.62,blue:0.1)],
                                                        startPoint: .leading, endPoint: .trailing))
                }
            }
            HStack(spacing: 10) {
                Button("Site web") { if let u = URL(string: "https://tigre.paris") { NSWorkspace.shared.open(u) } }
                Button("GitHub") { if let u = URL(string: "https://github.com/sandrophoto/pullthetimer-pro-plus-3000") { NSWorkspace.shared.open(u) } }
                Button("Contact") { if let u = URL(string: "mailto:sandro@tigre.paris") { NSWorkspace.shared.open(u) } }
            }
            Text("© 2026 STUPIDS STUDIO").font(.caption2).foregroundStyle(.secondary)
        }
    }

    private var lastCheckText: String {
        guard let d = Updater.shared.lastCheck else { return "jamais" }
        let f = DateFormatter(); f.dateStyle = .medium; f.timeStyle = .short
        return f.string(from: d)
    }

    func chooseApp() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.application]
        panel.directoryURL = URL(fileURLWithPath: "/Applications")
        panel.canChooseDirectories = false
        if panel.runModal() == .OK, let url = panel.url {
            settings.launchAppPath = url.path
        }
    }
}

// MARK: - Fenêtre À propos (style maison STUPIDS STUDIO)
struct AboutView: View {
    private let appName = appDisplayName
    private let tagline = "Minuteur à tirer · dans la barre de menu"
    private let studio = "STUPIDS STUDIO"
    private let bg = Color(red: 0.11, green: 0.11, blue: 0.12)

    private var versionShort: String { Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0" }
    private var versionBuild: String { Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1.0" }

    var body: some View {
        VStack(spacing: 0) {
            LinearGradient(colors: [Color(red: 0.16, green: 0.50, blue: 1.0),
                                    Color(red: 0.32, green: 0.80, blue: 1.0),
                                    Color(red: 0.16, green: 0.50, blue: 1.0)],
                           startPoint: .leading, endPoint: .trailing)
                .frame(height: 5)

            VStack(spacing: 0) {
                Spacer().frame(height: 30)

                Image(nsImage: NSApp.applicationIconImage)
                    .resizable().interpolation(.high)
                    .frame(width: 140, height: 140)
                    .shadow(color: .black.opacity(0.35), radius: 12, y: 6)

                Text(appName)
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    .minimumScaleFactor(0.7)
                    .padding(.horizontal, 20)
                    .padding(.top, 22)
                Text(tagline)
                    .font(.callout)
                    .foregroundStyle(.white.opacity(0.5))
                    .padding(.top, 4)

                HStack(spacing: 6) {
                    Text("Version \(versionShort)").font(.callout.weight(.semibold)).foregroundStyle(.white)
                    Text("(build \(versionBuild))").font(.callout).foregroundStyle(.white.opacity(0.45))
                }
                .padding(.horizontal, 14).padding(.vertical, 6)
                .background(.white.opacity(0.08), in: Capsule())
                .padding(.top, 18)

                Rectangle().fill(.white.opacity(0.12)).frame(width: 270, height: 1).padding(.top, 24)

                Text("RÉALISÉ PAR")
                    .font(.system(size: 11, weight: .semibold)).tracking(2.5)
                    .foregroundStyle(.white.opacity(0.4)).padding(.top, 22)
                Text(studio)
                    .font(.system(size: 22, weight: .heavy))
                    .foregroundStyle(LinearGradient(
                        colors: [Color(red: 0.95, green: 0.20, blue: 0.20), Color(red: 1.0, green: 0.62, blue: 0.10)],
                        startPoint: .leading, endPoint: .trailing))
                    .padding(.top, 6)

                VStack(spacing: 10) {
                    creditRow("timer", "Minuteur dans la barre de menu")
                    creditRow("hand.draw", "Réglage par geste — tirer vers le bas")
                    creditRow("bell.badge", "Alarme + déclencheurs de fin")
                    creditRow("arrow.triangle.2.circlepath", "Mises à jour · Sparkle + GitHub")
                    creditRow("swift", "Interface · AppKit + SwiftUI")
                }
                .padding(.top, 18)

                Spacer(minLength: 24)

                HStack(spacing: 10) {
                    Button("Site web") { open("https://tigre.paris") }
                    Button("Contact") { open("mailto:sandro@tigre.paris") }
                    Button("Rechercher les mises à jour…") { Updater.shared.checkForUpdates() }
                }

                Text("© 2026 \(studio) — Tous droits réservés.")
                    .font(.caption).foregroundStyle(.white.opacity(0.4))
                    .padding(.top, 16).padding(.bottom, 18)
            }
            .padding(.horizontal, 24)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(width: 430, height: 560)
        .background(bg)
    }

    private func creditRow(_ icon: String, _ text: String) -> some View {
        HStack(spacing: 8) { Image(systemName: icon); Text(text) }
            .font(.callout).foregroundStyle(.white.opacity(0.6))
    }
    private func open(_ s: String) { if let u = URL(string: s) { NSWorkspace.shared.open(u) } }
}

// MARK: - Popover de survol : la bille éclot en fenêtre montrant le minuteur
final class TimerModel: ObservableObject {
    @Published var progress: CGFloat = 0     // restant / total
    @Published var timeText: String = ""
    @Published var totalText: String = ""
    @Published var paused = false
    @Published var appeared = false          // pilote l'éclosion depuis la bille
}

struct TimerPopoverView: View {
    @ObservedObject var model: TimerModel
    var onPause: () -> Void
    var onStop: () -> Void
    var body: some View {
        VStack(spacing: 14) {
            ZStack {
                Circle().stroke(Color.primary.opacity(0.12), lineWidth: 11)
                Circle()
                    .trim(from: 0, to: max(0.0001, 1 - model.progress))   // se remplit avec le temps écoulé
                    .stroke(Color.accentColor, style: StrokeStyle(lineWidth: 11, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .animation(.linear(duration: 1), value: model.progress)
                VStack(spacing: 2) {
                    Text(model.timeText)
                        .font(.system(size: 30, weight: .light, design: .rounded)).monospacedDigit()
                        .foregroundStyle(.primary)
                        .contentTransition(.numericText())
                        .animation(.default, value: model.timeText)
                    Text(model.paused ? "en pause" : "restant").font(.caption2).foregroundStyle(.secondary)
                }
            }
            .frame(width: 150, height: 150)
            Text(model.totalText).font(.callout).foregroundStyle(.secondary)

            HStack(spacing: 10) {
                Button(action: onPause) {
                    Label(model.paused ? "Reprendre" : "Pause",
                          systemImage: model.paused ? "play.fill" : "pause.fill")
                        .frame(maxWidth: .infinity)
                }
                Button(action: onStop) {
                    Label("Stop", systemImage: "stop.fill").frame(maxWidth: .infinity)
                }
                .tint(.red)
            }
            .controlSize(.large)
            .buttonStyle(.bordered)
        }
        .padding(22)
        .frame(width: 230, height: 300)
        .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(.regularMaterial))
        .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).strokeBorder(.white.opacity(0.08)))
        // Éclosion : toute la carte « pousse » depuis la bille (haut), avec un léger ressort.
        .scaleEffect(model.appeared ? 1 : 0.2, anchor: .top)
        .opacity(model.appeared ? 1 : 0)
        .animation(.spring(response: 0.34, dampingFraction: 0.7), value: model.appeared)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .padding(10)   // marge pour l'ombre et l'éclosion
    }
}

// MARK: - Contrôleur principal
final class AppController: NSObject, NSApplicationDelegate, UNUserNotificationCenterDelegate {
    let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    let settings = Settings()
    var overlayWindow: NSWindow!
    var overlayView: OverlayView!
    var settingsWindow: NSWindow?
    var aboutWindow: NSWindow?
    let dockImageView = NSImageView()

    var countdown: Timer?
    var billeAnim: Timer?
    var totalSeconds = 0
    var remainingSeconds = 0
    var timerMinutes = 0          // durée d'un cycle, pour relancer en répétition
    var cyclesLeft = 0            // cycles restants
    var totalCycles = 1
    var cycleNum = 0              // numéro du cycle en cours (affichage)
    var infiniteRepeat = false

    let timerModel = TimerModel()
    var hoverWindow: NSWindow?
    var hideHoverWork: DispatchWorkItem?
    var dismissWork: DispatchWorkItem?

    let maxMinutes = 180
    let dragThreshold: CGFloat = 8
    let cancelThreshold: CGFloat = 6    // relâcher en deçà (ligne sur l'icône) = annuler
    // Courbe distance→minutes (px, min), interpolée par morceaux : début précis, milieu en heures.
    let curve: [(CGFloat, CGFloat)] = [(0, 0), (210, 15), (390, 60), (580, 180)]

    func applicationDidFinishLaunching(_ note: Notification) {
        UNUserNotificationCenter.current().delegate = self
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
        _ = Updater.shared        // démarre les vérifications planifiées de Sparkle
        buildMainMenu()           // ⌘W, ⌘Q, et raccourcis d'édition dans les fenêtres
        settings.onLoginChange = { on in Self.setLoginItem(on) }
        settings.onDockChange = { [weak self] on in
            NSApp.setActivationPolicy(on ? .regular : .accessory)
            if on { self?.refreshIconNow() }              // reflète l'état courant
        }
        settings.onTrayColorChange = { [weak self] in self?.refreshIconNow() }
        NSApp.setActivationPolicy(settings.showInDock ? .regular : .accessory)

        dockImageView.imageScaling = .scaleProportionallyUpOrDown

        if let b = statusItem.button {
            b.imagePosition = .imageRight   // temps À GAUCHE de la bille → la bille reste fixe
            b.target = self
            b.action = #selector(handlePress)
            b.sendAction(on: [.leftMouseDown, .rightMouseDown])
            // Zone de survol → popover du minuteur
            b.addTrackingArea(NSTrackingArea(rect: b.bounds,
                options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect],
                owner: self, userInfo: nil))
        }
        setIcon(fill: 1)

        overlayWindow = NSWindow(contentRect: .zero, styleMask: .borderless, backing: .buffered, defer: false)
        overlayWindow.isOpaque = false
        overlayWindow.backgroundColor = .clear
        overlayWindow.ignoresMouseEvents = true
        overlayWindow.level = NSWindow.Level(rawValue: Int(CGShieldingWindowLevel()))
        overlayWindow.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]

        overlayView = OverlayView()
        overlayWindow.contentView = overlayView
    }

    // MARK: Interaction (clic-maintenu puis tirer vers le bas)
    @objc func handlePress() {
        guard let event = NSApp.currentEvent else { return }
        closeHoverPopover()
        if event.type == .rightMouseDown { showMenu(); return }

        // Double-clic → annule le menu différé et le minuteur en cours.
        if event.clickCount >= 2 {
            NSObject.cancelPreviousPerformRequests(withTarget: self, selector: #selector(showMenuDeferred), object: nil)
            if remainingSeconds > 0 { cancelTimer() }
            return
        }

        let startY = NSEvent.mouseLocation.y
        let apex = apexPoint()
        // La ligne (et le tir effectif) sont bornés à la moitié de la hauteur d'écran.
        let maxDist = (NSScreen.screens.first { $0.frame.contains(apex) } ?? NSScreen.main!).frame.height / 2
        var didDrag = false
        var lastMins = 0

        trackingLoop: while true {
            guard let ev = NSApp.nextEvent(matching: [.leftMouseDragged, .leftMouseUp],
                                           until: .distantFuture, inMode: .eventTracking, dequeue: true)
            else { continue }
            let cur = NSEvent.mouseLocation
            let dist = min(startY - cur.y, maxDist)        // bornée à la moitié de l'écran
            let cappedY = startY - dist                    // empêche la ligne d'aller plus bas
            switch ev.type {
            case .leftMouseDragged:
                if dist > dragThreshold {
                    if !didDrag { beginOverlay(apex: apex, target: cur) }
                    didDrag = true
                    let mins = minutesFor(distance: dist)
                    if mins != lastMins {                 // « clic » haptique à chaque palier
                        NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .default)
                        lastMins = mins
                    }
                    overlayView.targetScreen = CGPoint(x: cur.x, y: cappedY)
                    overlayView.minutes = mins
                    // L'encre du disque « passe » dans la ligne : le niveau baisse avec le tir,
                    // avec une petite vague dont la phase suit le tir. (tray + Dock custom)
                    setIcon(fill: 1 - min(dist / maxDist, 1), phase: dist * 0.18, dockCustom: true)
                }
            case .leftMouseUp:
                if didDrag && dist > cancelThreshold {
                    let mins = minutesFor(distance: dist)
                    let startFill = 1 - min(dist / maxDist, 1)   // niveau au moment du lâcher
                    overlayView.onDetached = { [weak self] in self?.overlayWindow.orderOut(nil) }
                    overlayView.release()
                    // La bille finit de se vider, puis le minuteur démarre.
                    drainBille(from: startFill) { [weak self] in self?.startTimer(minutes: mins) }
                } else if didDrag {
                    // Ligne remontée sur l'icône → on annule le geste ET le minuteur en cours
                    overlayView.cancel()
                    overlayWindow.orderOut(nil)
                    if remainingSeconds > 0 { cancelTimer() } else { setIcon(fill: 1) }
                } else if remainingSeconds > 0 {
                    // Minuteur en cours : on diffère le menu pour laisser une chance au double-clic (annulation).
                    perform(#selector(showMenuDeferred), with: nil, afterDelay: NSEvent.doubleClickInterval, inModes: [.common])
                } else {
                    showMenu()
                }
                break trackingLoop
            default: break
            }
        }
    }

    func minutesFor(distance: CGFloat) -> Int {
        // Mapping non-proportionnel via la courbe (px → minutes).
        var raw = CGFloat(maxMinutes)
        for i in 1..<curve.count {
            let (x0, m0) = curve[i-1], (x1, m1) = curve[i]
            if distance <= x1 {
                raw = m0 + (distance - x0) / (x1 - x0) * (m1 - m0)
                break
            }
        }
        // Pas adapté à l'échelle : 1 min au début, 5 min, puis demi-heures.
        let step: CGFloat = raw <= 15 ? 1 : (raw <= 60 ? 5 : 30)
        let m = Int((raw / step).rounded()) * Int(step)
        return max(1, min(maxMinutes, m))
    }

    func apexPoint() -> CGPoint {
        guard let b = statusItem.button, let w = b.window else { return NSEvent.mouseLocation }
        let f = w.convertToScreen(b.convert(b.bounds, to: nil))
        return CGPoint(x: f.midX, y: f.minY)
    }

    func beginOverlay(apex: CGPoint, target: CGPoint) {
        billeAnim?.invalidate(); billeAnim = nil       // un nouveau geste interrompt le vidage
        let screen = NSScreen.screens.first { $0.frame.contains(apex) } ?? NSScreen.main!
        overlayWindow.setFrame(screen.frame, display: false)
        let bounds = NSRect(origin: .zero, size: screen.frame.size)
        overlayWindow.contentView?.frame = bounds
        overlayView.frame = bounds
        overlayView.mono = !settings.trayColor
        if overlayView.mono {              // couleur unique selon le thème, fixée pour ce tir
            let dark = NSApp.effectiveAppearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
            overlayView.monoColor = dark ? .white : .black
        }
        overlayWindow.orderFrontRegardless()
        overlayView.begin(apex: apex, target: target)
    }

    // MARK: Minuteur
    func startTimer(minutes: Int) {
        timerMinutes = minutes
        infiniteRepeat = settings.repeatEnabled && settings.repeatInfinite
        totalCycles = (settings.repeatEnabled && !settings.repeatInfinite) ? max(1, settings.repeatCount) : 1
        cyclesLeft = totalCycles
        cycleNum = 0
        beginCycle()
    }
    private func beginCycle() {
        cycleNum += 1
        totalSeconds = timerMinutes * 60
        remainingSeconds = totalSeconds
        timerModel.paused = false
        let base = timerMinutes >= 60 ? "Minuteur de \(timerMinutes/60)h\(String(format: "%02d", timerMinutes%60))"
                                      : "Minuteur de \(timerMinutes) min"
        if infiniteRepeat        { timerModel.totalText = "\(base) · ∞ (\(cycleNum))" }
        else if totalCycles > 1  { timerModel.totalText = "\(base) · \(cycleNum)/\(totalCycles)" }
        else                     { timerModel.totalText = base }
        startCountdown()
        updateDisplay()
    }
    private func startCountdown() {
        countdown?.invalidate()
        countdown = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in self?.tick() }
        RunLoop.main.add(countdown!, forMode: .common)
    }
    func togglePause() { timerModel.paused ? resumeTimer() : pauseTimer() }
    func pauseTimer() {
        guard remainingSeconds > 0 else { return }
        countdown?.invalidate(); countdown = nil
        timerModel.paused = true
    }
    func resumeTimer() {
        guard remainingSeconds > 0 else { return }
        timerModel.paused = false
        startCountdown()
        updateDisplay()
    }
    func tick() { remainingSeconds -= 1; if remainingSeconds <= 0 { finishTimer() } else { updateDisplay() } }
    func cancelTimer() {
        countdown?.invalidate(); countdown = nil
        billeAnim?.invalidate(); billeAnim = nil
        totalSeconds = 0; remainingSeconds = 0
        cyclesLeft = 0; infiniteRepeat = false
        timerModel.paused = false
        setIcon(fill: 1)
        statusItem.button?.attributedTitle = NSAttributedString(string: "")
        closeHoverPopover()
    }
    func finishTimer() {
        countdown?.invalidate(); countdown = nil
        playAlarm()                              // l'alarme sonne à chaque cycle
        if infiniteRepeat { beginCycle(); return }   // boucle sans fin (Stop pour arrêter)
        cyclesLeft -= 1
        if cyclesLeft > 0 {                      // répétition : on relance le même minuteur
            beginCycle()
            return
        }
        // Dernier cycle : déclencheurs complets puis reset
        totalSeconds = 0; remainingSeconds = 0
        timerModel.paused = false
        runTriggers()
        setIcon(fill: 1)
        statusItem.button?.attributedTitle = NSAttributedString(string: "")
        closeHoverPopover()
    }
    func postNotification() {
        let content = UNMutableNotificationContent()
        content.title = appDisplayName
        content.body = settings.notifyText.isEmpty ? "Minuteur terminé" : settings.notifyText
        if settings.alarmOn { content.sound = .default }
        UNUserNotificationCenter.current().add(
            UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil))
    }
    func formatTime(_ secs: Int) -> String {
        // 01h23m45s s'il reste au moins une heure ; sinon 23m45s
        if settings.timeFormat == 1, secs >= 3600 {
            return String(format: "%02dh%02dm%02ds", secs/3600, (secs%3600)/60, secs%60)
        }
        return String(format: "%02dm%02ds", secs/60, secs%60)
    }
    // Met à jour l'icône du tray (toujours le disque) et, si demandé, le Dock.
    // dockCustom = false → le Dock garde son icône normale (app icon).
    func setIcon(fill: CGFloat, phase: CGFloat = 0, dockCustom: Bool = false) {
        statusItem.button?.image = barIcon(fill: fill, phase: phase, mono: !settings.trayColor)
        if settings.showInDock {
            if dockCustom {
                dockImageView.image = dockIcon(fill: fill, phase: phase)
                NSApp.dockTile.contentView = dockImageView
            } else {
                NSApp.dockTile.contentView = nil           // icône normale (app icon)
            }
            NSApp.dockTile.display()
        }
    }
    func refreshIconNow() {
        if totalSeconds > 0 { updateDisplay() } else { setIcon(fill: 1) }
    }

    // Petite animation : la bille finit de se vider (de `start` à 0), puis `completion`.
    func drainBille(from start: CGFloat, completion: @escaping () -> Void) {
        billeAnim?.invalidate()
        var f = max(0, min(1, start))
        var phase: CGFloat = 0
        billeAnim = Timer(timeInterval: 1.0/60.0, repeats: true) { [weak self] t in
            guard let self = self else { t.invalidate(); return }
            f -= (1.0/60.0) / 0.4                 // vidage en ~0,4 s
            phase += 0.6
            if f <= 0 {
                t.invalidate(); self.billeAnim = nil
                self.setIcon(fill: 0, dockCustom: true)
                completion()
            } else {
                self.setIcon(fill: f, phase: phase, dockCustom: true)
            }
        }
        RunLoop.main.add(billeAnim!, forMode: .common)
    }
    func updateDisplay() {
        // Le disque se REMPLIT à mesure que le temps s'écoule (plein à la fin).
        let frac = totalSeconds > 0 ? CGFloat(totalSeconds - remainingSeconds)/CGFloat(totalSeconds) : 0
        setIcon(fill: frac, phase: CGFloat(remainingSeconds) * 0.9, dockCustom: true)
        statusItem.button?.attributedTitle = NSAttributedString(string: formatTime(remainingSeconds) + " ", attributes: [
            .font: NSFont.monospacedDigitSystemFont(ofSize: 12, weight: .medium)])
        // Popover de survol
        timerModel.progress = totalSeconds > 0 ? CGFloat(remainingSeconds)/CGFloat(totalSeconds) : 0
        timerModel.timeText = formatTime(remainingSeconds)
    }

    // MARK: Alarme + déclencheurs
    func playAlarm() {
        if settings.alarmOn, let s = NSSound(named: settings.soundName) { s.play() }
        NSApp.requestUserAttention(.criticalRequest)
    }
    // Lance les déclencheurs non destructifs (apps, URL, fermeture)
    func runNonTerminalTriggers() {
        let s = settings
        if s.actNotify { postNotification() }
        if s.actLaunchApp, !s.launchAppPath.isEmpty {
            NSWorkspace.shared.open(URL(fileURLWithPath: s.launchAppPath))
        }
        if s.actOpenURL, let u = URL(string: s.urlString), u.scheme != nil {
            NSWorkspace.shared.open(u)
        }
        if s.actQuitApp { quitChosenApp() }
    }
    func runTriggers() {
        runNonTerminalTriggers()
        // Les actions terminales en dernier
        if settings.actSleep { runAppleScript("tell application \"System Events\" to sleep") }
        if settings.actShutdown { runAppleScript("tell application \"System Events\" to shut down") }
    }
    func testTriggers() { runNonTerminalTriggers() }

    func quitChosenApp() {
        let s = settings
        if !s.quitAppBundleId.isEmpty {
            let apps = NSRunningApplication.runningApplications(withBundleIdentifier: s.quitAppBundleId)
            if !apps.isEmpty { apps.forEach { $0.terminate() }; return }
        }
        if !s.quitAppName.isEmpty { runAppleScript("tell application \"\(asEscape(s.quitAppName))\" to quit") }
    }

    static func setLoginItem(_ on: Bool) {
        if #available(macOS 13, *) {
            do { if on { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() } }
            catch { NSLog("\(appDisplayName) login item: \(error)") }
        }
    }

    // MARK: Menu
    func openSettings() {
        if settingsWindow == nil {
            let view = SettingsView(settings: settings, onTestSound: { [weak self] in
                if let n = self?.settings.soundName { NSSound(named: n)?.play() }
            }, onTestTriggers: { [weak self] in self?.testTriggers() })
            let w = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 772, height: 562),
                             styleMask: [.titled, .closable, .fullSizeContentView], backing: .buffered, defer: false)
            w.title = "Options — \(appDisplayName)"
            w.titlebarAppearsTransparent = true
            w.titleVisibility = .hidden
            w.isMovableByWindowBackground = true
            w.isOpaque = false
            w.backgroundColor = .clear
            let host = NSHostingView(rootView: view)
            w.contentView = host
            w.isReleasedWhenClosed = false
            w.center()
            settingsWindow = w
        }
        NSApp.activate(ignoringOtherApps: true)
        settingsWindow?.makeKeyAndOrderFront(nil)
    }

    func showMenu() {
        let menu = NSMenu()
        if remainingSeconds > 0 {
            let state = timerModel.paused ? "⏸ " + formatTime(remainingSeconds) + " (en pause)"
                                          : "⏳ " + formatTime(remainingSeconds) + " restant"
            let it = NSMenuItem(title: state, action: nil, keyEquivalent: "")
            it.isEnabled = false; menu.addItem(it)
            if totalCycles > 1 || infiniteRepeat {
                let cyc = NSMenuItem(title: infiniteRepeat ? "   répétition ∞ (cycle \(cycleNum))"
                                                           : "   répétition \(cycleNum)/\(totalCycles)",
                                     action: nil, keyEquivalent: "")
                cyc.isEnabled = false; menu.addItem(cyc)
            }
            menu.addItem(NSMenuItem(title: timerModel.paused ? "Reprendre" : "Pause",
                                    action: #selector(menuPause), keyEquivalent: ""))
            menu.addItem(NSMenuItem(title: "Annuler le minuteur", action: #selector(menuCancel), keyEquivalent: ""))
            menu.addItem(.separator())
        } else {
            let hint = NSMenuItem(title: "Tirez vers le bas pour régler", action: nil, keyEquivalent: "")
            hint.isEnabled = false; menu.addItem(hint)
            if timerMinutes > 0 {
                let label = timerMinutes >= 60 ? "Relancer le dernier (\(timerMinutes/60)h\(String(format: "%02d", timerMinutes%60)))"
                                               : "Relancer le dernier (\(timerMinutes) min)"
                menu.addItem(NSMenuItem(title: label, action: #selector(menuRestart), keyEquivalent: ""))
            }
            menu.addItem(.separator())
        }
        for m in [1, 5, 15, 60] {
            let title = m == 60 ? "1 heure" : (m == 1 ? "1 minute" : "\(m) minutes")
            let it = NSMenuItem(title: title, action: #selector(menuPreset(_:)), keyEquivalent: "")
            it.representedObject = m; menu.addItem(it)
        }
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Options…", action: #selector(menuOptions), keyEquivalent: ","))
        menu.addItem(NSMenuItem(title: "À propos de \(appDisplayName)", action: #selector(menuAbout), keyEquivalent: ""))
        for it in menu.items where it.target == nil && it.action != nil { it.target = self }
        // Quitter cible NSApp (terminate: n'existe pas sur le contrôleur)
        let quit = NSMenuItem(title: "Quitter \(appDisplayName)", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        quit.target = NSApp
        menu.addItem(quit)

        statusItem.menu = menu
        statusItem.button?.performClick(nil)
        statusItem.menu = nil
    }
    // MARK: Fenêtre de survol (bille + fenêtre ont chacune une zone de survol)
    // Sélecteurs Obj-C explicites : NSTrackingArea envoie mouseEntered:/mouseExited:
    // (AppController n'étant pas NSResponder, sans ça Swift génèrerait mouseEnteredWith:).
    @objc(mouseEntered:) func mouseEntered(with event: NSEvent) { presentHover() }
    @objc(mouseExited:) func mouseExited(with event: NSEvent) {
        cancelDismiss()
        let work = DispatchWorkItem { [weak self] in
            guard let self = self, !self.mouseOverHoverZone() else { return }
            self.dismissHover()
        }
        hideHoverWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12, execute: work)
    }
    func mouseOverHoverZone() -> Bool {
        let p = NSEvent.mouseLocation
        if let b = statusItem.button, let w = b.window {
            let f = w.convertToScreen(b.convert(b.bounds, to: nil))
            if f.insetBy(dx: -2, dy: -4).contains(p) { return true }
        }
        if let win = hoverWindow, win.isVisible, win.frame.contains(p) { return true }
        return false
    }
    func cancelDismiss() { hideHoverWork?.cancel(); dismissWork?.cancel() }

    func presentHover() {
        cancelDismiss()
        guard remainingSeconds > 0, let b = statusItem.button, let bw = b.window else { return }
        if hoverWindow == nil {
            let win = NSPanel(contentRect: NSRect(x: 0, y: 0, width: 250, height: 320),
                              styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
            win.isOpaque = false
            win.backgroundColor = .clear
            win.hasShadow = true
            win.level = .statusBar
            win.becomesKeyOnlyIfNeeded = true       // permet de cliquer les boutons
            win.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
            let host = NSHostingView(rootView: TimerPopoverView(model: timerModel,
                onPause: { [weak self] in self?.togglePause() },
                onStop:  { [weak self] in self?.cancelTimer() }))
            win.contentView = host
            // Zone de survol sur la fenêtre : y entrer la garde, en sortir la ferme.
            host.addTrackingArea(NSTrackingArea(rect: host.bounds,
                options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect], owner: self, userInfo: nil))
            hoverWindow = win
        }
        let f = bw.convertToScreen(b.convert(b.bounds, to: nil))
        let size = hoverWindow!.frame.size
        hoverWindow!.setFrameOrigin(NSPoint(x: f.midX - size.width/2, y: f.minY - size.height + 6))
        if !hoverWindow!.isVisible {
            timerModel.appeared = false
            hoverWindow!.orderFrontRegardless()
            DispatchQueue.main.async { [weak self] in self?.timerModel.appeared = true }   // éclosion
        } else {
            timerModel.appeared = true   // ré-entrée pendant la fermeture → re-grandit
        }
    }
    // Ferme avec animation : la carte se rétracte vers la bille, puis on retire la fenêtre.
    func dismissHover() {
        timerModel.appeared = false
        let work = DispatchWorkItem { [weak self] in self?.hoverWindow?.orderOut(nil) }
        dismissWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.36, execute: work)
    }
    func closeHoverPopover() {
        cancelDismiss()
        timerModel.appeared = false
        hoverWindow?.orderOut(nil)
    }

    @objc func showMenuDeferred() { showMenu() }
    @objc func menuPause() { togglePause() }
    @objc func menuRestart() { if timerMinutes > 0 { startTimer(minutes: timerMinutes) } }
    @objc func menuCancel() { cancelTimer() }
    @objc func menuOptions() { openSettings() }
    @objc func menuUpdate() { Updater.shared.checkForUpdates() }
    @objc func menuAbout() { openAbout() }

    // Menu principal : permet ⌘W (fermer fenêtre), ⌘Q, et l'édition de texte standard
    // dans les fenêtres (Options / À propos), même pour une app agent.
    func buildMainMenu() {
        let mainMenu = NSMenu()

        let appItem = NSMenuItem(); mainMenu.addItem(appItem)
        let appMenu = NSMenu()
        let about = appMenu.addItem(withTitle: "À propos de \(appDisplayName)", action: #selector(menuAbout), keyEquivalent: "")
        about.target = self
        appMenu.addItem(.separator())
        appMenu.addItem(withTitle: "Rechercher les mises à jour…", action: #selector(menuUpdate), keyEquivalent: "").target = self
        appMenu.addItem(.separator())
        appMenu.addItem(withTitle: "Préférences…", action: #selector(menuOptions), keyEquivalent: ",").target = self
        appMenu.addItem(.separator())
        appMenu.addItem(withTitle: "Quitter \(appDisplayName)", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        appItem.submenu = appMenu

        let editItem = NSMenuItem(); mainMenu.addItem(editItem)
        let editMenu = NSMenu(title: "Édition")
        editMenu.addItem(withTitle: "Annuler", action: Selector(("undo:")), keyEquivalent: "z")
        editMenu.addItem(withTitle: "Rétablir", action: Selector(("redo:")), keyEquivalent: "Z")
        editMenu.addItem(.separator())
        editMenu.addItem(withTitle: "Couper", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        editMenu.addItem(withTitle: "Copier", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        editMenu.addItem(withTitle: "Coller", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        editMenu.addItem(withTitle: "Tout sélectionner", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
        editItem.submenu = editMenu

        let winItem = NSMenuItem(); mainMenu.addItem(winItem)
        let winMenu = NSMenu(title: "Fenêtre")
        winMenu.addItem(withTitle: "Fermer", action: #selector(NSWindow.performClose(_:)), keyEquivalent: "w")
        winMenu.addItem(withTitle: "Réduire", action: #selector(NSWindow.miniaturize(_:)), keyEquivalent: "m")
        winItem.submenu = winMenu
        NSApp.windowsMenu = winMenu

        NSApp.mainMenu = mainMenu
    }

    func openAbout() {
        if aboutWindow == nil {
            let w = NSWindow(contentViewController: NSHostingController(rootView: AboutView()))
            w.styleMask = [.titled, .closable]
            w.titleVisibility = .hidden
            w.titlebarAppearsTransparent = true
            w.isMovableByWindowBackground = true
            w.appearance = NSAppearance(named: .darkAqua)
            w.backgroundColor = NSColor(calibratedRed: 0.11, green: 0.11, blue: 0.12, alpha: 1)
            w.standardWindowButton(.miniaturizeButton)?.isHidden = true
            w.standardWindowButton(.zoomButton)?.isHidden = true
            w.isReleasedWhenClosed = false
            aboutWindow = w
        }
        aboutWindow?.center()
        NSApp.activate(ignoringOtherApps: true)
        aboutWindow?.makeKeyAndOrderFront(nil)
    }
    @objc func menuPreset(_ sender: NSMenuItem) { if let m = sender.representedObject as? Int { startTimer(minutes: m) } }

    func userNotificationCenter(_ c: UNUserNotificationCenter, willPresent n: UNNotification,
                                withCompletionHandler h: @escaping (UNNotificationPresentationOptions) -> Void) {
        h([.banner, .sound])
    }

    // Clic sur l'icône du Dock → ouvrir les Options
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows: Bool) -> Bool {
        openSettings(); return true
    }
}

let app = NSApplication.shared
let controller = AppController()
app.delegate = controller
app.setActivationPolicy(controller.settings.showInDock ? .regular : .accessory)
app.run()
