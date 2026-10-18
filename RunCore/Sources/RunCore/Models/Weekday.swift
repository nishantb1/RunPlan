import Foundation

/// A day of the week. Raw values match `Calendar` weekday numbers (1 is Sunday), while
/// `allCases` and sorting run Monday first.
public enum Weekday: Int, Codable, CaseIterable, Comparable, Sendable {
    case monday = 2
    case tuesday = 3
    case wednesday = 4
    case thursday = 5
    case friday = 6
    case saturday = 7
    case sunday = 1

    public init(of date: Date, calendar: Calendar) {
        self = Weekday(rawValue: calendar.component(.weekday, from: date)) ?? .monday
    }

    /// 0 for Monday through 6 for Sunday.
    public var mondayFirstIndex: Int {
        (rawValue + 5) % 7
    }

    public var name: String {
        switch self {
        case .monday: return "Monday"
        case .tuesday: return "Tuesday"
        case .wednesday: return "Wednesday"
        case .thursday: return "Thursday"
        case .friday: return "Friday"
        case .saturday: return "Saturday"
        case .sunday: return "Sunday"
        }
    }

    public static func < (lhs: Weekday, rhs: Weekday) -> Bool {
        lhs.mondayFirstIndex < rhs.mondayFirstIndex
    }
}
