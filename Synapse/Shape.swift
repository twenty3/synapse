//
//  Shape.swift
//  Synapse
//
//  Created by 23 on 5/1/16.
//  Copyright © 2016 Escape Plan. All rights reserved.
//

import Foundation


enum Shape: Int {
    case Circle = 0
    case Square
    case Triangle
    case Last
    
    static let count: Int = {
        return Shape.Last.rawValue
    }()
    
    func toString() -> String {
        switch self {
        case .Circle:
            return "Circle"
        case .Square:
            return "Square"
        case .Triangle:
            return "Triangle"
        default:
            return "Unknown"
        }
    }
}
