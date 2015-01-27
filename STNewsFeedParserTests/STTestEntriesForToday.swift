//
//  STTestFeedsForToday.swift
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

internal class STTestEntriesForToday : STNewsFeedParserTests, STNewsFeedParserDelegate {
	
	func testEntriesForToday () {
		for feed in feeds {
			let calendar = NSCalendar.currentCalendar()
			let yesterday = calendar.dateByAddingUnit(.CalendarUnitDay, value: -2, toDate: NSDate(), options: nil)
			
			feed.lastUpdated = yesterday
			
			feed.delegate = self
			feed.parse()
		}
		
		self.waitForExpectationsWithTimeout(10 as NSTimeInterval, handler: {
			error in
			XCTAssertNil(error, "Error")
		})
	}
	
	// MARK: - STNewsFeedParserDelegate
	
	func newsFeed(didFinishFeedParsing feed: STNewsFeedParser) {
		println("\(feed.info.sourceType.verbose) : \(feed.info.title) on \(feed.info.domain!)")
		
		for entry in feed.entries {
			println("\t\(entry.title)")
			println("\t\(entry.link)")
			println("\t\(entry.date)")
			println("\t\(entry.domain)")
		}
		
		expectations[feed.address]!.fulfill()
	}
	
	func newsFeed(XMLParserErrorOn feed : STNewsFeedParser, withError error:NSError) {}
	func newsFeed(corruptFeed feed : STNewsFeedParser,		 withError error:NSError) {}
	
	func newsFeed(unknownElementOn feed: STNewsFeedParser, ofName elementName: String, withAttributes attributeDict: NSDictionary, andContent content: String) {}
}