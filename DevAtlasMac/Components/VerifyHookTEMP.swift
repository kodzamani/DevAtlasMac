import SwiftUI
import AppKit
extension Notification.Name {
    static let daVerifyDeps = Notification.Name("daVerifyDeps")
    static let daVerifyStats = Notification.Name("daVerifyStats")
}
@MainActor enum VerifyHookTEMP {
    static var installed = false
    static func install(_ vm: AppViewModel) {
        guard !installed else { return }
        installed = true
        DistributedNotificationCenter.default().addObserver(forName: .init("da.verify"), object: nil, queue: .main) { n in
            let cmd = (n.object as? String) ?? ""
            MainActor.assumeIsolated {
                if cmd.hasPrefix("open:") {
                    let name = String(cmd.dropFirst(5))
                    vm.selectedTab = .atlas
                    if let p = vm.projects.first(where: { $0.name == name }) { vm.selectProject(p) }
                } else if cmd == "analyze" { vm.isShowingProjectAnalysis = true }
                else if cmd == "back" { vm.isShowingProjectAnalysis = false }
                else if cmd == "navback" { vm.navigateBack() }
                else if cmd == "deps" { NotificationCenter.default.post(name: .daVerifyDeps, object: nil) }
                else if cmd == "tabstats" { vm.selectedTab = .stats }
                else if cmd == "statsanalyze" { NotificationCenter.default.post(name: .daVerifyStats, object: nil) }
                else if cmd == "dark" { vm.isDarkMode.toggle() }
                else if cmd.hasPrefix("size:") {
                    let v = cmd.dropFirst(5).split(separator: ",").compactMap { Double($0) }
                    if let w = NSApp.windows.first(where: { $0.isVisible && $0.frame.width > 400 }) {
                        var f = w.frame; f.origin.y += f.height - v[1]; f.size = CGSize(width: v[0], height: v[1]); w.setFrame(f, display: true)
                    }
                } else if cmd.hasPrefix("scroll:") {
                    let y = Double(cmd.dropFirst(7)) ?? 0
                    func all(_ v: NSView) -> [NSScrollView] { (v as? NSScrollView).map { [$0] } ?? v.subviews.flatMap(all) }
                    if let w = NSApp.windows.first(where: { $0.isVisible && $0.frame.width > 400 }), let c = w.contentView {
                        let s = all(c).filter { ($0.documentView?.frame.height ?? 0) > 700 }
                        for sv in s { sv.contentView.scroll(to: NSPoint(x: 0, y: y)); sv.reflectScrolledClipView(sv.contentView) }
                    }
                }
            }
        }
    }
}
