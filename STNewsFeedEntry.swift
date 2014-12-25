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

private extension Dictionary {
    /**
    Return first match for given key on keys or nil
    
    :param: keys Hashable key values for Dictionary type
    
    :returns: Return first found value or nil
    */
    func findAny (keys : Key...) -> Value? {
        for key in keys {
            if let result = self[key] {
                return result
            }
        }
        
        return nil
    }
}
/**
Enumeration of types of XML feeds supported

- NONE: Still to determine feedtype
- RSS:  Documentation on http://en.wikipedia.org/wiki/RSS
- ATOM: Documentation on http://en.wikipedia.org/wiki/Atom_(standard)
*/
internal enum FeedType {
    case NONE, RSS, ATOM
}
/**
Collective type of information about feed. Contains all properties and functionality of NewsFeedEntry as it inherits directly from it. Does not need a information to initialize, through.
*/
public class STNewsFeedInfo : STNewsFeedEntry {
    internal var sourceType : FeedType = FeedType.NONE
    internal init () {
        super.init(feed: nil)
        
        info = self
    }
}

public class STNewsFeedEntry: NSObject {
    // MARK: - Bound
    public var title : String!
    public var date : NSDate!
    public var address : String!
    public weak var info : STNewsFeedInfo!
    
    // MARK: - Optional
    public var summary : String? {
        return properties.findAny("subtitle", "description", "summary")
    }
    
    // MARK: - Internal
    internal var properties : [String : String] = Dictionary<String, String>()
    internal init (feed : STNewsFeedInfo!) {
        self.info = feed
    }
    internal var normalized : Bool {
        if title == nil {
            title = properties.findAny("title", "subtitle", "description", "summary", "url", "link")
            if title == nil {return false}
        }
        if address == nil {
            address = properties.findAny("link", "url")
            if address == nil {return false}
        }
        
        if let raw = properties.findAny("updated", "lastupdated", "pubDate", "published", "lastBuildDate") {
            let type = info.sourceType
            
            switch info.sourceType {
            case .ATOM:
                date = parseRFC3339DateFromString(raw)
            case .RSS:
                date = parseRFC822DateFromString(raw)
            case .NONE:
                date = nil
            }
        }
        
        if date == nil {return false}
        if info == nil {return false}
        
        return true
    }
    
    // MARK: - Date locale formatter
    /**
    ATOM feed locale
    
    :param: string data
    
    :returns: date optional
    */
    private func parseRFC3339DateFromString(string:String) -> NSDate? {
        let enUSPOSIXLocale = NSLocale(localeIdentifier: "en_US_POSIX")
        
        let rfc3339DateFormatter = NSDateFormatter()
        rfc3339DateFormatter.locale = enUSPOSIXLocale
        rfc3339DateFormatter.dateFormat = "yyyy'-'MM'-'dd'T'HH':'mm':'ss'Z'"
        rfc3339DateFormatter.timeZone = NSTimeZone(forSecondsFromGMT: 0)
        
        return rfc3339DateFormatter.dateFromString(string)
    }
    
    /**
    RSS feed locale
    
    :param: string data
    
    :returns: date optional
    */
    private func parseRFC822DateFromString(string:String) -> NSDate? {
        var dateFormat = NSDateFormatter()
        
        dateFormat.dateFormat = "EEE, dd MMM yyyy HH:mm:ss z"
        
        return dateFormat.dateFromString(string)
    }
}
