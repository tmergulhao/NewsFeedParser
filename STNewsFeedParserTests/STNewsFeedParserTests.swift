//
//  STNewsFeedParserTests.swift
//  STNewsFeedParserTests
//
//  Created by Tiago Mergulhão on 25/12/14.
//  Copyright (c) 2014 Tiago Mergulhão. All rights reserved.
//

import XCTest

//	TODO: Instrumentalize tests
//	http://www.raywenderlich.com/23037/how-to-use-instruments-in-xcode

/**
	Asynchronous test suite made based on XCTest library
	Explanatory articles on the technique used on:
*	http://nshipster.com/xctestcase/
*	http://blog.dadabeatnik.com/2014/07/13/asynchronous-unit-testing-in-xcode-6/
*	http://www.objc.io/issue-15/xctest.html
*/

internal class STNewsFeedParserTests : XCTestCase {
	
	var expectations : Dictionary<String, XCTestExpectation> = [String : XCTestExpectation]()
	
	var sampleAddresses = [
		"http://daringfireball.net/feeds/main",
		"http://www.swiss-miss.com/feed",
		"http://nautil.us/rss/all",
		"http://feeds.feedburner.com/zenhabits",
		"http://feeds.feedburner.com/codinghorror",
		"http://red-glasses.com/index.php/feed/",
		"http://bldgblog.blogspot.com/feeds/posts/default?alt=rss",
		"http://alistapart.com/site/rss"
	]
	
	override func setUp() {
		super.setUp()
		
		for address in sampleAddresses {
			if let someURL = NSURL(string: address) {
				feeds.append(STNewsFeedParser(
					    feedFromUrl: someURL,
					concurrencyType: STNewsFeedParserConcurrencyType.PrivateQueue))
				
				expectations[address] = expectationWithDescription("Parsed \(address)")
			} else {
				XCTAssert(false, "Unable to instance NSURL : \(address)")
			}
		}
	}
	
	// MARK: - STNewsFeedParser
	
	var feeds = [STNewsFeedParser]()
	var feed : STNewsFeedParser?
}
