import Foundation

// MARK: - String validation
public extension String {
    var isValidEmail: Bool {
        let pattern = #"^[A-Z0-9a-z._%+\-]+@[A-Za-z0-9.\-]+\.[A-Za-z]{2,}$"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return false }
        let range = NSRange(startIndex..., in: self)
        return regex.firstMatch(in: self, range: range) != nil
    }

    var isValidPassword: Bool {
        count >= 8
    }
}

// MARK: - NumberFormatter
public extension NumberFormatter {
    static func currency(code: String = "USD") -> NumberFormatter {
        let fmt = NumberFormatter()
        fmt.numberStyle = .currency
        fmt.currencyCode = code
        fmt.maximumFractionDigits = 2
        fmt.minimumFractionDigits = 2
        return fmt
    }
}

// MARK: - Double currency formatting
public extension Double {
    func formatted(asCurrency currency: String) -> String {
        NumberFormatter.currency(code: currency).string(from: NSNumber(value: self)) ?? "\(currency) \(self)"
    }
}

// MARK: - DateFormatter
public extension DateFormatter {
    static let display: DateFormatter = {
        let fmt = DateFormatter()
        fmt.dateStyle = .medium
        fmt.timeStyle = .short
        return fmt
    }()

    static let shortDate: DateFormatter = {
        let fmt = DateFormatter()
        fmt.dateStyle = .short
        fmt.timeStyle = .none
        return fmt
    }()
}

public extension Date {
    var displayString: String {
        DateFormatter.display.string(from: self)
    }

    var shortDateString: String {
        DateFormatter.shortDate.string(from: self)
    }
}

#if canImport(SwiftUI)
import SwiftUI

// MARK: - Brand colors
public extension Color {
    static let payPilotBlue   = Color(red: 0.10, green: 0.37, blue: 0.95)
    static let payPilotGreen  = Color(red: 0.15, green: 0.72, blue: 0.44)
    static let payPilotOrange = Color(red: 0.95, green: 0.47, blue: 0.10)
}

// MARK: - View helpers
public extension View {
    func cardStyle() -> some View {
        self
            .padding()
            .background(Color(.systemBackground))
            .cornerRadius(12)
            .shadow(color: Color.black.opacity(0.08), radius: 6, x: 0, y: 2)
    }
}
#endif // canImport(SwiftUI)
