//
//  STNewsFeedEntry.swift
//  STNewsFeed
//
//  Created by Tiago Mergulhão on 25/12/14.
//  Copyright (c) 2014 Tiago Mergulhão. All rights reserved.
//

//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//  http://www.apache.org/licenses/LICENSE-2.0
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//  See the License for the specific language governing permissions and
//  limitations under the License.

import Foundation

// MARK: - FeedTypes

/**
Enumeration of types of XML feeds supported

- NONE: Still to determine feedtype
- RSS:  Documentation on http://en.wikipedia.org/wiki/RSS
- ATOM: Documentation on http://en.wikipedia.org/wiki/Atom_(standard)
- PODCAST: Documentation on https://www.apple.com/itunes/podcasts/specs.html
*/
public enum FeedType {
    case NONE, RSS, ATOM
    /// Verbose description of types
    var verbose : String {
        switch self {
        case .NONE:
            return ""
        case .RSS:
            return "RSS"
        case .ATOM:
            return "Atom"
        }
    }
    /**
    Encapsulate entry type return methods for the info entity
    
    :param: info Pointer to the feed information structure
    
    :returns: entity of given entry type
    */
    func entry (info : STNewsFeedEntry) -> STNewsFeedEntry? {
        switch info.sourceType {
        case .NONE:
            return nil
        case .RSS:
            return STRSSEntry(info: info)
        case .ATOM:
            return STAtomEntry(info: info)
        }
    }
}

// MARK: - STRSSEntry
/**
RSS entry type with according methods and properties
*/
public class STRSSEntry : STNewsFeedEntry {}

// MARK: - STAtomEntry
/**
Atom entry type with according methods and properties
*/
public class STAtomEntry : STNewsFeedEntry {}

// MARK: - STNewsFeedEntry
/**
Generic non intanciable entry type with according methods and properties
*/
public class STNewsFeedEntry: NSObject {
    
    // MARK: - Lazy contextual mandatory variables
    public lazy var title : String! = self.properties.findAny("title", "subtitle", "description", "summary", "url", "link")
    public lazy var link : String! = self.properties.findAny("link", "url", "address")
    public lazy var date : NSDate! = self.parseDate()
    
    internal lazy var normalized : Bool = self.normalize()
    
    // MARK: - Lazy contextual optional variables
    public lazy var summary : String? = self.properties.findAny("subtitle", "description", "summary")
    public lazy var subtitle : String? = self.summary
    public lazy var domain : String? = (self.link + "/" =~ "^https?://(?:www\\.)?([A-Za-z0-9-]+\\.[A-Za-z0-9]+)").items.last
    
    // MARK: - Internal
    public var sourceType : FeedType = FeedType.NONE
    public weak var info : STNewsFeedEntry!
    internal var properties : [String : String] = Dictionary<String, String>()
    
    internal func normalize () -> Bool {
        if title == nil { return false }
        if link == nil { return false }
        if date == nil { return false }
        
        if info == nil {return false}
        
        return true
    }
    
    /**
    Method for parsing datetime of given date encoding.
    Supports partially RFC822 and RFC3339
    
    :returns: optional of date
    */
    private func parseDate() -> NSDate? {
        
        if let dateString = properties.findAny(
            
            // RSS standart tags
            "pubDate", "lastBuildDate",
            "dc:date", // A List Apart requirement
            
            // Atom standart tags
            "updated", "published"
            ) {
                
                var dateFormat = NSDateFormatter()
                
                // RFC822 date format
                // RSS Standart
                dateFormat.dateFormat = "EEE, dd MMM yyyy HH:mm:ss z"
                
                if let date = dateFormat.dateFromString(dateString) {
                    return date
                }
                
                // TODO: Consistent date parsings
                // Another A List Apart requirement
                // "2014-12-26T17:17:00+00:00"
                // https://developer.apple.com/library/ios/documentation/Cocoa/Conceptual/DataFormatting/Articles/dfDateFormatting10_4.html
                //
                // Some variation of the RFC3339 date format
                // Date formating is a serious data dump problem
                // Atom Standart
                
                var trimDateString = dateString.substringWithRange(
                    Range<String.Index>(
                        start: advance(dateString.startIndex, 0),
                        end: advance(dateString.startIndex/*endIndex*/, 19)
                    )
                )
                
                dateFormat.dateFormat = "yyyy'-'MM'-'dd'T'HH':'mm':'ss'Z'"
                dateFormat.locale = NSLocale(localeIdentifier: "en_US_POSIX")
                dateFormat.timeZone = NSTimeZone(forSecondsFromGMT: 0)
                
                if let date = dateFormat.dateFromString(trimDateString) {
                    return date
                }
        }
        
        return nil
    }
    /**
    Init method for the feed header entity
    
    :returns: The feed header entity
    */
    internal override init () {}
    
    /**
    Init method for the entry entity
    
    :param: info A news feed entry type with the header of the feed
    
    :returns: The entry entity
    */
    internal init (info : STNewsFeedEntry!) {
        self.info = info
        
        sourceType = info.sourceType
    }
}
