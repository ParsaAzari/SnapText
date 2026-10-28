import Foundation

@main
struct PersianNormalizerTests {
    static func main() {
        let goldenTests: [(id: String, input: String)] = [
            ("T1", "هیچ موتور OCR ای در دنیا (حتی ABBYY یا Google) روی ورودی دلخواه ۱۰۰٪ درست نیست؛"),
            ("T2", "می‌خواهم کتاب‌ها را بخوانم"),
            ("T3", "مسئله رئیس جزء مؤسسه"),
            ("T4", "قیمت ۱۲۳ تومان (متن) 3.2.1 user@example.com"),
            ("T5", "سلام! حالت چطوره؟")
        ]

        var allPassed = true

        print("========================================")
        print("Running PersianNormalizer Acceptance Tests")
        print("========================================")

        for (id, input) in goldenTests {
            let output = PersianNormalizer.processTesseractPersianOutput(input)
            if output == input {
                print("[\(id)] PASSED")
            } else {
                allPassed = false
                print("[\(id)] FAILED!")
                print("  Expected: \(input)")
                print("  Actual:   \(output)")
                print("  Diff utf8: Expected=\(Array(input.utf8)) vs Actual=\(Array(output.utf8))")
            }
        }

        // T6: Idempotence check f(f(x)) == f(x)
        print("\n--- T6: Idempotence check f(f(x)) == f(x) ---")
        var t6Passed = true
        for (id, input) in goldenTests {
            let f1 = PersianNormalizer.processTesseractPersianOutput(input)
            let f2 = PersianNormalizer.processTesseractPersianOutput(f1)
            if f1 == f2 {
                print("[T6-\(id)] PASSED (f(f(x)) == f(x))")
            } else {
                t6Passed = false
                allPassed = false
                print("[T6-\(id)] FAILED!")
                print("  f(x):    \(f1)")
                print("  f(f(x)): \(f2)")
            }
        }

        // Latin token preservation: ASCII digits/letters inside Latin tokens are never converted to Persian digits
        print("\n--- Latin Token Digit & Letter Preservation ---")
        let latinTokens = ["T1", "T7", "120", "iPhone 16", "25 USD", "ali@example.com"]
        for tok in latinTokens {
            let norm = PersianNormalizer.normalizePersian(tok)
            if norm == tok {
                print("[LATIN-\(tok)] PASSED: untouched")
            } else {
                allPassed = false
                print("[LATIN-\(tok)] FAILED: expected '\(tok)', got '\(norm)'")
            }
        }

        print("========================================")
        if allPassed && t6Passed {
            print("ALL ACCEPTANCE & LATIN TOKEN TESTS PASSED SUCCESSFULLY!")
            exit(0)
        } else {
            print("TESTS FAILED!")
            exit(1)
        }
    }
}
