//
//  ViewController.swift
//  ChatPrototype
//
//  Created by Hussein Jaber on 26/9/19.
//  Copyright © 2019 Hussein Jaber. All rights reserved.
//

import UIKit

public struct Message {
    var text: String
    var isSender: Bool
    var dateString: String?
    
    public init(text: String, isSender: Bool) {
        self.text = text
        self.isSender = isSender
    }
}

/// Defines the style of the controllers UI elements
public struct ChatStyle {
    // TextView
    /// The font of the chat text view
    public var textViewFont: UIFont = .systemFont(ofSize: 17, weight: .bold)
    
    /// Tint color (mainly to specify the cursor color)
    public var textViewTintColor: UIColor = .red
    
    /// Placeholder text color
    public var placeholderTextColor: UIColor = .lightGray
    
    // TableView
    /// Content inset of chat table view
    public var tableContentInset: UIEdgeInsets = .init(top: 10, left: 0, bottom: 0, right: 0)
    /// Footer view of chat table view
    public var tableFooterView: UIView = .init()
    
    // Lower area
    /// Background color of the area holding a stackview (which holds a
    /// view and a send button)
    public var textAreaBackgroundColor: UIColor = .clear
    
    // StackView
    /// Spacing between elements inside stackview
    public var stackViewSpacing: CGFloat = 15
    
    // Send Button
    public var buttonImage: UIImage? = UIImage(named: "sendButton", in: Bundle(for: ChatViewController.self), compatibleWith: nil)
    
    /// The buttons title, in case a title is set, the image will disappear
    public var sendButtonTitle: String? = nil
    
    public var textFieldRoundedCornerRadius: CGFloat? = nil
    
    /// Background color of incoming message bubble
    public var incomingMessageColor: UIColor? = nil
    
    /// Background color of outgoing message bubble
    public var outgoingMessageColor: UIColor? = nil
    
    /// Incoming message text color
    public var incomingMessageTextColor: UIColor? = nil
    
    /// Outgoung message text color
    public var outgoingMessageTextColor: UIColor? = nil
    
    public var chatAreaTextColor: UIColor? = nil
    
    public init() {}
}

/// Defines some options of the controller
public struct ChatOptions {
    public var hideKeyboardOnScroll: Bool = true
    
    public var hideKeyboardOnTableTap: Bool = true
}

/// View controller with the following hierachy:
/// - view
///     - UITableView
///     - UIStackView (horizontal)
///         - UITextView
///         - UIButton
open class ChatViewController: UIViewController {
    
    /// Chat controller style
    open var style: ChatStyle = .init() {
        didSet {
            updateStyle()
        }
    }
    /// Chat controller options
    public var options: ChatOptions = .init()
    
    private var currentBundle: Bundle{
        return .init(for: Self.self)
    }
    
    // MARK: - Subviews
    
    /// Chat controller table view where the chat will be displayed
    private let tableView = UITableView(frame: .zero, style: .plain)
    
    /// The area below the table view
    private let textAreaBackground = UIView()
    
    /// Horizontal StackView
    /// - Note: Holds initially a textview (where message is typed) and a send button
    private lazy var stackView: UIStackView = {
        let sv = UIStackView(arrangedSubviews: [self.chatTextView, self.sendButton])
        sv.translatesAutoresizingMaskIntoConstraints = false
        sv.axis = .horizontal
        sv.distribution = .fill
        sv.spacing = self.style.stackViewSpacing
        return sv
    }()
    
    /// Text view where message is typed. Expandes with text height
    private lazy var chatTextView: UITextView = {
        let tf = UITextView()
        tf.textContainer.heightTracksTextView = true
        tf.tintColor = self.style.textViewTintColor
        tf.font = self.style.textViewFont
        tf.isScrollEnabled = false
        tf.delegate = self
        if let cornerRadius = self.style.textFieldRoundedCornerRadius {
            tf.layer.cornerRadius = cornerRadius
        }
        return tf
    }()
    
    /// Constraint between text area bottom and view bottom
    /// - NOTE: Initially is set to zero, changes when keyboard
    ///         appears/disappears
    private lazy var textAreaBottomConstraint: NSLayoutConstraint = {
        return self.textAreaBackground
            .bottomAnchor
            .constraint(equalTo: self.view.safeAreaLayoutGuide.bottomAnchor,
                        constant: 0)
    }()
    
    /// The button used to trigger the 'send message' action
    private lazy var sendButton: UIButton = {
        let button = UIButton()
        if let buttonTitle = style.sendButtonTitle {
            button.setTitle(buttonTitle, for: .normal)
        } else if let image = style.buttonImage {
            button.setImage(image, for: .normal)
        } else {
            button.setTitle("Send", for: .normal)
        }
        button.addTarget(self, action: #selector(didTapSend), for: .touchUpInside)
        button.setContentHuggingPriority(.defaultHigh, for: .horizontal)
        return button
    }()
    
    var messages: [Message] = []
    
    open var chatFieldPlaceholderText: String = "Type in your message"
        
    override open func viewDidLoad() {
        super.viewDidLoad()
        startObservingKeyboard()
        view.backgroundColor = .white
    }
    
    open override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        sendButton.widthAnchor.constraint(equalToConstant: sendButton.intrinsicContentSize.width).isActive = true
    }
    
    override public func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        defer {
            activateConstraints()
        }
        setupTableView()
        setupTextFieldArea()
        setupStackView()
        addPlaceHolderText()
    }
    
    /// Setup TableView and add it to view
    private func setupTableView() {
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.estimatedRowHeight = 180
        tableView.rowHeight = UITableView.automaticDimension
        tableView.delegate = self
        tableView.dataSource = self
        tableView.separatorStyle = .none
        tableView.contentInset = style.tableContentInset
        tableView.tableFooterView = style.tableFooterView
        tableView.allowsSelection = false
        registerCells()
        if options.hideKeyboardOnTableTap {
            tableView.addGestureRecognizer(
                UITapGestureRecognizer(target: self,
                                       action: #selector(hideKeyboard)))
        }
        view.addSubview(tableView)
    }
    
    /// Register cells to tableview
    open func registerCells() {
        tableView.register(IncomingCell.self,
                           forCellReuseIdentifier: IncomingCell.identifier)
        tableView.register(OutgoingCell.self,
                           forCellReuseIdentifier: OutgoingCell.identifier)
    }
    
    /// Setup the lower area of the view
    private func setupTextFieldArea() {
        textAreaBackground.translatesAutoresizingMaskIntoConstraints = false
        textAreaBackground.backgroundColor = style.textAreaBackgroundColor
        
        let lineView = UIView()
        lineView.translatesAutoresizingMaskIntoConstraints = false
        if #available(iOS 13.0, *) {
            lineView.backgroundColor = UIColor.systemGray4
        } else {
            lineView.backgroundColor = UIColor.darkGray
        }
        view.addSubview(textAreaBackground)
        textAreaBackground.addSubview(lineView)
        NSLayoutConstraint.activate([
            lineView.leadingAnchor.constraint(equalTo: textAreaBackground.leadingAnchor),
            lineView.topAnchor.constraint(equalTo: textAreaBackground.topAnchor),
            lineView.trailingAnchor.constraint(equalTo: textAreaBackground.trailingAnchor),
            lineView.heightAnchor.constraint(equalToConstant: 1)
        ])
    }
    
    private func setupStackView() {
        textAreaBackground.addSubview(stackView)
    }
    
    /// Activate constraints for all views
    private func activateConstraints() {
        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: textAreaBackground.topAnchor),
            
            textAreaBackground.leadingAnchor.constraint(equalTo: tableView.leadingAnchor),
            textAreaBackground.trailingAnchor.constraint(equalTo: tableView.trailingAnchor),
            self.textAreaBottomConstraint,
            textAreaBackground.heightAnchor.constraint(greaterThanOrEqualToConstant: 60),
            stackView.topAnchor.constraint(equalTo: textAreaBackground.topAnchor, constant: 10),
            stackView.bottomAnchor.constraint(equalTo: textAreaBackground.bottomAnchor, constant: -10),
            stackView.leadingAnchor.constraint(equalTo: textAreaBackground.leadingAnchor, constant: 10),
            stackView.trailingAnchor.constraint(equalTo: textAreaBackground.trailingAnchor, constant: -10)
        ])
    }
    
    
    /// Updates the new set options
    private func updateStyle() {
        chatTextView.font = style.textViewFont
        chatTextView.tintColor = style.textViewTintColor
        tableView.contentInset = self.style.tableContentInset
        tableView.tableFooterView = style.tableFooterView
        textAreaBackground.backgroundColor = style.textAreaBackgroundColor
        stackView.spacing = style.stackViewSpacing
        if let buttonTitle = style.sendButtonTitle {
            sendButton.setTitle(buttonTitle, for: .normal)
            sendButton.setImage(nil, for: .normal)
        } else if let buttonImage = style.buttonImage {
            sendButton.setImage(buttonImage, for: .normal)
            sendButton.setTitle(nil, for: .normal)
        } else {
            sendButton.setTitle("Send", for: .normal)
        }
        chatTextView.layer.cornerRadius = style.textFieldRoundedCornerRadius ?? 0.0
        view.backgroundColor = style.textAreaBackgroundColor
        if let textColor = style.chatAreaTextColor {
            chatTextView.textColor = textColor
        }
    }
    
    /// Hide keyboard
    @objc
    public func hideKeyboard() {
        self.view.endEditing(true)
    }
    
    /// Action triggered when 'Send' button gets tapped
    @objc
    public func didTapSend() {
        if chatTextView.containsAtLeastACharacter, let text = chatTextView.text, text != self.chatFieldPlaceholderText {
            addMessage(.init(text: chatTextView.text, isSender: true))
            chatTextView.text = ""
        }
    }
    
    public func addMessage(_ message: Message) {
        messages.append(message)
        tableView.insertRows(at: [.init(row: messages.count - 1, section: 0)], with: .automatic)
        scrollTableViewToLastRow()
    }
    
    /// Scrolls table view to last row according to items in messages array
    public func scrollTableViewToLastRow() {
        let lastRow = tableView.numberOfRows(inSection: 0) - 1
        guard lastRow > 0 else { return }
        let lastIndexPath = IndexPath(row: lastRow, section: 0)
        tableView.scrollToRow(at: lastIndexPath, at: .top, animated: true)
    }
    
    /// Remove observers to avoid memory leaks
    deinit {
        let notificationCenter = NotificationCenter.default
        notificationCenter.removeObserver(
            self,
            name: UIResponder.keyboardWillShowNotification,
            object: nil)
        notificationCenter.removeObserver(
            self,
            name: UIResponder.keyboardWillHideNotification,
            object: nil)
    }
    
    /// Adds observers to changes in keyboard show/hide flags
    private func startObservingKeyboard() {
        let notificationCenter = NotificationCenter.default
        notificationCenter.addObserver(forName: UIResponder.keyboardWillShowNotification,
                                       object: nil,
                                       queue: nil,
                                       using: keyboardWillAppear)
        
        notificationCenter.addObserver(forName: UIResponder.keyboardWillHideNotification,
                                       object: nil,
                                       queue: nil,
                                       using: keyboardWillDisappear)
    }
    
    /// Action done when keyboard will appear
    public func keyboardWillAppear(_ notification: Notification) {
        let key = UIResponder.keyboardFrameEndUserInfoKey
        guard let keyboardFrame = notification.userInfo?[key] as? CGRect else {
          return
        }
        
        let safeAreaBottom = view.safeAreaLayoutGuide.layoutFrame.maxY
        let viewHeight = view.bounds.height
        let safeAreaOffset = viewHeight - safeAreaBottom
        
        UIView.animate(
            withDuration: 0.3,
            delay: 0,
            options: [.curveEaseInOut],
            animations: {
                self.textAreaBottomConstraint.constant = -keyboardFrame.height + safeAreaOffset                
                self.view.layoutIfNeeded()
                self.tableView.scrollToRow(at: IndexPath(row: self.messages.count - 1, section: 0), at: .top, animated: true)
        })
    }
    
    
    public func keyboardWillDisappear(_ notification: Notification) {
        UIView.animate(
          withDuration: 0.3,
          delay: 0,
          options: [.curveEaseInOut],
          animations: {
            self.textAreaBottomConstraint.constant = 0
            self.view.layoutIfNeeded()
        })
    }


}

extension ChatViewController: UITableViewDelegate, UITableViewDataSource {
    
    public func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        messages.count
    }
    
    public func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let message = messages[indexPath.row]
        
        if message.isSender {
            let cell = tableView.dequeueReusableCell(withIdentifier: OutgoingCell.identifier, for: indexPath) as! OutgoingCell
            cell.setupWithMessage(message)
            if let outgoingColor = style.outgoingMessageColor {
                cell.bubbleBackgroundColor = outgoingColor
            }
            if let outgoingTextColor = style.outgoingMessageTextColor {
                cell.chatTextColor = outgoingTextColor
            }
            return cell
        } else {
            let cell = tableView.dequeueReusableCell(withIdentifier: IncomingCell.identifier, for: indexPath) as! IncomingCell
            cell.setupWithMessage(messages[indexPath.row])
            if let outgoingColor = style.incomingMessageColor {
                cell.bubbleBackgroundColor = outgoingColor
            }
            if let incomingTextColor = style.incomingMessageTextColor {
                cell.chatTextColor = incomingTextColor
            }
            return cell
        }
        
    }
    
    public func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
        if options.hideKeyboardOnScroll {
            self.view.endEditing(true)
        }
    }
    
}

extension ChatViewController: UITextViewDelegate {
    
    /// Changes color of textview text to appear like a placeholder.
    public func addPlaceHolderText() {
        chatTextView.text = self.chatFieldPlaceholderText
        chatTextView.textColor = style.placeholderTextColor
    }
    
    public func removePlaceholderText() {
        self.chatTextView.text = nil
        if let textColor = style.chatAreaTextColor {
            chatTextView.textColor = textColor
        } else {
            if #available(iOS 13.0, *) {
                self.chatTextView.textColor = .label
            } else {
                self.chatTextView.textColor = .black
            }
        }
        
    }
    
    public func textViewDidEndEditing(_ textView: UITextView) {
        if textView.text.isEmpty {
            addPlaceHolderText()
        }
    }
    
    public func textViewDidBeginEditing(_ textView: UITextView) {
        removePlaceholderText()
    }
}

extension UITextView {
    /// Ensures contains at least one character (not accounting
    /// spaces/new line breaks)
    var containsAtLeastACharacter: Bool {
        return !self.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}


