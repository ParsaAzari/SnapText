import Foundation

@main
struct BidiReconstructorTests {
    static func main() {
        print("========================================")
        print("Running BidiReconstructor Unit Tests")
        print("========================================")

        var allPassed = true

        // Synthetic Unit Tests for Fixtures F1 to F8
        let testCases: [(id: String, expected: String, overrideBase: BidiReconstructor.ScriptDirection?, words: [TSVWordBox])] = [
            (
                "F1",
                "نتیجه اجرای تستهای خودکار (T1 تا T7)",
                nil,
                [
                    TSVWordBox(text: "(", left: 60, top: 20, width: 10, height: 24, conf: 90.0),
                    TSVWordBox(text: "T7", left: 75, top: 20, width: 40, height: 24, conf: 95.0),
                    TSVWordBox(text: "تا", left: 140, top: 20, width: 30, height: 24, conf: 90.0),
                    TSVWordBox(text: "T1", left: 180, top: 20, width: 40, height: 24, conf: 95.0),
                    TSVWordBox(text: ")", left: 230, top: 20, width: 10, height: 24, conf: 90.0),
                    TSVWordBox(text: "خودکار", left: 280, top: 20, width: 80, height: 24, conf: 90.0),
                    TSVWordBox(text: "تستهای", left: 410, top: 20, width: 80, height: 24, conf: 90.0),
                    TSVWordBox(text: "اجرای", left: 550, top: 20, width: 70, height: 24, conf: 90.0),
                    TSVWordBox(text: "نتیجه", left: 670, top: 20, width: 70, height: 24, conf: 90.0)
                ]
            ),
            (
                "F2",
                "(Build Output) نتیجه ساخت",
                nil,
                [
                    TSVWordBox(text: "(Build", left: 40, top: 20, width: 80, height: 24, conf: 95.0),
                    TSVWordBox(text: "Output)", left: 140, top: 20, width: 90, height: 24, conf: 95.0),
                    TSVWordBox(text: "ساخت", left: 260, top: 20, width: 60, height: 24, conf: 90.0),
                    TSVWordBox(text: "نتیجه", left: 340, top: 20, width: 70, height: 24, conf: 90.0)
                ]
            ),
            (
                "F3",
                "برای استفاده از Google Chrome نسخه 120 را نصب کنید",
                nil,
                [
                    TSVWordBox(text: "کنید", left: 50, top: 20, width: 60, height: 24, conf: 90.0),
                    TSVWordBox(text: "نصب", left: 130, top: 20, width: 60, height: 24, conf: 90.0),
                    TSVWordBox(text: "را", left: 220, top: 20, width: 30, height: 24, conf: 90.0),
                    TSVWordBox(text: "120", left: 260, top: 20, width: 50, height: 24, conf: 95.0),
                    TSVWordBox(text: "نسخه", left: 330, top: 20, width: 60, height: 24, conf: 90.0),
                    TSVWordBox(text: "Google", left: 420, top: 20, width: 80, height: 24, conf: 95.0),
                    TSVWordBox(text: "Chrome", left: 540, top: 20, width: 90, height: 24, conf: 95.0),
                    TSVWordBox(text: "از", left: 680, top: 20, width: 30, height: 24, conf: 90.0),
                    TSVWordBox(text: "استفاده", left: 730, top: 20, width: 80, height: 24, conf: 90.0),
                    TSVWordBox(text: "برای", left: 850, top: 20, width: 60, height: 24, conf: 90.0)
                ]
            ),
            (
                "F4",
                "Apple در سال ۲۰۲۴ مدل iPhone 16 را معرفی کرد.",
                nil,
                [
                    TSVWordBox(text: "کرد.", left: 60, top: 20, width: 50, height: 24, conf: 90.0),
                    TSVWordBox(text: "معرفی", left: 120, top: 20, width: 60, height: 24, conf: 90.0),
                    TSVWordBox(text: "را", left: 200, top: 20, width: 30, height: 24, conf: 90.0),
                    TSVWordBox(text: "iPhone", left: 250, top: 20, width: 70, height: 24, conf: 95.0),
                    TSVWordBox(text: "16", left: 340, top: 20, width: 40, height: 24, conf: 95.0),
                    TSVWordBox(text: "مدل", left: 400, top: 20, width: 50, height: 24, conf: 90.0),
                    TSVWordBox(text: "۲۰۲۴", left: 460, top: 20, width: 60, height: 24, conf: 90.0),
                    TSVWordBox(text: "سال", left: 540, top: 20, width: 50, height: 24, conf: 90.0),
                    TSVWordBox(text: "در", left: 610, top: 20, width: 30, height: 24, conf: 90.0),
                    TSVWordBox(text: "Apple", left: 660, top: 20, width: 70, height: 24, conf: 95.0)
                ]
            ),
            (
                "F5",
                "قیمت: 25 USD (حدود ۲٬۵۰۰٬۰۰۰ تومان)",
                nil,
                [
                    TSVWordBox(text: "(", left: 40, top: 20, width: 10, height: 24, conf: 90.0),
                    TSVWordBox(text: "تومان", left: 60, top: 20, width: 60, height: 24, conf: 90.0),
                    TSVWordBox(text: "۲٬۵۰۰٬۰۰۰", left: 140, top: 20, width: 90, height: 24, conf: 90.0),
                    TSVWordBox(text: "حدود", left: 250, top: 20, width: 60, height: 24, conf: 90.0),
                    TSVWordBox(text: ")", left: 320, top: 20, width: 10, height: 24, conf: 90.0),
                    TSVWordBox(text: "25", left: 350, top: 20, width: 40, height: 24, conf: 95.0),
                    TSVWordBox(text: "USD", left: 400, top: 20, width: 50, height: 24, conf: 95.0),
                    TSVWordBox(text: "قیمت:", left: 470, top: 20, width: 60, height: 24, conf: 90.0)
                ]
            ),
            (
                "F6",
                "Press ⌘E برای گرفتن عکس",
                .L, // English base direction case
                [
                    TSVWordBox(text: "Press", left: 40, top: 20, width: 70, height: 24, conf: 95.0),
                    TSVWordBox(text: "⌘E", left: 130, top: 20, width: 40, height: 24, conf: 95.0),
                    TSVWordBox(text: "عکس", left: 200, top: 20, width: 60, height: 24, conf: 90.0),
                    TSVWordBox(text: "گرفتن", left: 270, top: 20, width: 60, height: 24, conf: 90.0),
                    TSVWordBox(text: "برای", left: 350, top: 20, width: 50, height: 24, conf: 90.0)
                ]
            ),
            (
                "F7",
                "فایل report_final.pdf را به ali@example.com بفرستید.",
                nil,
                [
                    TSVWordBox(text: "بفرستید.", left: 60, top: 20, width: 90, height: 24, conf: 90.0),
                    TSVWordBox(text: "ali@example.com", left: 170, top: 20, width: 160, height: 24, conf: 95.0),
                    TSVWordBox(text: "به", left: 350, top: 20, width: 30, height: 24, conf: 90.0),
                    TSVWordBox(text: "را", left: 400, top: 20, width: 30, height: 24, conf: 90.0),
                    TSVWordBox(text: "report_final.pdf", left: 450, top: 20, width: 170, height: 24, conf: 95.0),
                    TSVWordBox(text: "فایل", left: 650, top: 20, width: 50, height: 24, conf: 90.0)
                ]
            ),
            (
                "F8",
                "هیچ موتور OCR ای در دنیا (حتی ABBYY یا Google) روی ورودی دلخواه ۱۰۰٪ درست نیست؛",
                nil,
                [
                    TSVWordBox(text: "نیست؛", left: 40, top: 20, width: 60, height: 24, conf: 90.0),
                    TSVWordBox(text: "درست", left: 120, top: 20, width: 60, height: 24, conf: 90.0),
                    TSVWordBox(text: "۱۰۰٪", left: 200, top: 20, width: 50, height: 24, conf: 90.0),
                    TSVWordBox(text: "دلخواه", left: 270, top: 20, width: 60, height: 24, conf: 90.0),
                    TSVWordBox(text: "ورودی", left: 360, top: 20, width: 60, height: 24, conf: 90.0),
                    TSVWordBox(text: "روی", left: 450, top: 20, width: 40, height: 24, conf: 90.0),
                    TSVWordBox(text: "(", left: 510, top: 20, width: 10, height: 24, conf: 90.0),
                    TSVWordBox(text: "Google", left: 530, top: 20, width: 70, height: 24, conf: 95.0),
                    TSVWordBox(text: "یا", left: 620, top: 20, width: 25, height: 24, conf: 90.0),
                    TSVWordBox(text: "ABBYY", left: 660, top: 20, width: 80, height: 24, conf: 95.0),
                    TSVWordBox(text: "حتی", left: 760, top: 20, width: 50, height: 24, conf: 90.0),
                    TSVWordBox(text: ")", left: 830, top: 20, width: 10, height: 24, conf: 90.0),
                    TSVWordBox(text: "دنیا", left: 870, top: 20, width: 50, height: 24, conf: 90.0),
                    TSVWordBox(text: "در", left: 940, top: 20, width: 30, height: 24, conf: 90.0),
                    TSVWordBox(text: "ای", left: 990, top: 20, width: 30, height: 24, conf: 90.0),
                    TSVWordBox(text: "OCR", left: 1030, top: 20, width: 60, height: 24, conf: 95.0),
                    TSVWordBox(text: "موتور", left: 1120, top: 20, width: 60, height: 24, conf: 90.0),
                    TSVWordBox(text: "هیچ", left: 1220, top: 20, width: 50, height: 24, conf: 90.0)
                ]
            )
        ]

        for tc in testCases {
            let actual = BidiReconstructor.reconstruct(words: tc.words, overrideBaseDirection: tc.overrideBase)
            let passed = (actual == tc.expected)
            if passed {
                print("[\(tc.id)] PASSED")
            } else {
                allPassed = false
                print("[\(tc.id)] FAILED!")
                print("  Expected: '\(tc.expected)'")
                print("  Actual:   '\(actual)'")
            }
        }

        print("========================================")
        if allPassed {
            print("ALL BIDI RECONSTRUCTOR SYNTHETIC TESTS PASSED SUCCESSFULLY!")
            exit(0)
        } else {
            print("SOME TESTS FAILED!")
            exit(1)
        }
    }
}
