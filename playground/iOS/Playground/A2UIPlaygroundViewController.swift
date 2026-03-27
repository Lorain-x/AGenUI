//
//  A2UIPlaygroundViewController.swift
//  GenerativeUIClientSDK
//
//  Created by AGenUI on 2026/2/27.
//

import UIKit
import AGenUI

class A2UIPlaygroundViewController: UIViewController, SurfaceManagerListener {
    
    // MARK: - Properties
    
    /// Surface Manager instance
    private let surfaceManager = SurfaceManager()
    
    /// Scroll view
    private let scrollView = UIScrollView()
    private let surfaceId: String? = nil

    /// Store current JSON data
    private var currentComponentsJSON: String?
    private var currentDataModelJSON: String?
    
    /// Store previous surfaceId for deletion
    private var previousSurfaceId: String?
    
    /// Edit button reference
    private var editBarButtonItem: UIBarButtonItem!
    

    // MARK: - Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        setupUI()
        setupNavigationBar()

        // Register as Surface lifecycle listener
        surfaceManager.addListener(self)
    }
    
    private func setupUI() {
        view.backgroundColor = .systemBackground
        
        // Add ScrollView
        view.addSubview(scrollView)
        scrollView.backgroundColor = .systemGray6
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        
        // ScrollView constraints - fixed to view's four edges
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }
    
    private func setupNavigationBar() {
        // Set title
        title = "A2UI Playground"
        
        // Create left menu button
        let menuButton = UIBarButtonItem(
            image: UIImage(systemName: "line.3.horizontal"),
            style: .plain,
            target: self,
            action: #selector(menuButtonTapped)
        )
        navigationItem.leftBarButtonItem = menuButton
        
        // Create right button group
        let editButton = UIBarButtonItem(
            image: UIImage(systemName: "square.and.pencil"),
            style: .plain,
            target: self,
            action: #selector(editButtonTapped)
        )
        editButton.isEnabled = false  // Initially disabled
        editBarButtonItem = editButton  // Save reference
        
        navigationItem.rightBarButtonItems = [editButton]
        
        // Configure navigation bar appearance
        navigationController?.navigationBar.prefersLargeTitles = true
    }
    
    // MARK: - SurfaceManagerListener
    
    /// Surface creation completed callback
    ///
    /// - Parameter surface: Surface object
    func onCreateSurface(_ surface: Surface) {
        print("[Playground] 🎨 Surface created: \(surface.surfaceId)")
        
        surface.updateSize(width: self.view.bounds.width, height: .infinity)
        scrollView.addSubview(surface.view)
        
        surface.onLayoutChanged = { [weak self] in
            guard let self = self else {
                print("[Playground] ⚠️ Layout changed but self is nil for: \(surface.surfaceId)")
                return
            }
            
            // Use surface.view height (view size is determined by Surface's width/height)
            let height = surface.view.frame.size.height
            self.scrollView.contentSize = CGSize(width: scrollView.frame.size.width, height: height)
        }
        
        print("[Playground] ✅ Surface rootView added to container: \(surface.surfaceId)")
    }
    
    /// Surface deletion completed callback
    ///
    /// - Parameter surfaceId: Surface ID
    func onDeleteSurface(_ surfaceId: String) {
        print("[Playground] Surface deleted: \(surfaceId)")

        // Remove all subviews from scrollView
        scrollView.subviews.forEach { $0.removeFromSuperview() }
    }
    
    // MARK: - Actions
    
    @objc private func menuButtonTapped() {
        let menuVC = A2UIPlaygroundMenuViewController()
        menuVC.modalPresentationStyle = .fullScreen
        
        // Set data callback closure
        menuVC.onDataSelected = { [weak self] componentsJSON, dataModelJSON in
            self?.currentComponentsJSON = componentsJSON
            self?.currentDataModelJSON = dataModelJSON
            // Send data uniformly
            self?.sendJSONData(componentsJSON: componentsJSON, dataModelJSON: dataModelJSON)
            // Enable edit button
            self?.editBarButtonItem.isEnabled = true
        }
        
        present(menuVC, animated: true)
    }
    
    @objc private func editButtonTapped() {
        let editVC = A2UIPlaygroundEditViewController()
        editVC.initialComponentsJSON = currentComponentsJSON
        editVC.initialDataModelJSON = currentDataModelJSON
        
        // Set data submission callback
        editVC.onDataSubmitted = { [weak self] componentsJSON, dataModelJSON in
            self?.currentComponentsJSON = componentsJSON
            self?.currentDataModelJSON = dataModelJSON
            // Send data uniformly
            self?.sendJSONData(componentsJSON: componentsJSON, dataModelJSON: dataModelJSON)
        }
        
        editVC.modalPresentationStyle = .fullScreen
        present(editVC, animated: true)
    }
    
    
   // MARK: - Examples.
    
    /// Mock send JSON data part to renderer.
    ///
    /// - Parameters:
    ///   - componentsJSON: Components JSON string
    ///   - dataModelJSON: DataModel JSON string
    private func sendJSONData(componentsJSON: String?, dataModelJSON: String?) {
        // Process Components JSON
        if let componentsJSON = componentsJSON {
            // Try to parse JSON and extract surfaceId
            if let data = componentsJSON.data(using: .utf8),
               let jsonObject = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let updateComponents = jsonObject["updateComponents"] as? [String: Any],
               let surfaceId = updateComponents["surfaceId"] as? String {
                
                // First send deleteSurface for previous surfaceId (if exists)
                if let previousSurfaceId = previousSurfaceId {
                    let deleteSurfaceJSON: [String: Any] = [
                        "version": "v0.9",
                        "deleteSurface": [
                            "surfaceId": previousSurfaceId
                        ]
                    ]
                    
                    if let deleteSurfaceData = try? JSONSerialization.data(withJSONObject: deleteSurfaceJSON, options: []),
                       let deleteSurfaceString = String(data: deleteSurfaceData, encoding: .utf8) {
                        surfaceManager.receiveTextChunk(deleteSurfaceString)
                        print("✅ [Main Page] Sent deleteSurface: surfaceId = \(previousSurfaceId)")
                    }
                }
                
                // Then send createSurface
                let createSurfaceJSON: [String: Any] = [
                    "version": "v0.9",
                    "createSurface": [
                        "surfaceId": surfaceId,
                        "catalogId": "https://a2ui.org/specification/v0_9/basic_catalog.json",
                        "theme": [
                            "primaryColor": "#00BFFF"
                        ],
                        "sendDataModel": true
                    ]
                ]
                
                if let createSurfaceData = try? JSONSerialization.data(withJSONObject: createSurfaceJSON, options: []),
                   let createSurfaceString = String(data: createSurfaceData, encoding: .utf8) {
                    surfaceManager.receiveTextChunk(createSurfaceString)
                    print("✅ [Main Page] Sent createSurface: surfaceId = \(surfaceId)")
                }
                
                // Save current surfaceId for next deletion
                self.previousSurfaceId = surfaceId
            }
            
            // Send Components JSON
            surfaceManager.receiveTextChunk(componentsJSON)
            print("✅ [Main Page] Sent Components data")
        }
        
        // Process DataModel JSON
        if let dataModelJSON = dataModelJSON {
            surfaceManager.receiveTextChunk(dataModelJSON)
            print("✅ [Main Page] Sent DataModel data")
        }
    }
}
