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

// MARK - Regular Expression

infix operator =~ {}

func =~ (value : String, pattern : String) -> RegexMatchResult {
    let nsstr = value as NSString // we use this to access the NSString methods like .length and .substringWithRange(NSRange)
    
    var err : NSError?
    let options = NSRegularExpressionOptions(0)
    let re = NSRegularExpression(pattern: pattern, options: options, error: &err)
    if let e = err {
        return RegexMatchResult(items: [])
    }
    
    let all = NSRange(location: 0, length: nsstr.length)
    let moptions = NSMatchingOptions(0)
    var matches : Array<String> = []
    re!.enumerateMatchesInString(value, options: moptions, range: all) {
        (result : NSTextCheckingResult!, flags : NSMatchingFlags, ptr : UnsafeMutablePointer<ObjCBool>) in
        let string = nsstr.substringWithRange(result.range)
        matches.append(string)
    }
    return RegexMatchResult(items: matches)
}

struct RegexMatchCaptureGenerator : GeneratorType {
    mutating func next() -> String? {
        if items.isEmpty { return nil }
        let ret = items[0]
        items = items[1..<items.count]
        return ret
    }
    var items: Slice<String>
}

struct RegexMatchResult : SequenceType, BooleanType {
    var items: Array<String>
    func generate() -> RegexMatchCaptureGenerator {
        return RegexMatchCaptureGenerator(items: items[0..<items.count])
    }
    var boolValue: Bool {
        return items.count > 0
    }
    subscript (i: Int) -> String {
        return items[i]
    }
}

// MARK - Dictionary Extension

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
public enum FeedType {
    case NONE, RSS, ATOM
    var verbose : String {
        switch self {
        case .NONE:
            return "NONE"
        case .RSS:
            return "RSS"
        case .ATOM:
            return "ATOM"
        }
    }
}
/**
Collective type of information about feed. Contains all properties and functionality of NewsFeedEntry as it inherits directly from it. Does not need a information to initialize, through.
*/
public class STNewsFeedInfo : STNewsFeedEntry {
    public var sourceType : FeedType = FeedType.NONE
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
    public var domain : String? {
        var result = address =~ "^(https?://[A-Za-z0-9.-]+\\.[A-Za-z]{2,4})"
        
        if result.boolValue {
            return result.items[0]
        }
        
        return nil
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
            address = properties.findAny("link", "url", "address")
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
