//
//  STHTMLFeedDiscovery.swift
//  STNewsFeedParser
//
//  Created by Tiago Mergulhão on 26/12/14.
//  Copyright (c) 2014 Tiago Mergulhão. All rights reserved.
//

import XCTest

import STNewsFeedParser

// MARK: - XCTests

/**
*  <#Description#>
*/

internal class STTestHTMLPageDiscovery: XCTestCase, STNewsFeedDiscoveryDelegate {
	
	var expectations : Dictionary<String, XCTestExpectation> = [String : XCTestExpectation]()
	
	var sampleAddresses = [
		"http://daringfireball.net/",
		"http://www.swiss-miss.com/",
		"http://nautil.us/",
		"http://zenhabits.net/",
		"http://blog.codinghorror.com/",
		"http://red-glasses.com/",
		"http://bldgblog.blogspot.com/",
		"http://alistapart.com/"
	]
	
	override func setUp() {
		super.setUp()
		
		for address in sampleAddresses {
			if let someURL = NSURL(string: address) {
				pages.append(STNewsFeedDiscovery(pageFromUrl: someURL))
				
				// expectations[address] = expectationWithDescription("Parsed \(address)")
			} else {
				XCTAssert(false, "Unable to instance NSURL : \(address)")
			}
		}
	}
	
	func testHTMLPageDiscovery () {
		println()
		
		for page in pages {
			page.delegate = self
			page.discover()
		}
	}
	
    // MARK: - STNewsFeedDiscovery
    
    func feedDiscovery(page: STNewsFeedDiscovery, corruptHTML error: NSError) {
		println(error.description)
	}
	func feedDiscovery(didFinishPage page: STNewsFeedDiscovery, withAddresses addresses: Array<FeedAddress>) {
		println(page.title)
		println(page.imageURL?.absoluteString)
		
		for address in page.addresses {
			println("\t\(address.type.verbose) : \(address.title!), \(address.url.absoluteString!)")
		}
		
		println()
	}
	
	var pages = [STNewsFeedDiscovery]()
}
