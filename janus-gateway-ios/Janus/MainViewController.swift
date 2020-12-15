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
        videoroomStreamController = VideoroomStreamController(url: "wss://v.here.fm:443/janus",
                                                              roomName: "tCPJmclqm5jLwBSbDk83",
                                                              userName: "j9s1h5MVf2OJ5eHIK2zU43uJufk2",
                                                              delegate: self)

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


extension MainViewController: RTCEAGLVideoViewDelegate {
    /*
     - (void)videoView:(RTCEAGLVideoView *)videoView didChangeVideoSize:(CGSize)size {
         CGRect rect = videoView.frame;
         rect.size = size;
         NSLog(@"========didChangeVideoSize %fx%f", size.width, size.height);
         videoView.frame = rect;
     }
     */
    func videoView(_ videoView: RTCEAGLVideoView, didChangeVideoSize size: CGSize) {
//        var rect = videoView.frame
//        rect.size = size
//        print("========didChangeVideoSize \(size.width)x\(size.height)");
//        videoView.frame = rect
    }
}
