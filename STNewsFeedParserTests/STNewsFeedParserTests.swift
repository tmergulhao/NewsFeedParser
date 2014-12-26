//
//  STNewsFeedParserTests.swift
//  STNewsFeedParserTests
//
//  Created by Tiago Mergulhão on 25/12/14.
//  Copyright (c) 2014 Tiago Mergulhão. All rights reserved.
//

import UIKit
import XCTest

class STNewsFeedParserTests: XCTestCase, STNewsFeedParserDelegate {
    
    var parsers : Dictionary<String, STNewsFeedParser> = [:]
    
    var verbose : Bool = false
    
    func willBeginFeedParsing(feed : STNewsFeedParser) {
        println()
        println("\(feed.info.properties)")
        println()
        feed.abortParsing()
    }
    func didFinishFeedParsing(feed : STNewsFeedParser) {}
    func newsFeed(feed : STNewsFeedParser, XMLParserError error:NSError) {}
    func newsFeed(feed : STNewsFeedParser, corruptFeed error:NSError) {}
    func newsFeed(feed : STNewsFeedParser, unknownElement elementName:String, withAttributes attributeDict:NSDictionary, andError error: NSError) {}
    
    override func setUp() {
        super.setUp()
        
        var feeds = [
            "http://daringfireball.net/feeds/main",
            "http://feeds.gawker.com/lifehacker/full",
            "http://www.swiss-miss.com/feed",
            "http://nautil.us/rss/all",
            "http://feeds.feedburner.com/zenhabits",
            "http://feeds.feedburner.com/codinghorror",
            "http://red-glasses.com/index.php/feed/",
            "http://bldgblog.blogspot.com/feeds/posts/default?alt=rss",
            "http://alistapart.com/site/rss"]
        
        for address in feeds {
            if let url = NSURL(string: address) {
                var feed = STNewsFeedParser(feedFromUrl: url)
                
                parsers[address] = feed
            }
        }
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
        
        parsers.removeAll(keepCapacity: false)
    }
    
    func testFetchNewEntriesVerbose() {
        verbose = true
        
        for parser in self.parsers.values {
            parser.delegate = self
            
            let calendar = NSCalendar.currentCalendar()
            let yesterday = calendar.dateByAddingUnit(.CalendarUnitDay, value: -1, toDate: NSDate(), options: nil)
            
            parser.lastUpdated = yesterday
            
            parser.parse()
        }
        
        // XCTAssert(true, "Pass")
    }
    
    func testA () {
        for parser in self.parsers.values {
            
            parser.delegate = self
            
            parser.parse()
        }
    }
    
    func testMeasureDispatchParsing () {
        self.measureBlock() {
            for parser in self.parsers.values {
                
                parser.delegate = self
                
                parser.parse()
            }
        }
    }
    
}
