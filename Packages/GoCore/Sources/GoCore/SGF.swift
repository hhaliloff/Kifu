// MARK: - SGF (FF[4]) parser & writer

import Foundation

public enum SGFError: Error, Equatable {
    case unbalancedParentheses
    case unexpectedCharacter(offset: Int)
    case emptyInput
    case inputTooLarge
    case nestingTooDeep
    case tooManyNodes
    case unsupportedBoardSize
    case unsupportedSetupEdit
}

/// A node in an SGF game tree. Property order is preserved; unknown
/// properties are kept for lossless round-tripping.
public final class SGFNode: @unchecked Sendable {
    /// Ordered properties: (identifier, values).
    public private(set) var properties: [(id: String, values: [String])] = []
    /// Child nodes. Multiple children = variations; order = branch order.
    public var children: [SGFNode] = []

    public init() {}

    public func values(for ident: String) -> [String]? {
        properties.first { $0.id == ident }?.values
    }

    public func firstValue(_ ident: String) -> String? {
        values(for: ident)?.first
    }

    public func hasProperty(_ ident: String) -> Bool {
        properties.contains { $0.id == ident }
    }

    /// Sets or replaces a property (keeps original position if replacing).
    public func set(_ ident: String, _ values: [String]) {
        if let idx = properties.firstIndex(where: { $0.id == ident }) {
            properties[idx].values = values
        } else {
            properties.append((ident, values))
        }
    }

    public func remove(_ ident: String) {
        properties.removeAll { $0.id == ident }
    }
}

/// A parsed SGF game (one game tree).
public struct SGFGame: Sendable {
    public var root: SGFNode

    public init(root: SGFNode) { self.root = root }
}

// MARK: - Parser

public enum SGFParser {
    /// Point-list properties whose values may use compressed rectangles.
    /// (AR/LN excluded: their "aa:bb" pairs are endpoints, not regions.)
    static let pointListProperties: Set<String> = [
        "AB", "AW", "AE", "TR", "SQ", "CR", "MA", "SL", "DD", "VW", "TB", "TW"
    ]

    /// Parses an SGF collection (one or more games).
    public static func parse(_ text: String) throws -> [SGFGame] {
        guard text.utf8.count <= 5_000_000 else { throw SGFError.inputTooLarge }
        var scanner = Scanner(text: Array(text.unicodeScalars))
        var games: [SGFGame] = []
        scanner.skipWhitespace()
        guard !scanner.atEnd else { throw SGFError.emptyInput }
        while !scanner.atEnd {
            scanner.skipWhitespace()
            guard scanner.peek() == "(" else {
                throw SGFError.unexpectedCharacter(offset: scanner.offset)
            }
            let tree = try parseGameTree(&scanner, depth: 0)
            games.append(SGFGame(root: tree))
            scanner.skipWhitespace()
        }
        return games
    }

    /// GameTree = "(" Sequence GameTree* ")"
    static func parseGameTree(_ scanner: inout Scanner, depth: Int) throws -> SGFNode {
        guard depth < 128 else { throw SGFError.nestingTooDeep }
        guard scanner.consume("(") else { throw SGFError.unexpectedCharacter(offset: scanner.offset) }
        var first: SGFNode? = nil
        var last: SGFNode? = nil
        // Sequence = Node+
        while true {
            scanner.skipWhitespace()
            if scanner.peek() == ";" {
                let node = try parseNode(&scanner)
                if let l = last { l.children.append(node) } else { first = node }
                last = node
            } else {
                break
            }
        }
        guard first != nil else { throw SGFError.unexpectedCharacter(offset: scanner.offset) }
        // GameTree*
        while true {
            scanner.skipWhitespace()
            if scanner.peek() == "(" {
                let sub = try parseGameTree(&scanner, depth: depth + 1)
                last?.children.append(sub)
            } else {
                break
            }
        }
        guard scanner.consume(")") else { throw SGFError.unbalancedParentheses }
        return first!
    }

    /// Node = ";" Property*
    static func parseNode(_ scanner: inout Scanner) throws -> SGFNode {
        guard scanner.consume(";") else { throw SGFError.unexpectedCharacter(offset: scanner.offset) }
        scanner.nodeCount += 1
        guard scanner.nodeCount <= 50_000 else { throw SGFError.tooManyNodes }
        let node = SGFNode()
        while true {
            scanner.skipWhitespace()
            guard let c = scanner.peek(), Self.isASCIILetter(c) else { break }
            // Property identifier: uppercase letters (FF[4]); be lenient
            // and accept any letters, normalizing to uppercase.
            var ident = ""
            while let ch = scanner.peek(), Self.isASCIILetter(ch) {
                ident.append(Character(ch))
                _ = scanner.advance()
            }
            ident = ident.uppercased()
            guard !ident.isEmpty else { break }
            // Values: one or more bracketed values.
            var values: [String] = []
            scanner.skipWhitespace()
            while scanner.peek() == "[" {
                var value = try parseValue(&scanner)
                if pointListProperties.contains(ident) {
                    value = Self.expandCompressedPointsIfNeeded(value)
                }
                values.append(value)
                scanner.skipWhitespace()
            }
            guard !values.isEmpty else { throw SGFError.unexpectedCharacter(offset: scanner.offset) }
            node.set(ident, values)
        }
        return node
    }

    /// PropValue = "[" escaped-text "]"
    static func parseValue(_ scanner: inout Scanner) throws -> String {
        guard scanner.consume("[") else { throw SGFError.unexpectedCharacter(offset: scanner.offset) }
        var out = String.UnicodeScalarView()
        while true {
            guard let ch = scanner.advance() else { throw SGFError.unbalancedParentheses }
            switch ch {
            case "]":
                return String(out)
            case "\\":
                if let next = scanner.advance() {
                    if next == "\n" {
                        // Soft linebreak: remove entirely.
                    } else if next == "\r" {
                        // Handle "\r\n" soft break.
                        if scanner.peek() == "\n" { _ = scanner.advance() }
                    } else {
                        out.append(next)
                    }
                }
            default:
                out.append(ch)
            }
        }
    }

    /// Expands a compressed point rectangle "aa:cc" into a space-separated
    /// list of points ("aa ab ac ..."). Only valid inside point-list values.
    static func expandCompressedPointsIfNeeded(_ value: String) -> String {
        // Detect top-level ':' not escaped — compressed list syntax.
        var parts: [String] = []
        var current = ""
        var escaped = false
        for ch in value {
            if escaped { current.append(ch); escaped = false; continue }
            if ch == "\\" { current.append(ch); escaped = true; continue }
            if ch == ":" {
                parts.append(current)
                current = ""
                continue
            }
            current.append(ch)
        }
        parts.append(current)
        guard parts.count == 2, parts[0].count == 2, parts[1].count == 2 else { return value }
        func isPoint(_ s: String) -> Bool { s.allSatisfy { $0.isASCII && $0.isLetter } }
        guard isPoint(parts[0]), isPoint(parts[1]) else { return value }
        guard let from = sgfPoint(parts[0]), let to = sgfPoint(parts[1]) else { return value }
        var points: [String] = []
        let minCol = min(from.x, to.x), maxCol = max(from.x, to.x)
        let minRow = min(from.y, to.y), maxRow = max(from.y, to.y)
        for row in minRow...maxRow {
            for col in minCol...maxCol {
                points.append(sgfString(Point(x: col, y: row)))
            }
        }
        return points.joined(separator: " ")
    }

    /// "pd" → Point(x: 15, y: 3). Uppercase letters for boards > 26.
    public static func sgfPoint(_ s: String) -> Point? {
        let scalars = Array(s.unicodeScalars)
        guard scalars.count == 2 else { return nil }
        func coord(_ c: Unicode.Scalar) -> Int? {
            let v = c.value
            if v >= 97 && v <= 122 { return Int(v - 97) }        // a-z
            if v >= 65 && v <= 90 { return Int(v - 65 + 26) }    // A-Z (27..52)
            return nil
        }
        guard let x = coord(scalars[0]), let y = coord(scalars[1]) else { return nil }
        return Point(x: x, y: y)
    }

    static func isASCIILetter(_ c: Unicode.Scalar) -> Bool {
        (c.value >= 65 && c.value <= 90) || (c.value >= 97 && c.value <= 122)
    }

    public static func sgfString(_ p: Point) -> String {
        func letter(_ v: Int) -> Character {
            if v < 26 { return Character(UnicodeScalar(UInt8(97 + v))) }
            return Character(UnicodeScalar(UInt8(65 + v - 26)))
        }
        return "\(letter(p.x))\(letter(p.y))"
    }

    /// Lightweight character scanner over Unicode scalars.
    struct Scanner {
        let scalars: [Unicode.Scalar]
        var offset: Int = 0
        var nodeCount = 0

        init(text: [Unicode.Scalar]) { scalars = text }

        var atEnd: Bool { offset >= scalars.count }

        func peek() -> Unicode.Scalar? { offset < scalars.count ? scalars[offset] : nil }

        mutating func advance() -> Unicode.Scalar? {
            guard offset < scalars.count else { return nil }
            defer { offset += 1 }
            return scalars[offset]
        }

        @discardableResult
        mutating func consume(_ c: Character) -> Bool {
            guard let p = peek(), String(p) == String(c) else { return false }
            offset += 1
            return true
        }

        mutating func skipWhitespace() {
            while let c = peek(), c == " " || c == "\n" || c == "\r" || c == "\t" {
                offset += 1
            }
        }
    }
}

// MARK: - Writer

public enum SGFWriter {
    /// Serializes a collection of games.
    public static func write(games: [SGFGame]) -> String {
        games.map(write(game:)).joined()
    }

    public static func write(game: SGFGame) -> String {
        var out = ""
        write(node: game.root, into: &out)
        return out
    }

    static func write(node: SGFNode, into out: inout String) {
        out += "("
        var current: SGFNode? = node
        while let n = current {
            out += ";"
            for prop in n.properties {
                out += prop.id
                for value in prop.values {
                    out += "["
                    out += escape(value, isLongText: prop.id == "C" || prop.id == "GC")
                    out += "]"
                }
            }
            if n.children.count == 1 {
                current = n.children[0]
            } else {
                break
            }
        }
        if let last = current {
            for child in last.children {
                write(node: child, into: &out)
            }
        }
        out += ")"
    }

    /// Escapes a value: `\]` and `\\`; adds soft linebreaks every ~78
    /// characters for long text properties (on the already-escaped text).
    public static func escape(_ value: String, isLongText: Bool) -> String {
        var escaped = ""
        escaped.reserveCapacity(value.count + 8)
        for ch in value {
            if ch == "]" { escaped += "\\]" }
            else if ch == "\\" { escaped += "\\\\" }
            else { escaped.append(ch) }
        }
        guard isLongText, escaped.count > 78 else { return escaped }
        return softWrap(escaped, at: 78)
    }

    /// Inserts soft breaks ("\" + newline) at whitespace near `width`.
    static func softWrap(_ text: String, at width: Int) -> String {
        var result = ""
        var lineLength = 0
        for word in text.split(separator: " ", omittingEmptySubsequences: false) {
            let w = String(word)
            if lineLength + w.count + 1 > width && lineLength > 0 {
                // SGF removes the escaped newline. Keep the word separator
                // before it so export/import preserves the comment text.
                result += " \\\n"
                lineLength = 0
            } else if lineLength > 0 {
                result += " "
                lineLength += 1
            }
            result += w
            lineLength += w.count
        }
        return result
    }
}
