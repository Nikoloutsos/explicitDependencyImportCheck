/// The root class for the JSON report
public struct SitrepResponse: Decodable {
    /// A named statistical value
    public struct Import: Decodable {
        /// Name of the statistic
        public var targetName: String
        /// Value of the statistic
        public var timesImported: Int
        
        enum CodingKeys: String, CodingKey {
            case targetName = "name"
            case timesImported = "value"
        }
    }
    /// Import statistics
    public var imports: [Import]
}
