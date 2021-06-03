public struct Parser<Output> {
    let parse: (Substring) -> (Substring, Output)?

    public init(_ parse: @escaping (Substring) -> (Substring, Output)?) {
        self.parse = parse
    }
}

public extension Parser {
    func map<Other>(_ fn: @escaping (Output) -> Other) -> Parser<Other> {
        return Parser<Other> {
            guard let (rest, result) = parse($0) else { return nil }
            return (rest, fn(result))
        }
    }

    func flatMap<Other>(_ fn: @escaping (Output) -> Parser<Other>) -> Parser<Other> {
        return Parser<Other> {
            guard let (rest, result) = parse($0) else { return nil }
            return fn(result).parse(rest)
        }
    }

    func optional() -> Parser<Output?> {
        return Parser<Output?> {
            if let (rest, result) = parse($0) {
                return (rest, result)
            }

            return ($0, nil)
        }
    }

    func repeated() -> Parser<[Output]> {
        return reduce(into: []) { $0.append($1) }
    }

    func repeated<T>(separator: Parser<T>) -> Parser<[Output]> {
        return Parser<[Output]> {
            var result: [Output] = []
            var input = $0

            func skipSeparator() -> Bool {
                guard let (next, _) = separator.parse(input) else {
                    return false
                }

                input = next
                return true
            }

            repeat {
                guard let (next, item) = parse(input) else {
                    return nil
                }
                result.append(item)
                input = next
            } while skipSeparator()

            return (input, result)
        }
    }

    func reduce<T>(into: T, _ fn: @escaping (inout T, Output) -> Void) -> Parser<T> {
        return Parser<T> {
            var result = into
            var rest = $0
            while let (next, element) = self.parse(rest) {
                rest = next
                fn(&result, element)
            }

            return (rest, result)
        }
    }

    func then<Other>(_ p: Parser<Other>) -> Parser<(Output, Other)> {
        return Parsers.sequence(self, p)
    }

    func followedBy<Other>(_ p: Parser<Other>) -> Self {
        then(p).map { result, _ in result }
    }
}

public enum Parsers {
    public static func string(_ string: String) -> Parser<Void> {
        return Parser {
            guard $0.hasPrefix(string) else { return nil }
            return ($0.dropFirst(string.count), ())
        }
    }

    public static func upTo(_ ch: Character) -> Parser<Substring> {
        return Parser {
            guard let index = $0.firstIndex(of: ch) else {
                return nil
            }
            return ($0[index...], $0[..<index])
        }
    }

    public static func upTo(_ pred: @escaping (Character) -> Bool) -> Parser<Substring> {
        return Parser {
            guard let index = $0.firstIndex(where: pred) else { return nil }
            return ($0[index...], $0[..<index])
        }
    }

    public static func sequence<O1, O2>(_ p1: Parser<O1>, _ p2: Parser<O2>) -> Parser<(O1, O2)> {
        return Parser {
            guard
                let (rest1, o1) = p1.parse($0),
                let (rest2, o2) = p2.parse(rest1)
            else {
                return nil
            }

            return (rest2, (o1, o2))
        }
    }

    public static func sequence<O1, O2, O3>(_ p1: Parser<O1>, _ p2: Parser<O2>, _ p3: Parser<O3>) -> Parser<(O1, O2, O3)> {
        return Parser {
            guard
                let (rest1, o1) = p1.parse($0),
                let (rest2, o2) = p2.parse(rest1),
                let (rest3, o3) = p3.parse(rest2)
            else {
                return nil
            }

            return (rest3, (o1, o2, o3))
        }
    }

    public  static func sequence<O1, O2, O3, O4>(_ p1: Parser<O1>, _ p2: Parser<O2>, _ p3: Parser<O3>, _ p4: Parser<O4>) -> Parser<(O1, O2, O3, O4)> {
        return Parser {
            guard
                let (rest1, o1) = p1.parse($0),
                let (rest2, o2) = p2.parse(rest1),
                let (rest3, o3) = p3.parse(rest2),
                let (rest4, o4) = p4.parse(rest3)
            else {
                return nil
            }

            return (rest4, (o1, o2, o3, o4))
        }
    }

    public static func oneOf<Output>(_ parsers: Parser<Output>...) -> Parser<Output> {
        return Parser {
            for p in parsers {
                if let result = p.parse($0) {
                    return result
                }
            }
            return nil
        }
    }

    public static let newLine = string("\n")

    public static func characters(isIncluded: @escaping (Character) -> Bool) -> Parser<Substring> {
        return Parser {
            let index = $0.firstIndex(where: { !isIncluded($0) }) ?? $0.endIndex
            return ($0[index...], $0[..<index])
        }
    }

    public static let empty = Parser { ($0, ()) }

    public static func fail<T>() -> Parser<T> {
        return Parser { _ in nil }
    }
}

public extension Parser where Output == Substring {
    var notEmpty: Self {
        return Parser {
            guard let (rest, result) = parse($0), !result.isEmpty else {
                return nil
            }

            return (rest, result)
        }
    }

    func toString() -> Parser<String> {
        map { String($0) }
    }
}
