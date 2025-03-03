// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/

import Shared
import UIKit
import Common
import SiteImageView

struct ETPMenuUX {
    struct Fonts {
        static let websiteTitle: UIFont = .systemFont(ofSize: 17, weight: .semibold)
        static let viewTitleLabels: UIFont = .systemFont(ofSize: 17, weight: .regular)
        static let detailsLabel: UIFont = .systemFont(ofSize: 12, weight: .regular)
        static let minorInfoLabel: UIFont = .systemFont(ofSize: 15, weight: .regular)
    }

    struct UX {
        static let gutterDistance: CGFloat = 16
        static let viewCornerRadius: CGFloat = 8
        static let viewHeight: CGFloat = 44
        static let websiteLabelToHeroImageSpacing: CGFloat = 8
        static let faviconImageSize: CGFloat = 40
        static let closeButtonSize: CGFloat = 30
        static let faviconCornerRadius: CGFloat = 5

        struct Line {
            static let distanceFromFavicon: CGFloat = 17
            static let height: CGFloat = 1
        }
    }
}

class ETPSectionView: UIView {
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupView()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupView() {
        translatesAutoresizingMaskIntoConstraints = false
        layer.cornerRadius = ETPMenuUX.UX.viewCornerRadius
    }
}

protocol EnhancedTrackingProtectionMenuDelegate: AnyObject {
    func settingsOpenPage(settings: Route.SettingsSection)
    func didFinish()
}

class EnhancedTrackingProtectionMenuVC: UIViewController, Themeable {
    var themeManager: ThemeManager
    var themeObserver: NSObjectProtocol?
    var notificationCenter: NotificationProtocol
    weak var enhancedTrackingProtectionMenuDelegate: EnhancedTrackingProtectionMenuDelegate?
    // MARK: UI components

    // Header View
    private let headerContainer: UIView = .build { view in
        view.backgroundColor = .clear
    }

    private var favicon: FaviconImageView = .build { favicon in
        favicon.manuallySetImage(
            UIImage(named: StandardImageIdentifiers.Large.globe)?.withRenderingMode(.alwaysTemplate) ?? UIImage())
    }

    private let siteDomainLabel: UILabel = .build { label in
        label.font = ETPMenuUX.Fonts.websiteTitle
        label.numberOfLines = 0
    }

    private var closeButton: UIButton = .build { button in
        button.layer.cornerRadius = 0.5 * ETPMenuUX.UX.closeButtonSize
        button.clipsToBounds = true
        button.imageView?.contentMode = .scaleAspectFit
    }

    private let horizontalLine: UIView = .build { _ in }

    // Connection Info view
    private let connectionView = ETPSectionView(frame: .zero)

    private let connectionImage: UIImageView = .build { image in
        image.contentMode = .scaleAspectFit
        image.clipsToBounds = true
        image.layer.masksToBounds = true
        image.layer.cornerRadius = 5
    }

    private let connectionLabel: UILabel = .build { label in
        label.font = ETPMenuUX.Fonts.viewTitleLabels
        label.numberOfLines = 0
    }

    private let connectionDetailArrow: UIImageView = .build { image in
        image.image = UIImage(imageLiteralResourceName: StandardImageIdentifiers.Large.chevronLeft).withRenderingMode(.alwaysTemplate).imageFlippedForRightToLeftLayoutDirection()
        image.transform = CGAffineTransform(rotationAngle: .pi)
    }

    private let connectionButton: UIButton = .build { button in }

    // TrackingProtection toggle View
    private let toggleContainer: UIView = .build { view in
        view.backgroundColor = .clear
    }

    private let toggleView: UIView = ETPSectionView(frame: .zero)

    private let toggleLabel: UILabel = .build { label in
        label.font = ETPMenuUX.Fonts.viewTitleLabels
        label.numberOfLines = 0
    }

    private let toggleSwitch: UISwitch = .build { toggleSwitch in
        toggleSwitch.isEnabled = true
    }

    private let toggleStatusLabel: UILabel = .build { label in
        label.font = ETPMenuUX.Fonts.detailsLabel
        label.numberOfLines = 0
    }

    // Protection setting view
    private let protectionView: UIView = ETPSectionView(frame: .zero)

    private var protectionButton: UIButton = .build { button in
        button.setTitle(.TPProtectionSettings, for: .normal)
        button.titleLabel?.font = ETPMenuUX.Fonts.viewTitleLabels
        button.contentHorizontalAlignment = .left
    }

    private var constraints = [NSLayoutConstraint]()

    // MARK: - Variables

    private var viewModel: EnhancedTrackingProtectionMenuVM
    private var hasSetPointOrigin = false
    private var pointOrigin: CGPoint?
    var asPopover = false

    private var toggleContainerShouldBeHidden: Bool {
        return !viewModel.globalETPIsEnabled
    }

    private var protectionViewTopConstraint: NSLayoutConstraint?

    // MARK: - View lifecycle

    init(viewModel: EnhancedTrackingProtectionMenuVM,
         themeManager: ThemeManager = AppContainer.shared.resolve(),
         notificationCenter: NotificationProtocol = NotificationCenter.default) {
        self.viewModel = viewModel
        self.themeManager = themeManager
        self.notificationCenter = notificationCenter
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        if asPopover {
            var height: CGFloat = 385
            if toggleContainerShouldBeHidden {
                height = 285
            }
            self.preferredContentSize = CGSize(width: 400, height: height)
        } else {
            addGestureRecognizer()
        }
        setupView()
        listenForThemeChange(view)
    }

    override func viewDidLayoutSubviews() {
        if !hasSetPointOrigin {
            hasSetPointOrigin = true
            pointOrigin = self.view.frame.origin
        }
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        updateViewDetails()
        applyTheme()
    }

    private func setupView() {
        constraints.removeAll()

        setupHeaderView()
        setupConnectionStatusView()
        setupToggleView()
        setupProtectionSettingsView()
        setupViewActions()

        NSLayoutConstraint.activate(constraints)
    }

    private func setupHeaderView() {
        headerContainer.addSubviews(favicon, siteDomainLabel, closeButton, horizontalLine)
        view.addSubview(headerContainer)

        var headerConstraints = [
            headerContainer.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            headerContainer.trailingAnchor.constraint(equalTo: view.trailingAnchor),

            favicon.leadingAnchor.constraint(equalTo: headerContainer.leadingAnchor, constant: ETPMenuUX.UX.gutterDistance),
            favicon.topAnchor.constraint(equalTo: headerContainer.topAnchor, constant: ETPMenuUX.UX.gutterDistance),
            favicon.widthAnchor.constraint(equalToConstant: ETPMenuUX.UX.faviconImageSize),
            favicon.heightAnchor.constraint(equalToConstant: ETPMenuUX.UX.faviconImageSize),

            siteDomainLabel.centerYAnchor.constraint(equalTo: favicon.centerYAnchor),
            siteDomainLabel.leadingAnchor.constraint(equalTo: favicon.trailingAnchor, constant: 8),
            siteDomainLabel.trailingAnchor.constraint(equalTo: closeButton.leadingAnchor, constant: -15),

            closeButton.trailingAnchor.constraint(equalTo: headerContainer.trailingAnchor, constant: -ETPMenuUX.UX.gutterDistance),
            closeButton.topAnchor.constraint(equalTo: headerContainer.topAnchor, constant: ETPMenuUX.UX.gutterDistance),
            closeButton.heightAnchor.constraint(equalToConstant: ETPMenuUX.UX.closeButtonSize),
            closeButton.widthAnchor.constraint(equalToConstant: ETPMenuUX.UX.closeButtonSize),

            horizontalLine.leadingAnchor.constraint(equalTo: headerContainer.leadingAnchor),
            horizontalLine.trailingAnchor.constraint(equalTo: headerContainer.trailingAnchor),
            horizontalLine.topAnchor.constraint(equalTo: favicon.bottomAnchor, constant: ETPMenuUX.UX.Line.distanceFromFavicon),
            horizontalLine.heightAnchor.constraint(equalToConstant: ETPMenuUX.UX.Line.height),
            headerContainer.bottomAnchor.constraint(equalTo: horizontalLine.bottomAnchor)
        ]

        if asPopover {
            headerConstraints.append(headerContainer.topAnchor.constraint(equalTo: view.topAnchor, constant: 20))
        } else {
            headerConstraints.append(headerContainer.topAnchor.constraint(equalTo: view.topAnchor))
        }

        constraints.append(contentsOf: headerConstraints)
    }

    private func setupConnectionStatusView() {
        connectionView.addSubviews(connectionImage, connectionLabel, connectionDetailArrow, connectionButton)
        view.addSubview(connectionView)

        let connectionConstraints = [
            connectionView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: ETPMenuUX.UX.gutterDistance),
            connectionView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -ETPMenuUX.UX.gutterDistance),
            connectionView.topAnchor.constraint(equalTo: headerContainer.bottomAnchor, constant: 28),
            connectionView.heightAnchor.constraint(greaterThanOrEqualToConstant: ETPMenuUX.UX.viewHeight),

            connectionImage.leadingAnchor.constraint(equalTo: connectionView.leadingAnchor, constant: ETPMenuUX.UX.gutterDistance),
            connectionImage.centerYAnchor.constraint(equalTo: connectionView.centerYAnchor),
            connectionImage.heightAnchor.constraint(equalToConstant: 20),
            connectionImage.widthAnchor.constraint(equalToConstant: 20),

            connectionLabel.leadingAnchor.constraint(equalTo: connectionImage.trailingAnchor, constant: ETPMenuUX.UX.gutterDistance),
            connectionLabel.centerYAnchor.constraint(equalTo: connectionView.centerYAnchor),
            connectionLabel.topAnchor.constraint(equalTo: connectionView.topAnchor, constant: 11),
            connectionLabel.bottomAnchor.constraint(equalTo: connectionView.bottomAnchor, constant: -11),
            connectionLabel.trailingAnchor.constraint(equalTo: connectionDetailArrow.leadingAnchor, constant: ETPMenuUX.UX.gutterDistance),

            connectionDetailArrow.trailingAnchor.constraint(equalTo: connectionView.trailingAnchor, constant: -ETPMenuUX.UX.gutterDistance),
            connectionDetailArrow.centerYAnchor.constraint(equalTo: connectionView.centerYAnchor),
            connectionDetailArrow.heightAnchor.constraint(equalToConstant: 20),
            connectionDetailArrow.widthAnchor.constraint(equalToConstant: 20),

            connectionButton.leadingAnchor.constraint(equalTo: connectionView.leadingAnchor),
            connectionButton.topAnchor.constraint(equalTo: connectionView.topAnchor),
            connectionButton.trailingAnchor.constraint(equalTo: connectionView.trailingAnchor),
            connectionButton.bottomAnchor.constraint(equalTo: connectionView.bottomAnchor)
        ]

        constraints.append(contentsOf: connectionConstraints)
    }

    private func setupToggleView() {
        toggleView.addSubviews(toggleLabel, toggleSwitch)
        toggleContainer.addSubviews(toggleView, toggleStatusLabel)
        view.addSubview(toggleContainer)

        var toggleConstraints = [
            toggleContainer.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            toggleContainer.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            toggleContainer.topAnchor.constraint(equalTo: connectionView.bottomAnchor, constant: 32),
            toggleContainer.heightAnchor.constraint(greaterThanOrEqualToConstant: 92),
            toggleContainer.heightAnchor.constraint(lessThanOrEqualToConstant: 106),

            toggleView.leadingAnchor.constraint(equalTo: toggleContainer.leadingAnchor, constant: ETPMenuUX.UX.gutterDistance),
            toggleView.trailingAnchor.constraint(equalTo: toggleContainer.trailingAnchor, constant: -ETPMenuUX.UX.gutterDistance),
            toggleView.topAnchor.constraint(equalTo: toggleContainer.topAnchor),
            toggleView.heightAnchor.constraint(greaterThanOrEqualToConstant: ETPMenuUX.UX.viewHeight),

            toggleLabel.leadingAnchor.constraint(equalTo: toggleView.leadingAnchor, constant: ETPMenuUX.UX.gutterDistance),
            toggleLabel.trailingAnchor.constraint(equalTo: toggleSwitch.leadingAnchor, constant: -ETPMenuUX.UX.gutterDistance),
            toggleLabel.topAnchor.constraint(equalTo: toggleView.topAnchor, constant: 11),
            toggleLabel.bottomAnchor.constraint(equalTo: toggleView.bottomAnchor, constant: -11),

            toggleSwitch.centerYAnchor.constraint(equalTo: toggleView.centerYAnchor),
            toggleSwitch.widthAnchor.constraint(equalToConstant: 51),
            toggleSwitch.heightAnchor.constraint(equalToConstant: 31),
            toggleSwitch.trailingAnchor.constraint(equalTo: toggleView.trailingAnchor, constant: -ETPMenuUX.UX.gutterDistance),

            toggleStatusLabel.leadingAnchor.constraint(equalTo: toggleLabel.leadingAnchor),
            toggleStatusLabel.trailingAnchor.constraint(equalTo: toggleSwitch.trailingAnchor),
            toggleStatusLabel.topAnchor.constraint(equalTo: toggleView.bottomAnchor, constant: 6),
            toggleStatusLabel.bottomAnchor.constraint(lessThanOrEqualTo: toggleContainer.bottomAnchor, constant: -6)
        ]

        if toggleContainerShouldBeHidden {
            toggleConstraints.append(protectionView.topAnchor.constraint(equalTo: connectionView.bottomAnchor, constant: 32))
            toggleContainer.isHidden = true
        } else {
            toggleConstraints.append(protectionView.topAnchor.constraint(equalTo: toggleContainer.bottomAnchor))
            toggleContainer.isHidden = false
        }

        constraints.append(contentsOf: toggleConstraints)
    }

    private func setupProtectionSettingsView() {
        protectionView.addSubview(protectionButton)
        view.addSubview(protectionView)

        let protectionConstraints = [
            protectionView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: ETPMenuUX.UX.gutterDistance),
            protectionView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -ETPMenuUX.UX.gutterDistance),
            protectionView.heightAnchor.constraint(equalToConstant: ETPMenuUX.UX.viewHeight),
            protectionView.bottomAnchor.constraint(lessThanOrEqualTo: view.bottomAnchor, constant: 15),

            protectionButton.leadingAnchor.constraint(equalTo: protectionView.leadingAnchor, constant: ETPMenuUX.UX.gutterDistance),
            protectionButton.trailingAnchor.constraint(equalTo: protectionView.trailingAnchor, constant: -ETPMenuUX.UX.gutterDistance),
            protectionButton.topAnchor.constraint(equalTo: protectionView.topAnchor),
            protectionButton.bottomAnchor.constraint(equalTo: protectionView.bottomAnchor)
        ]

        constraints.append(contentsOf: protectionConstraints)
    }

    private func updateViewDetails() {
        favicon.setFavicon(FaviconImageViewModel(siteURLString: viewModel.url.absoluteString,
                                                 faviconCornerRadius: ETPMenuUX.UX.faviconCornerRadius))

        siteDomainLabel.text = viewModel.websiteTitle
        connectionLabel.text = viewModel.connectionStatusString
        toggleSwitch.isOn = viewModel.isSiteETPEnabled
        toggleLabel.text = .TrackingProtectionEnableTitle
        toggleStatusLabel.text = toggleSwitch.isOn ? .ETPOn : .ETPOff
    }

    private func setupViewActions() {
        closeButton.addTarget(self, action: #selector(closeButtonTapped), for: .touchUpInside)
        connectionButton.addTarget(self, action: #selector(connectionDetailsTapped), for: .touchUpInside)
        toggleSwitch.addTarget(self, action: #selector(trackingProtectionToggleTapped), for: .valueChanged)
        protectionButton.addTarget(self, action: #selector(protectionSettingsTapped), for: .touchUpInside)
    }

    // MARK: - Button actions

    @objc
    func closeButtonTapped() {
        if CoordinatorFlagManager.isEtpCoordinatorEnabled {
            enhancedTrackingProtectionMenuDelegate?.didFinish()
        } else {
            self.dismiss(animated: true, completion: nil)
        }
    }

    @objc
    func connectionDetailsTapped() {
        let detailsVC = EnhancedTrackingProtectionDetailsVC(with: viewModel.getDetailsViewModel())
        detailsVC.modalPresentationStyle = .pageSheet
        self.present(detailsVC, animated: true)
    }

    @objc
    func trackingProtectionToggleTapped() {
        // site is safelisted if site ETP is disabled
        viewModel.toggleSiteSafelistStatus()
        toggleStatusLabel.text = toggleSwitch.isOn ? .ETPOn : .ETPOff
    }

    @objc
    func protectionSettingsTapped() {
        if CoordinatorFlagManager.isEtpCoordinatorEnabled {
             enhancedTrackingProtectionMenuDelegate?.settingsOpenPage(settings: .contentBlocker)
         } else {
             self.dismiss(animated: true) {
                 self.viewModel.onOpenSettingsTapped?()
             }
         }
    }

    // MARK: - Gesture Recognizer

    private func addGestureRecognizer() {
        let panGesture = UIPanGestureRecognizer(target: self, action: #selector(panGestureRecognizerAction))
        view.addGestureRecognizer(panGesture)
    }

    @objc
    func panGestureRecognizerAction(sender: UIPanGestureRecognizer) {
        let translation = sender.translation(in: view)
        let originalYPosition = self.view.frame.origin.y
        let originalXPosition = self.view.frame.origin.x

        // Not allowing the user to drag the view upward
        guard translation.y >= 0 else { return }

        // Setting x based on window calculation because we don't want
        // users to move the frame side ways, only straight up or down
        view.frame.origin = CGPoint(x: originalXPosition,
                                    y: self.pointOrigin!.y + translation.y)

        if sender.state == .ended {
            let dragVelocity = sender.velocity(in: view)
            if dragVelocity.y >= 1300 {
                if CoordinatorFlagManager.isEtpCoordinatorEnabled {
                    enhancedTrackingProtectionMenuDelegate?.didFinish()
                } else {
                    self.dismiss(animated: true, completion: nil)
                }
            } else {
                // Set back to original position of the view controller
                UIView.animate(withDuration: 0.3) {
                    self.view.frame.origin = self.pointOrigin ?? CGPoint(x: originalXPosition, y: originalYPosition)
                }
            }
        }
    }
}

// MARK: - Themable
extension EnhancedTrackingProtectionMenuVC {
    func applyTheme() {
        let theme = themeManager.currentTheme
        overrideUserInterfaceStyle = theme.type.getInterfaceStyle()
        view.backgroundColor = theme.colors.layer1
        closeButton.backgroundColor = theme.colors.layer2
        let buttonImage = UIImage(named: StandardImageIdentifiers.Medium.cross)?
            .tinted(withColor: theme.colors.iconSecondary)
        closeButton.setImage(buttonImage, for: .normal)
        connectionView.backgroundColor = theme.colors.layer2
        connectionDetailArrow.tintColor = theme.colors.iconSecondary
        connectionImage.image = viewModel.getConnectionStatusImage(themeType: theme.type)
        headerContainer.tintColor = theme.colors.iconPrimary
        if viewModel.connectionSecure {
            connectionImage.tintColor = theme.colors.iconPrimary
        }
        toggleView.backgroundColor = theme.colors.layer2
        toggleSwitch.tintColor = theme.colors.actionPrimary
        toggleSwitch.onTintColor = theme.colors.actionPrimary
        toggleStatusLabel.textColor = theme.colors.textSecondary
        protectionView.backgroundColor = theme.colors.layer2
        protectionButton.setTitleColor(theme.colors.textAccent, for: .normal)
        horizontalLine.backgroundColor = theme.colors.borderPrimary
        setNeedsStatusBarAppearanceUpdate()
    }
}
