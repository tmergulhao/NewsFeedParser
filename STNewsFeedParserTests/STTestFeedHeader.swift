//
//  STTestFeedHeader.swift
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

internal class STTestFeedHeader : STNewsFeedParserTests, STNewsFeedParserDelegate {
	
	func testFeedHeader () {
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
	
	func newsFeed(shouldBeginFeedParsing feed: STNewsFeedParser) -> Bool {
		println("\(feed.info.sourceType.verbose) : \(feed.info.title) on \(feed.info.domain!)")
		expectations[feed.address]!.fulfill()
		
		return false
	}
	func newsFeed(didFinishFeedParsing feed: STNewsFeedParser) {}
	
	func newsFeed(XMLParserErrorOn feed : STNewsFeedParser, withError error:NSError) {}
	func newsFeed(corruptFeed feed : STNewsFeedParser,		 withError error:NSError) {}
	
	func newsFeed(unknownElementOn feed: STNewsFeedParser, ofName elementName: String, withAttributes attributeDict: NSDictionary, andContent content: String) {}
}
