import Foundation

/// "How to shoot this" on a target's detail page (v0.6.7): filter, exposure and frames for the user's own instrument and
/// this kind of target, sized to tonight's clear window. Every number comes from the maker's own material, named in
/// `source`; where none was found (planets, ISO on a camera) the tip gives guidance without numbers.
public struct ShootingTip: Equatable, Sendable {
    public var title: String
    public var rows: [Row]
    public var source: String?
    public struct Row: Equatable, Sendable {
        public var label: String
        public var text: String
        public init(_ label: String, _ text: String) { self.label = label; self.text = text }
    }
}

public enum ShootingTips {
    /// What kind of light the target gives, which decides the filter.
    enum Kind: Equatable { case emission, broadband, nebulaUnknown, moon, planet, constellation }

    static func kind(_ t: RankedTarget) -> Kind {
        if t.id == "moon" { return .moon }
        if t.id.hasPrefix("planet-") { return .planet }
        switch t.group {
        case .constellations: return .constellation
        case .galaxies, .clusters: return t.typeName == "Cluster with nebula" ? .emission : .broadband
        default: break
        }
        switch t.typeName {
        case "Emission nebula", "Planetary nebula", "Supernova remnant", "Cluster with nebula": return .emission
        case "Reflection nebula", "Dark nebula": return .broadband
        default: return .nebulaUnknown
        }
    }

    /// `stackMinutes`: the detail page's suggested stack (tonight's window, up to 3 h); nil when there is no clear window.
    public static func tip(for t: RankedTarget, presetID: String?, presetName: String?, stackMinutes: Double?, site: Site) -> ShootingTip {
        let k = kind(t)
        var rows: [ShootingTip.Row] = []
        var source: String?
        let name = presetName ?? "your telescope"
        let hours = stackMinutes.map { String(format: "%.1f h", $0 / 60).replacingOccurrences(of: ".0 h", with: " h") }
        func frames(_ seconds: Double) -> Int? { stackMinutes.map { Int(($0 * 60 / seconds).rounded()) } }

        switch presetID {
        case "dwarf-mini", "dwarf-3":
            source = "Settings from DWARFLAB's user manual."
            switch k {
            case .moon:
                rows.append(.init("Mode", "Use the Moon mode: it sets focus, exposure and gain for you (about 1/250 s, gain 0, Astro filter)."))
                rows.append(.init("Frames", "Start with 20–30 images."))
            case .planet:
                rows.append(.init("Expect", "A small bright disc at this focal length; Jupiter's and Saturn's larger moons show as points."))
                source = nil
            case .constellation:
                rows.append(.init("Framing", "Far larger than the field of view: use a wide-angle lens, or pick one bright object in it."))
                source = nil
            default:
                rows.append(.init("Filter", filterText(k, dualBand: "Duo-Band", broadband: "Astro")))
                rows.append(.init("Exposure", "15–60 s per frame at gain 60–80 (try 30 s)."))
                if let n = frames(30), let h = hours {
                    rows.append(.init("Frames", "200–400 recommended; \(n) × 30 s fills \(h) of tonight's window."))
                } else {
                    rows.append(.init("Frames", "200–400 recommended."))
                }
            }
        case "seestar-s50":
            source = "Filters and frame length from ZWO's Seestar S50 FAQ."
            switch k {
            case .moon:
                rows.append(.init("Mode", "Use Lunar mode: it finds and tracks the Moon for you."))
            case .planet:
                rows.append(.init("Expect", "A small bright disc at this focal length; Jupiter's and Saturn's larger moons show as points."))
                source = nil
            case .constellation:
                rows.append(.init("Framing", "Far larger than the field of view: use a wide-angle lens, or pick one bright object in it."))
                source = nil
            default:
                rows.append(.init("Filter", filterText(k, dualBand: "Light-pollution filter on", broadband: "Light-pollution filter off (UV/IR cut)")))
                rows.append(.init("Exposure", "10 s frames; the Seestar stacks them as it goes."))
                if let n = frames(10), let h = hours {
                    rows.append(.init("Frames", "Let it stack for the window: \(h) is about \(n) frames. Faint targets need at least half an hour."))
                } else {
                    rows.append(.init("Frames", "Let it stack for as long as you can: faint targets need at least half an hour."))
                }
            }
        case "dslr-apsc-200":
            source = "Exposure guidance from the 500 and NPF rules for untracked shots."
            switch k {
            case .moon:
                rows.append(.init("Exposure", "The Moon is bright: use short exposures and check the histogram."))
                source = nil
            case .planet:
                rows.append(.init("Expect", "A tiny disc at 200 mm; Jupiter's larger moons show as points."))
                source = nil
            default:
                rows.append(.init("Exposure", "On a star tracker, 60–120 s in the suburbs and longer at a dark site. Without one, under about 1.5 s before stars trail."))
                if let h = hours, let n = frames(120) {
                    rows.append(.init("Frames", "Take as many as the window allows: \(h) is about \(n) × 120 s on a tracker."))
                }
                if k == .emission || k == .nebulaUnknown {
                    rows.append(.init("Filter", "A dual-band or light-pollution filter lifts an emission nebula out of a bright sky."))
                }
            }
        default:
            switch k {
            case .moon, .planet, .constellation:
                rows.append(.init("Tip", "Check your instrument's manual for its Moon, planet or wide-field settings."))
            default:
                rows.append(.init("Filter", filterText(k, dualBand: "A dual-band or narrowband filter", broadband: "No filter, or a light-pollution filter only")))
                rows.append(.init("Exposure", "Check your telescope's manual for exposure and gain."))
                if let h = hours { rows.append(.init("Frames", "Tonight's window allows up to \(h) of frames.")) }
            }
        }

        if let v = t.viewable, k != .constellation {
            rows.append(.init("When", "Start at \(Copy.hhmm(v.start, site: site)), when it is clear and high enough; it is best at \(Copy.hhmm(t.peakTime, site: site))."))
        }
        return ShootingTip(title: "How to shoot this with \(presetName == nil ? "your telescope" : "your \(name)")", rows: rows, source: source)
    }

    static func filterText(_ k: Kind, dualBand: String, broadband: String) -> String {
        switch k {
        case .emission: "\(dualBand): it passes the hydrogen-alpha and oxygen-III light an emission nebula gives off."
        case .broadband: "\(broadband): galaxies, star clusters and reflection nebulae shine across the spectrum, so a narrow filter would cut their light."
        default: "\(dualBand) if it glows red (an emission nebula); \(broadband.prefix(1).lowercased() + broadband.dropFirst()) if it is a reflection or dark nebula."
        }
    }
}
