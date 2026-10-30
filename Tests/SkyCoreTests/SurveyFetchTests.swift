import Foundation
import Testing
@testable import SkyCore

private final class Calls: @unchecked Sendable {
    private let lock = NSLock()
    private var urls: [URL] = []
    func add(_ u: URL) { lock.lock(); urls.append(u); lock.unlock() }
    var hosts: [String] { lock.lock(); defer { lock.unlock() }; return urls.compactMap(\.host) }
}

@Suite struct SurveyFetchTests {
    let cds = URL(string: "https://alasky.cds.unistra.fr/hips-image-services/hips2fits?hips=CDS/P/DSS2/color&ra=83.82000&dec=-5.39000&fov=2.100&width=480&height=270&projection=TAN&format=jpg")!
    let jpeg = Data([0xFF, 0xD8, 0xFF, 0xE0, 0x00])

    @Test func theSkyViewRequestCoversTheSameSky() throws {
        let u = try #require(SkyViewCutout.fallback(for: cds))
        let q = Dictionary(uniqueKeysWithValues: URLComponents(url: u, resolvingAgainstBaseURL: false)!.queryItems!.map { ($0.name, $0.value ?? "") })
        #expect(u.host == "skyview.gsfc.nasa.gov")
        #expect(q["Position"] == "83.82000,-5.39000")
        #expect(q["Pixels"] == "480,270")
        #expect(q["Size"] == "2.1000,1.1812")
        #expect(q["Return"] == "JPEG")
    }

    @Test func aLargeImageIsAskedForAtTheWidthSkyViewServes() throws {
        let big = URL(string: cds.absoluteString.replacingOccurrences(of: "width=480&height=270", with: "width=1600&height=900"))!
        let q = URLComponents(url: try #require(SkyViewCutout.fallback(for: big)), resolvingAgainstBaseURL: false)!.queryItems!
        #expect(q.first { $0.name == "Pixels" }?.value == "1200,675")
    }

    @Test func otherAddressesHaveNoFallback() {
        #expect(SkyViewCutout.fallback(for: URL(string: "https://example.com/a.jpg")!) == nil)
    }

    @Test func cdsAnsweringIsEnoughAndSkyViewIsNotAsked() async {
        let calls = Calls()
        let data = await SurveyFetch().image(cds, timeout: 1) { u, _ in calls.add(u); return self.jpeg }
        #expect(data == jpeg)
        #expect(calls.hosts == ["alasky.cds.unistra.fr"])
    }

    @Test func skyViewIsUsedWhenCdsFailsAndCdsIsLeftAloneForTenMinutes() async {
        let calls = Calls(), jpeg = self.jpeg
        let fetch = SurveyFetch(), now = Date()
        let get: SurveyFetch.Get = { u, _ in calls.add(u); if u.host == "alasky.cds.unistra.fr" { throw URLError(.timedOut) }; return jpeg }
        #expect(await fetch.image(cds, timeout: 1, now: now, retryDelay: .zero, get: get) == jpeg)
        #expect(await fetch.image(cds, timeout: 1, now: now.addingTimeInterval(60), retryDelay: .zero, get: get) == jpeg)
        #expect(calls.hosts == ["alasky.cds.unistra.fr", "skyview.gsfc.nasa.gov", "skyview.gsfc.nasa.gov"])
        _ = await fetch.image(cds, timeout: 1, now: now.addingTimeInterval(601), get: get)
        #expect(calls.hosts.last == "skyview.gsfc.nasa.gov" && calls.hosts.filter { $0 == "alasky.cds.unistra.fr" }.count == 2)
    }

    @Test func aBusyPageFromSkyViewIsNotAnImage() async {
        let busy = Data("<html>Too Many Processes</html>".utf8)
        let data = await SurveyFetch().image(cds, timeout: 1, retryDelay: .zero) { u, _ in if u.host == "alasky.cds.unistra.fr" { throw URLError(.cannotConnectToHost) }; return busy }
        #expect(data == nil)
    }

    @Test func aBusySkyViewIsTriedAgainAndTheSecondAnswerIsUsed() async {
        let calls = Calls(), jpeg = self.jpeg, busy = Data("<html>Too Many Processes</html>".utf8)
        let get: SurveyFetch.Get = { u, _ in
            calls.add(u)
            if u.host == "alasky.cds.unistra.fr" { throw URLError(.timedOut) }
            return calls.hosts.filter { $0 == "skyview.gsfc.nasa.gov" }.count < 2 ? busy : jpeg
        }
        #expect(await SurveyFetch().image(cds, timeout: 1, retryDelay: .zero, get: get) == jpeg)
        #expect(calls.hosts.count == 3)
    }
}
