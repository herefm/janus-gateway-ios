//
//  MainViewController.swift
//  janus-gateway-ios
//
//  Created by Jesse Boyes on 12/13/20.
//  Copyright © 2020 H3R3. All rights reserved.
//

import UIKit

class MainViewController: UIViewController {
    var height: Int = 0
    var localView: RTCCameraPreviewView!
    var videoroomStreamController: VideoroomStreamController!

    override func viewDidLoad() {
        super.viewDidLoad()
        videoroomStreamController = VideoroomStreamController(url: "wss://v2.here.fm:443/janus",
                                                              roomName: "ZInARgyrVYXjj2NukBNu",
                                                              userName: "j9s1h5MVf2OJ5eHIK2zU43uJufk2",
                                                              delegate: self)

        let cameraSwitchButton = UIButton(type: .roundedRect)
        cameraSwitchButton.frame = CGRect(x: 200, y: 20, width: 150, height: 44)
        cameraSwitchButton.setTitle("Back/Front", for: .normal)
        cameraSwitchButton.addTarget(self, action: #selector(switchCamera), for: .touchUpInside)
        self.view.addSubview(cameraSwitchButton)
    }

    @objc func switchCamera(_ sender: UIControl) {
        videoroomStreamController.updateCameraPosition(videoroomStreamController.cameraPosition == .back ? .front : .back)
    }


}

extension MainViewController: VideoroomStreamControllerDelegate {
    func videoroomDidAdd(_ userId: String?, streamView: RTCEAGLVideoView) {
        height += 90;
        streamView.frame = CGRect(x: 0, y: height, width: 120, height: 90)
        streamView.delegate = self
        self.view.addSubview(streamView)
    }

    func localCaptureSessionReady(_ captureSession: AVCaptureSession) {
        if localView == nil {
            localView = RTCCameraPreviewView(frame: CGRect(x: 0, y: 0, width: 120, height: 90))
            self.view.addSubview(localView)
        }
        localView.captureSession = captureSession
    }
}


extension MainViewController: RTCVideoViewDelegate {
    func videoView(_ videoView: RTCVideoRenderer, didChangeVideoSize size: CGSize) {
        // TODO
    }
}
