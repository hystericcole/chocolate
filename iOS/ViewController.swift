//
//  ViewController.swift
//  Chocolate
//
//  Created by Eric Cole on 1/27/21.
//	Copyright © 2021 Eric Cole. All rights reserved.
//

import UIKit

class ViewController: BaseTabController {
	override func prepare() {
		super.prepare()
		
		title = DisplayStrings.Chocolate.title
		viewControllers = [ChocolateViewController(), ChocolatePlaneViewController(), ChocolateLumaRampViewController()]
	}
}
