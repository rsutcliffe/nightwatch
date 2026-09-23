import Testing
import Foundation
@testable import SkyCore

@Test func moonApiUrlUsesUtcHour() {
    // 2026-09-23 21:17 UTC → the 21:00 slot
    let d = utc(2026, 9, 23, 21, 17)
    #expect(MoonImage.apiURL(for: d).absoluteString == "https://svs.gsfc.nasa.gov/api/dialamoon/2026-09-23T21:00")
    #expect(MoonImage.hourKey(for: d) == "2026092321")
}

// Shape verified against the live service on 2026-09-23 (top-level keys image, phase, age, …).
@Test func moonParseReadsImageAndPhase() throws {
    let json = """
    {"image":{"url":"https://svs.gsfc.nasa.gov/vis/a000000/a005500/a005587/frames/730x730_1x1_30p/moon.6382.jpg"},
     "image_highres":{"url":"x"},"time":"2026-09-23T21:00","phase":91.38,"obscuration":0.0,"age":12.731,"diameter":1829.3}
    """.data(using: .utf8)!
    let info = try MoonImage.parse(json)
    #expect(info.imageURL.absoluteString.hasSuffix("moon.6382.jpg"))
    #expect(abs(info.phasePercent - 91.38) < 1e-9)
    #expect(abs(info.ageDays - 12.731) < 1e-9)
}
