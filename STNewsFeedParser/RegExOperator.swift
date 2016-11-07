//
//  RegExOperator.swift
//  STNewsFeedParser
//
//  Created by Tiago Mergulhão on 26/12/14.
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

// MARK: - Regular Expression Extension

infix operator =~

func =~ (value : String, pattern : String) -> RegexMatchResult {
    let nsstr = value as NSString // we use this to access the NSString methods like .length and .substringWithRange(NSRange)
    
    var err : NSError?
    let options = NSRegularExpression.Options(0)
    let re = NSRegularExpression(pattern: pattern, options: options, error: &err)
    if let e = err {
        return RegexMatchResult(items: [])
    }
    
    let all = NSRange(location: 0, length: nsstr.length)
    let moptions = NSRegularExpression.MatchingOptions(0)
    var matches : Array<String> = []
    re!.enumerateMatchesInString(value, options: moptions, range: all) {
        (result : NSTextCheckingResult!, flags : NSRegularExpression.MatchingFlags, ptr : UnsafeMutablePointer<ObjCBool>) in
        
        for rangeIndex in 0..<result.numberOfRanges {
            let range = result.rangeAtIndex(rangeIndex)
            
            if range.location + range.length < nsstr.length {
                let string = nsstr.substringWithRange(range)
                
                matches.append(string)
            }
        }
    }
    return RegexMatchResult(items: matches)
}

struct RegexMatchCaptureGenerator : IteratorProtocol {
    mutating func next() -> String? {
        if items.isEmpty { return nil }
        let ret = items[0]
        items = items[1..<items.count]
        return ret
    }
    var items: ArraySlice<String>
}

struct RegexMatchResult : Sequence {
    var items: Array<String>
    func makeIterator() -> RegexMatchCaptureGenerator {
        return RegexMatchCaptureGenerator(items: items[0..<items.count])
    }
    var boolValue: Bool {
        return items.count > 0
    }
    subscript (i: Int) -> String {
        return items[i]
    }
}
