//
//  ViewController.swift
//  VideoOverlays
//
//  Created by Muhammad Abed Ekrazek on 9/6/18.
//  Copyright © 2018 Muhammad Abed Ekrazek. All rights reserved.
//

import UIKit
import MobileCoreServices
import AVFoundation

class ViewController: UIViewController , UIImagePickerControllerDelegate, UINavigationControllerDelegate
{
    
    private var chooseVideoBtn1 : UIButton!
    private var chooseVideoBtn2 : UIButton!
    private var cropBtn : UIButton!
    
    
    private var mergeBtn : UIButton!
    
    private var videoLayer : AVPlayerLayer!
    private var player : AVPlayer!
    
    private var currenttag = 0
    
    private var url1 : URL!
    private var url2 : URL!
    
    override func viewDidLoad()
    {
        super.viewDidLoad()
        
        self.chooseVideoBtn1 = UIButton(frame: CGRect(x: 0, y: 60, width: self.view.bounds.width, height: CGFloat(40)))
        self.chooseVideoBtn1.setTitle("Choose BackGround video", for: .normal)
        self.chooseVideoBtn1.setTitleColor(.white, for: .normal)
        self.chooseVideoBtn1.backgroundColor = .red
        self.view.addSubview(self.chooseVideoBtn1)
        self.chooseVideoBtn1.tag = 0
        self.chooseVideoBtn1.addTarget(self, action: #selector(self.btnClicked(sender:)), for: .touchUpInside)
        
        self.chooseVideoBtn2 = UIButton(frame: CGRect(x: 0, y: 100, width: self.view.bounds.width, height: CGFloat(40)))
        self.chooseVideoBtn2.setTitle("Choose Front video", for: .normal)
        self.chooseVideoBtn2.setTitleColor(.white, for: .normal)
        self.chooseVideoBtn2.backgroundColor = .blue
        self.view.addSubview(self.chooseVideoBtn2)
        self.chooseVideoBtn2.tag = 1
        self.chooseVideoBtn2.addTarget(self, action: #selector(self.btnClicked(sender:)), for: .touchUpInside)
        
        self.mergeBtn = UIButton(frame: CGRect(x: 0, y: 140, width: self.view.bounds.width, height: CGFloat(40)))
        self.mergeBtn.setTitle("!MERGE!", for: .normal)
        self.mergeBtn.setTitleColor(.white, for: .normal)
        self.mergeBtn.backgroundColor = .black
        self.view.addSubview(self.mergeBtn)
        self.mergeBtn.addTarget(self, action: #selector(self.mergeBtnClicked(sender:)), for: .touchUpInside)
        
        
        self.cropBtn = UIButton(frame: CGRect(x: 0, y: 180, width: self.view.bounds.width, height: CGFloat(40)))
        self.cropBtn.setTitle("CROP", for: .normal)
        self.cropBtn.setTitleColor(.white, for: .normal)
        self.cropBtn.backgroundColor = UIColor.darkGray
        self.view.addSubview(self.cropBtn)
        self.cropBtn.addTarget(self, action: #selector(self.cropBtnClicked(sender:)), for: .touchUpInside)
    }
    
    override func didReceiveMemoryWarning()
    {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    
    @objc func cropBtnClicked(sender : UIButton)
    {
        VideoProcessor.cropSquareVideo(with: self.url1) { (croppedUrl) in
            
            if let _url = croppedUrl
            {
                self.playWith(url: _url)
            }
        }
    }
    
    @objc func btnClicked(sender : UIButton)
    {
        self.currenttag = sender.tag
        let imagePicker = UIImagePickerController()
        imagePicker.delegate = self
        imagePicker.sourceType = .savedPhotosAlbum
        imagePicker.mediaTypes = [kUTTypeMovie as String, kUTTypeVideo as String]
        imagePicker.allowsEditing = true
        
        self.present(imagePicker, animated: true, completion: nil)
    }
    
    
    @objc func mergeBtnClicked(sender : UIButton)
    {
        print("merging...")
        VideoProcessor.mergeBgVideo(self.url1, withForeGroundVideo: self.url2) { (mergedUrl) in
            
            print("finished merging with link :\(mergedUrl)")
            
            if let _mergedLink = mergedUrl
            {
                self.playWith(url: _mergedLink)
            }
            
            
        }
    }
    
    
    func playWith(url : URL)
    {
        DispatchQueue.main.async {
            self.player = AVPlayer(url: url)
            self.player.actionAtItemEnd = AVPlayerActionAtItemEnd.none
            
            self.videoLayer = AVPlayerLayer(player: self.player)
            self.videoLayer.backgroundColor = UIColor.green.cgColor
            
            self.videoLayer.frame = CGRect(x: 0, y: 220, width: self.view.bounds.width, height: self.view.bounds.width)
            
            
            
            self.videoLayer!.videoGravity = AVLayerVideoGravity.resize
            self.view.layer.addSublayer(self.videoLayer)
            
            self.player.play()
            
            NotificationCenter.default.addObserver(self, selector: #selector(self.videoPlayerFinishedPlaying(_:)), name: NSNotification.Name.AVPlayerItemDidPlayToEndTime, object: self.player.currentItem!)
            
        }
        
        
    }
    
    @objc func videoPlayerFinishedPlaying(_ notification : Foundation.Notification)
    {
        if let item = notification.object as? AVPlayerItem
        {
            item.seek(to: kCMTimeZero)
        }
    }
    
    
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [String : Any])
    {
        DispatchQueue.main.async {
            
            picker.dismiss(animated: true, completion: nil)
            
            if let url = info[UIImagePickerControllerMediaURL] as? URL
            {
                if self.currenttag == 0
                {
                    self.url1 = url
                }
                else
                {
                    self.url2 = url
                }
            }
        }
    }
    
    func imagePickerControllerDidCancel(_ picker: UIImagePickerController)
    {
        picker.dismiss(animated: true, completion: nil)
    }
    
    
}

