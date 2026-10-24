import Foundation

extension String {
    /// The text with every en dash and em dash turned into a plain hyphen. The Mac's wording uses an en dash in time ranges;
    /// this app uses hyphens everywhere (owner's rule, 14 October 2026). Apply it to any wording that comes from SkyCore before it is shown.
    public var plainDashes: String {
        replacingOccurrences(of: "\u{2014}", with: "-").replacingOccurrences(of: "\u{2013}", with: "-")
    }
}
