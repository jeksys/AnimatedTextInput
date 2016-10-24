import UIKit

@objc public protocol AnimatedTextInputDelegate: class {

    @objc optional func animatedTextInputDidBeginEditing(_ animatedTextInput: AnimatedTextInput)
    @objc optional func animatedTextInputDidEndEditing(_ animatedTextInput: AnimatedTextInput)
    @objc optional func animatedTextInputDidChange(_ animatedTextInput: AnimatedTextInput)
    @objc optional func animatedTextInput(_ animatedTextInput: AnimatedTextInput, shouldChangeCharactersInRange range: NSRange, replacementString string: String) -> Bool
    @objc optional func animatedTextInputShouldBeginEditing(_ animatedTextInput: AnimatedTextInput) -> Bool
    @objc optional func animatedTextInputShouldEndEditing(_ animatedTextInput: AnimatedTextInput) -> Bool
    @objc optional func animatedTextInputShouldReturn(_ animatedTextInput: AnimatedTextInput) -> Bool
}

open class AnimatedTextInput: UIControl {

    public typealias AnimatedTextInputType = AnimatedTextInputFieldConfigurator.AnimatedTextInputType

    open var tapAction: ((Void) -> Void)?
    open  weak var delegate: AnimatedTextInputDelegate?
    open fileprivate(set) var isActive = false

    open var type: AnimatedTextInputType = .standard {
        didSet {
            configureType()
        }
    }

    open var placeHolderText = "Test" {
        didSet {
            placeholderLayer.string = placeHolderText
        }
    }

    open var style: AnimatedTextInputStyle = AnimatedTextInputStyleBlue() {
        didSet {
            configureStyle()
        }
    }

    open var text: String? {
        get {
            return textInput.currentText
        }
        set {
            if !textInput.view.isFirstResponder {
                (newValue != nil) ? configurePlaceholderAsInactiveHint() : configurePlaceholderAsDefault()
            }
            textInput.currentText = newValue
        }
    }

    fileprivate let lineView = AnimatedLine()
    fileprivate let placeholderLayer = CATextLayer()
    fileprivate let counterLabel = UILabel()
    fileprivate let lineWidth: CGFloat = 1
    fileprivate let counterLabelRightMargin: CGFloat = 15
    fileprivate let counterLabelTopMargin: CGFloat = 5

    fileprivate var isResigningResponder = false
    fileprivate var isPlaceholderAsHint = false
    fileprivate var hasCounterLabel = false
    fileprivate var textInput: TextInput!
    fileprivate var placeholderErrorText: String?
    fileprivate var lineToBottomConstraint: NSLayoutConstraint!

    fileprivate var placeholderPosition: CGPoint {
        let hintPosition = CGPoint(x: style.leftMargin, y: style.yHintPositionOffset)
        let defaultPosition = CGPoint(x: style.leftMargin, y: style.topMargin + style.yPlaceholderPositionOffset)
        return isPlaceholderAsHint ? hintPosition : defaultPosition
    }

    override init(frame: CGRect) {
        super.init(frame: frame)

        setupCommonElements()
    }

    required public init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)

        setupCommonElements()
    }

    override open var intrinsicContentSize : CGSize {
        let normalHeight = textInput.view.intrinsicContentSize.height
        return CGSize(width: UIViewNoIntrinsicMetric, height: normalHeight + style.topMargin + style.bottomMargin)
    }

    open override func updateConstraints() {
        addLineViewConstraints()
        addTextInputConstraints()
        super.updateConstraints()
    }

    open override func layoutSubviews() {
        super.layoutSubviews()
        layoutPlaceholderLayer()
    }

    fileprivate func layoutPlaceholderLayer() {
        // Some letters like 'g' or 'á' were not rendered properly, the frame need to be about 20% higher than the font size
        let frameHeightCorrectionFactor: CGFloat = 1.2
        placeholderLayer.frame = CGRect(origin: placeholderPosition, size: CGSize(width: bounds.width, height: style.textInputFont.pointSize * frameHeightCorrectionFactor))
    }

    // mark: Configuration

    fileprivate func addLineViewConstraints() {
        pinLeading(toLeadingOf: lineView, constant: style.leftMargin)
        pinTrailing(toTrailingOf: lineView, constant: style.rightMargin)
        lineView.setHeight(to: lineWidth / UIScreen.main.scale)
        let constant = hasCounterLabel ? -counterLabel.intrinsicContentSize.height - counterLabelTopMargin : 0
        pinBottom(toBottomOf: lineView, constant: constant)
    }

    fileprivate func addTextInputConstraints() {
        pinLeading(toLeadingOf: textInput.view, constant: style.leftMargin)
        pinTrailing(toTrailingOf: textInput.view, constant: style.rightMargin)
        pinTop(toTopOf: textInput.view, constant: style.topMargin)
        textInput.view.pinBottom(toTopOf: lineView, constant: style.bottomMargin)
    }

    fileprivate func setupCommonElements() {
        addLine()
        addPlaceHolder()
        addTapGestureRecognizer()
        addTextInput()
    }

    fileprivate func addLine() {
        lineView.defaultColor = style.lineInactiveColor
        lineView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(lineView)
    }

    fileprivate func addPlaceHolder() {
        placeholderLayer.masksToBounds = false
        placeholderLayer.string = placeHolderText
        placeholderLayer.foregroundColor = style.inactiveColor.cgColor
        placeholderLayer.fontSize = style.textInputFont.pointSize
        placeholderLayer.font = style.textInputFont
        placeholderLayer.contentsScale = UIScreen.main.scale
        placeholderLayer.backgroundColor = UIColor.clear.cgColor
        layoutPlaceholderLayer()
        layer.addSublayer(placeholderLayer)
    }

    fileprivate func addTapGestureRecognizer() {
        let tap = UITapGestureRecognizer(target: self, action: #selector(viewWasTapped(_:)))
        addGestureRecognizer(tap)
    }

    fileprivate func addTextInput() {
        textInput = AnimatedTextInputFieldConfigurator.configure(with: type)
        textInput.textInputDelegate = self
        textInput.view.tintColor = style.activeColor
        textInput.textColor = style.textInputFontColor
        textInput.font = style.textInputFont
        textInput.view.translatesAutoresizingMaskIntoConstraints = false
        addSubview(textInput.view)
        invalidateIntrinsicContentSize()
    }

    fileprivate func updateCounter() {
        guard let counterText = counterLabel.text else { return }
        let components = counterText.components(separatedBy: "/")
        let characters = (text != nil) ? text!.characters.count : 0
        counterLabel.text = "\(characters)/\(components[1])"
    }

    //mark: States and animations

    fileprivate func configurePlaceholderAsActiveHint() {
        isPlaceholderAsHint = true
        configurePlaceholderWith(fontSize: style.placeholderMinFontSize,
                                 foregroundColor: style.activeColor.cgColor,
                                 text: placeHolderText)
        lineView.fillLine(with: style.activeColor)
    }

    fileprivate func configurePlaceholderAsInactiveHint() {
        isPlaceholderAsHint = true
        configurePlaceholderWith(fontSize: style.placeholderMinFontSize,
                                 foregroundColor: style.inactiveColor.cgColor,
                                 text: placeHolderText)
        lineView.animateToInitialState()
    }

    fileprivate func configurePlaceholderAsDefault() {
        isPlaceholderAsHint = false
        configurePlaceholderWith(fontSize: style.textInputFont.pointSize,
                                 foregroundColor: style.inactiveColor.cgColor,
                                 text: placeHolderText)
        lineView.animateToInitialState()
    }

    fileprivate func configurePlaceholderAsErrorHint() {
        isPlaceholderAsHint = true
        configurePlaceholderWith(fontSize: style.placeholderMinFontSize,
                                 foregroundColor: style.errorColor.cgColor,
                                 text: placeholderErrorText)
        lineView.fillLine(with: style.errorColor)
    }

    fileprivate func configurePlaceholderWith(fontSize: CGFloat, foregroundColor: CGColor, text: String?) {
        placeholderLayer.fontSize = fontSize
        placeholderLayer.foregroundColor = foregroundColor
        placeholderLayer.string = text
        placeholderLayer.frame = CGRect(origin: placeholderPosition, size: placeholderLayer.frame.size)
    }

    fileprivate func animatePlaceholder(to applyConfiguration: (Void) -> Void) {
        let duration = 0.2
        let function = CAMediaTimingFunction(controlPoints: 0.3, 0.0, 0.5, 0.95)
        transactionAnimation(with: duration, timingFuncion: function, animations: applyConfiguration)
    }

    //MARK: Behaviours

    @objc fileprivate func viewWasTapped(_ sender: UIGestureRecognizer) {
        if let tapAction = tapAction {
            tapAction()
        } else {
            becomeFirstResponder()
        }
    }

    fileprivate func styleDidChange() {
        lineView.defaultColor = style.lineInactiveColor
        placeholderLayer.foregroundColor = style.inactiveColor.cgColor
        let fontSize = style.textInputFont.pointSize
        placeholderLayer.fontSize = fontSize
        placeholderLayer.font = style.textInputFont
        layoutPlaceholderLayer()
        textInput.view.tintColor = style.activeColor
        textInput.textColor = style.textInputFontColor
        textInput.font = style.textInputFont
        invalidateIntrinsicContentSize()
        layoutIfNeeded()
    }

    override open func becomeFirstResponder() -> Bool {
        isActive = true
        textInput.view.becomeFirstResponder()
        counterLabel.textColor = style.activeColor
        placeholderErrorText = nil
        animatePlaceholder(to: configurePlaceholderAsActiveHint)
        return true
    }

    override open func resignFirstResponder() -> Bool {
        guard !isResigningResponder else { return true }
        isActive = false
        isResigningResponder = true
        textInput.view.resignFirstResponder()
        isResigningResponder = false
        counterLabel.textColor = style.inactiveColor

        if let textInputError = textInput as? TextInputError {
            textInputError.removeErrorHintMessage()
        }

        // If the placeholder is showing an error we want to keep this state. Otherwise revert to inactive state.
        if placeholderErrorText == nil {
            animateToInactiveState()
        }
        return true
    }

    fileprivate func animateToInactiveState() {
        guard let text = textInput.currentText, !text.isEmpty else {
            animatePlaceholder(to: configurePlaceholderAsDefault)
            return
        }
        animatePlaceholder(to: configurePlaceholderAsInactiveHint)
    }

    override open var canResignFirstResponder : Bool {
        return textInput.view.canResignFirstResponder
    }

    override open var canBecomeFirstResponder : Bool {
        guard !isResigningResponder else { return false }
        return textInput.view.canBecomeFirstResponder
    }

    open func show(error errorMessage: String, placeholderText: String? = nil) {
        placeholderErrorText = errorMessage
        if let textInput = textInput as? TextInputError {
            textInput.configureErrorState(with: placeholderText)
        }
        animatePlaceholder(to: configurePlaceholderAsErrorHint)
    }

    open func clearError() {
        placeholderErrorText = nil
        if let textInputError = textInput as? TextInputError {
            textInputError.removeErrorHintMessage()
        }
        if isActive {
            animatePlaceholder(to: configurePlaceholderAsActiveHint)
        } else {
            animateToInactiveState()
        }
    }

    fileprivate func configureType() {
        textInput.view.removeFromSuperview()
        addTextInput()
    }

    fileprivate func configureStyle() {
        styleDidChange()
        if isActive {
            configurePlaceholderAsActiveHint()
        } else {
            isPlaceholderAsHint ? configurePlaceholderAsInactiveHint() : configurePlaceholderAsDefault()
        }
    }

    open func showCharacterCounterLabel(with maximum: Int) {
        let characters = (text != nil) ? text!.characters.count : 0
        counterLabel.text = "\(characters)/\(maximum)"
        counterLabel.textColor = isActive ? style.activeColor : style.inactiveColor
        counterLabel.font = style.counterLabelFont
        counterLabel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(counterLabel)
        addCharacterCounterConstraints()
        invalidateIntrinsicContentSize()
    }

    fileprivate func addCharacterCounterConstraints() {
        lineView.pinBottom(toTopOf: counterLabel, constant: counterLabelTopMargin)
        pinTrailing(toTrailingOf: counterLabel, constant: counterLabelRightMargin)
    }

    open func removeCharacterCounterLabel() {
        counterLabel.removeConstraints(counterLabel.constraints)
        counterLabel.removeFromSuperview()
        lineToBottomConstraint.constant = 0
        invalidateIntrinsicContentSize()
    }
}

extension AnimatedTextInput: TextInputDelegate {

    public func textInputDidBeginEditing(_ textInput: TextInput) {
        becomeFirstResponder()
        delegate?.animatedTextInputDidBeginEditing?(self)
    }

    public func textInputDidEndEditing(_ textInput: TextInput) {
        resignFirstResponder()
        delegate?.animatedTextInputDidEndEditing?(self)
    }

    public func textInputDidChange(_ textInput: TextInput) {
        updateCounter()
        delegate?.animatedTextInputDidChange?(self)
    }

    public func textInput(_ textInput: TextInput, shouldChangeCharactersInRange range: NSRange, replacementString string: String) -> Bool {
        return delegate?.animatedTextInput?(self, shouldChangeCharactersInRange: range, replacementString: string) ?? true
    }

    public func textInputShouldBeginEditing(_ textInput: TextInput) -> Bool {
        return delegate?.animatedTextInputShouldBeginEditing?(self) ?? true
    }

    public func textInputShouldEndEditing(_ textInput: TextInput) -> Bool {
        return delegate?.animatedTextInputShouldEndEditing?(self) ?? true
    }

    public func textInputShouldReturn(_ textInput: TextInput) -> Bool {
        return delegate?.animatedTextInputShouldReturn?(self) ?? true
    }
}

public protocol TextInput {
    var view: UIView { get }
    var currentText: String? { get set }
    var font: UIFont? { get set }
    var textColor: UIColor? { get set }
    weak var textInputDelegate: TextInputDelegate? { get set }
}

public protocol TextInputDelegate: class {
    func textInputDidBeginEditing(_ textInput: TextInput)
    func textInputDidEndEditing(_ textInput: TextInput)
    func textInputDidChange(_ textInput: TextInput)
    func textInput(_ textInput: TextInput, shouldChangeCharactersInRange range: NSRange, replacementString string: String) -> Bool
    func textInputShouldBeginEditing(_ textInput: TextInput) -> Bool
    func textInputShouldEndEditing(_ textInput: TextInput) -> Bool
    func textInputShouldReturn(_ textInput: TextInput) -> Bool
}

public protocol TextInputError {
    func configureErrorState(with message: String?)
    func removeErrorHintMessage()
}
