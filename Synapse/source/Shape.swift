//
//  Shape.swift
//  Synapse
//
//  Created by 23 on 5/1/16.
//  Copyright © 2016 Escape Plan. All rights reserved.
//

import Foundation


enum Shape: Int {
    case circle = 0
    case square
    case triangle
    case last
    
    static let count: Int = {
        return Shape.last.rawValue
    }()
    
    func toString() -> String {
        switch self {
        case .circle:
            return "Circle"
        case .square:
            return "Square"
        case .triangle:
            return "Triangle"
        default:
            return "Unknown"
        }
    }
    
    func toSymbol() -> String {
        switch self {
        case .circle:
            return "⚫︎"
        case .square:
            return "■"
        case .triangle:
            return "▲"
        default:
            return "🤔"
        }
    }
}
