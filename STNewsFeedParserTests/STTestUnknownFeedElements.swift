//
//  STTestFeedElements.swift
//  STNewsFeedParser
//
//  Created by Tiago Mergulhão on 22/01/15.
//  Copyright (c) 2015 Tiago Mergulhão. All rights reserved.
//

import XCTest

import STNewsFeedParser

// MARK: - XCTests

/**
*  <#Description#>
*/

internal class STTestUnknownFeedElements: STNewsFeedParserTests, STNewsFeedParserDelegate {
	
	func testUnknownFeedElements () {
		for feed in feeds {
			feed.delegate = self
			feed.parse()
		}
		
		self.waitForExpectationsWithTimeout(10 as NSTimeInterval, handler: {
			error in
			XCTAssertNil(error, "Error")
		})
	}
	
	// MARK: - STNewsFeedParserDelegate
	
	func newsFeed(didFinishFeedParsing feed: STNewsFeedParser) { expectations[feed.address]!.fulfill() }

	func newsFeed(XMLParserErrorOn feed : STNewsFeedParser, withError error:NSError) {}
	func newsFeed(corruptFeed feed : STNewsFeedParser,		withError error:NSError) {}

	func newsFeed(unknownElementOn feed: STNewsFeedParser, ofName elementName: String, withAttributes attributeDict: NSDictionary, andContent content: String) {
		println("\(feed.info.title) : \(elementName) : \(content)")
		println("\(attributeDict)")
	}
}
