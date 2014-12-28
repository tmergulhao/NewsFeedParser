//
//  DictionaryExtension.swift
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

// MARK: - Dictionary Extension

internal extension Dictionary {
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
