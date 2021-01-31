//
//  ViewController.swift
//  Chocolate
//
//  Created by Eric Cole on 1/27/21.
//

import UIKit

class ViewController: BaseViewController {
	override func viewDidLoad() {
		super.viewDidLoad()
	}
	
	override func viewWillAppear() {
		super.viewWillAppear()
		
		replaceChild(with:ChocolateViewController())
		//replaceChild(with:ChocolateLayerViewController())
	}
}
