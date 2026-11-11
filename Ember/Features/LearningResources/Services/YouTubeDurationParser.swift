import Foundation

enum YouTubeDurationParser {
    static func seconds(from value: String) -> Int? {
        guard value.first == "P" else { return nil }

        var total = 0
        var digits = ""
        var isTime = false
        var consumedComponent = false

        for character in value.dropFirst() {
            if character == "T" {
                guard digits.isEmpty, !isTime else { return nil }
                isTime = true
                continue
            }
            if character.isNumber {
                digits.append(character)
                continue
            }
            guard let amount = Int(digits) else { return nil }
            digits = ""

            switch character {
            case "D" where !isTime:
                total += amount * 86_400
            case "H" where isTime:
                total += amount * 3_600
            case "M" where isTime:
                total += amount * 60
            case "S" where isTime:
                total += amount
            default:
                return nil
            }
            consumedComponent = true
        }

        guard digits.isEmpty, consumedComponent else { return nil }
        return total
    }
}
