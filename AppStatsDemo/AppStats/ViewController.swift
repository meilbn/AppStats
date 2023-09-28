//
//  ViewController.swift
//  AppStats
//
//  Created by Meilbn on 2023/9/26.
//

import UIKit

class ViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
        
        let addEventButton = UIButton(type: .system)
        addEventButton.setTitle("Add Event", for: .normal)
        addEventButton.setTitleColor(.white, for: .normal)
        addEventButton.titleLabel?.font = UIFont.boldSystemFont(ofSize: 18)
        addEventButton.addTarget(self, action: #selector(addEvent), for: .touchUpInside)
        self.view.addSubview(addEventButton)
        addEventButton.frame = CGRect(x: 0, y: 0, width: 100, height: 44)
        addEventButton.center = self.view.center
        
        let uploadButton = UIButton(type: .system)
        uploadButton.setTitle("Upload", for: .normal)
        uploadButton.setTitleColor(.white, for: .normal)
        uploadButton.titleLabel?.font = UIFont.boldSystemFont(ofSize: 18)
        uploadButton.addTarget(self, action: #selector(uploadAppStats), for: .touchUpInside)
        self.view.addSubview(uploadButton)
        uploadButton.frame = CGRect(x: addEventButton.frame.minX, y: addEventButton.frame.maxY + 20, width: 100, height: 44)
    }

    
    @objc private func addEvent() {
        let now = Date()
        AppStats.shared.addAppEvent("add", attrs: ["date_time" : AppStatsHelper.longDateFormatter.string(from: now), "ts" : Int(now.timeIntervalSince1970)])
    }
    
    @objc private func uploadAppStats() {
        AppStats.shared.checkUploadAppCollects()
    }

}

