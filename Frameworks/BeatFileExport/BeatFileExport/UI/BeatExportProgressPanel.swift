//
//  BeatExportProgressPanel.swift
//  BeatFileExport
//
//  Created by Lauri-Matti Parppei on 14.11.2024.
//

@objc public protocol BeatProgressModalView {
    func updateProgress(_ progress:CGFloat, label:String?)
    func show(_ parent:Any?)
    func close()
}

#if os(macOS)
public class BeatExportProgressModal: NSWindowController, BeatProgressModalView {
    @IBOutlet weak var progressBar: NSProgressIndicator?
    @IBOutlet weak var progressLabel: NSTextField?
            
    override public var windowNibName: NSNib.Name? {
        return BeatExportProgressModal.windowNibName
    }
    class var windowNibName:NSNib.Name? {
        return NSNib.Name("BeatExportProgressModal")
    }

    /// Percentage is `0.0` to `1.0`
    public func updateProgress(_ progress: CGFloat, label:String? = nil) {
        let percentage = progress * 100
        let text = label ?? "\(percentage)%"
        
        progressBar?.doubleValue = percentage
        progressLabel?.stringValue = text
    }
        
    public func show(_ parent:Any?) {
        window?.makeKeyAndOrderFront(nil)
        window?.level = .floating
        progressBar?.minValue = 0
        progressBar?.maxValue = 100
        progressBar?.doubleValue = 0.0
    }
}
#endif

#if os(iOS)

public class BeatExportProgressModalManager:BeatProgressModalView {
    static let shared = BeatExportProgressModalManager()
    private var progressVC: BeatExportProgressViewController?
    
    public init() {}
    
    // Function to present the loading modal
    public func show(_ parent:Any?) {
        if let vc = parent as? UIViewController {
            showLoadingModal(on: vc)
        }
    }
    
    func showLoadingModal(on viewController: UIViewController) {
        guard progressVC == nil else { return } // Ensure it's not shown multiple times
        
        let vc = BeatExportProgressViewController()
        vc.modalPresentationStyle = .overFullScreen
        vc.modalTransitionStyle = .crossDissolve
        vc.updateProgress(1.0, label: "")
        
        viewController.present(vc, animated: true, completion: nil)
        self.progressVC = vc
    }
    
    public func updateProgress(_ progress: CGFloat, label: String?) {
        progressVC?.updateProgress(progress, label: label)
    }
        
    // Function to dismiss the loading modal
    func dismissLoadingModal() {
        progressVC?.dismiss(animated: true, completion: {
            self.progressVC = nil
        })
    }
    
    public func close() {
        self.dismissLoadingModal()
    }
}

class BeatExportProgressViewController: UIViewController {
    // Loading indicator and label to show progress or status text
    private let progressBar = UIActivityIndicatorView(style: .large)
    private let progressLabel = UILabel()

    override func viewDidLoad() {
        super.viewDidLoad()
        
        view.backgroundColor = UIColor(white: 0, alpha: 0.7)
        
        progressBar.translatesAutoresizingMaskIntoConstraints = false
        progressBar.startAnimating()
        view.addSubview(progressBar)
        
        // Configure progress label
        progressLabel.translatesAutoresizingMaskIntoConstraints = false
        progressLabel.textColor = .white
        progressLabel.textAlignment = .center
        progressLabel.font = UIFont.systemFont(ofSize: 16, weight: .medium)
        progressLabel.numberOfLines = 0
        view.addSubview(progressLabel)
        
        // Center both the label and the activity indicator
        NSLayoutConstraint.activate([
            progressBar.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            progressBar.centerYAnchor.constraint(equalTo: view.centerYAnchor, constant: -20),
            
            progressLabel.topAnchor.constraint(equalTo: progressBar.bottomAnchor, constant: 16),
            progressLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            progressLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20)
        ])
    }
    
    // Public method to update the label text
    func updateProgress(_ progress:CGFloat, label:String? = nil) {
        let percentage = progress * 100
        progressLabel.text = label ?? "\(percentage)%"
    }

}
#endif
