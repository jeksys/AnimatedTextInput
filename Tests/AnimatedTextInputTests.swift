import KIF
import UIKit
import XCTest
import Nimble
import AnimatedTextInput
@testable import AnimatedTextInput_Example

class AnimatedTextInputTests: KIFTestCase {

    let inputAccessibilityLabel = "standard_text_input"

    override func afterEach() {
        super.afterEach()
        let viewController = UIApplication.shared.keyWindow?.rootViewController as! AnimatedTextInput_Example.ViewController
        viewController.textInputs.forEach{
            $0.text = nil
            $0.resignFirstResponder()
        }
    }

    func testStandardInputHasCorrectText() {
        // GIVEN
        let testText = "hello"
        let sut = tester().waitForView(withAccessibilityLabel: inputAccessibilityLabel) as! AnimatedTextInput

        // WHEN
        sut.becomeFirstResponder()
        tester().enterText(intoCurrentFirstResponder: testText)
        tester().wait(forTimeInterval: 0.5)

        // THEN
        expect(sut.text).to(equal(testText.capitalizedString))
    }

    func testInputIsActive() {
        // GIVEN
        let sut = tester().waitForView(withAccessibilityLabel: inputAccessibilityLabel) as! AnimatedTextInput

        // WHEN
        sut.becomeFirstResponder()

        // THEN
        expect(sut.isActive).to(beTrue())
    }

    func testInputIsInActive() {
        // GIVEN
        let sut = tester().waitForView(withAccessibilityLabel: inputAccessibilityLabel) as! AnimatedTextInput

        // WHEN
        sut.becomeFirstResponder()
        tester().waitForAnimationsToFinish()
        sut.resignFirstResponder()

        // THEN
        expect(sut.isActive).to(beFalse())
    }

    func testStandardInputSetText() {
        // GIVEN
        let initialText = "hello"
        let typedText = " world!"
        let sut = tester().waitForView(withAccessibilityLabel: inputAccessibilityLabel) as! AnimatedTextInput

        // WHEN
        sut.text = initialText
        sut.becomeFirstResponder()
        tester().enterText(intoCurrentFirstResponder: typedText)
        tester().wait(forTimeInterval: 0.5)

        // THEN
        expect(sut.text).to(equal(initialText + typedText))
    }

    func testTapInputToBecomeActive() {
        // GIVEN
        let sut = tester().waitForView(withAccessibilityLabel: inputAccessibilityLabel) as! AnimatedTextInput

        // WHEN
        tester().tapScreen(at: sut.center)

        // THEN
        expect(sut.isActive).to(beTrue())
    }

    func testPlaceholderActiveState() {
        // GIVEN
        let sut = tester().waitForView(withAccessibilityLabel: inputAccessibilityLabel) as! AnimatedTextInput
        let style = CustomTextInputStyle()
        sut.style = style
        let placeholder = textLayer(forTextInput: sut)

        // WHEN
        sut.becomeFirstResponder()
        tester().waitForAnimationsToFinish()

        // THEN
        expect(placeholder.fontSize).to(equal(style.placeholderMinFontSize))
    }

    func testPlaceholderInactiveStateWhenEmpty() {
        // GIVEN
        let sut = tester().waitForView(withAccessibilityLabel: inputAccessibilityLabel) as! AnimatedTextInput
        let style = CustomTextInputStyle()
        sut.style = style
        let placeholder = textLayer(forTextInput: sut)

        // WHEN
        sut.becomeFirstResponder()
        tester().waitForAnimationsToFinish()
        sut.resignFirstResponder()
        tester().waitForAnimationsToFinish()

        // THEN
        expect(placeholder.fontSize).to(equal(style.textInputFont.pointSize))
    }

    func testPlaceholderInactiveStateWhenFilled() {
        // GIVEN
        let sut = tester().waitForView(withAccessibilityLabel: inputAccessibilityLabel) as! AnimatedTextInput
        let style = CustomTextInputStyle()
        sut.style = style
        let placeholder = textLayer(forTextInput: sut)

        // WHEN
        sut.becomeFirstResponder()
        tester().enterText(intoCurrentFirstResponder: "hello")
        tester().waitForAnimationsToFinish()
        sut.resignFirstResponder()
        tester().waitForAnimationsToFinish()

        // THEN
        expect(placeholder.fontSize).to(equal(style.placeholderMinFontSize))
    }

    func testPlaceholderErrorState() {
        // GIVEN
        let sut = tester().waitForView(withAccessibilityLabel: inputAccessibilityLabel) as! AnimatedTextInput
        let style = CustomTextInputStyle()
        sut.style = style
        let placeholder = textLayer(forTextInput: sut)

        // WHEN
        let errorMessage = "Error"
        sut.show(error: errorMessage)
        tester().waitForAnimationsToFinish()

        // THEN
        expect(placeholder.string as? String).to(equal(errorMessage))
    }

    fileprivate func textLayer(forTextInput textInput: AnimatedTextInput) -> CATextLayer {
        var placeholder: CATextLayer?
        for layer in textInput.layer.sublayers! {
            if let textLayer = layer as? CATextLayer {
                placeholder = textLayer
            }
        }
        return placeholder!
    }
}

extension XCTestCase {

    func tester(_ file: String = #file, line: Int = #line) -> KIFUITestActor {
        return KIFUITestActor(inFile: file, atLine: line, delegate: self)
    }

    func system(_ file: String = #file, line: Int = #line) -> KIFSystemTestActor {
        return KIFSystemTestActor(inFile: file, atLine: line, delegate: self)
    }
}
