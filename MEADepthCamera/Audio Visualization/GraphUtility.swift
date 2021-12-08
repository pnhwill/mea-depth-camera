//
//  GraphUtility.swift
//  MEADepthCamera
//
//  Created by Will on 11/27/21.
//

import Accelerate
import UIKit

/// Class containing static methods for graph drawing.
class GraphUtility {
    
    // MARK: - Line Graph
    
    /// Draws a series of values as a line graph with points equally spaced along the horizontal axis.
    static func drawGraphInLayer(_ layer: CAShapeLayer,
                                 strokeColor: CGColor,
                                 lineWidth: CGFloat = 1,
                                 values: [Float],
                                 minimum: Float? = nil,
                                 maximum: Float? = nil,
                                 hScale: CGFloat = 1) {
        
        layer.fillColor = nil
        layer.strokeColor = strokeColor
        layer.lineWidth = lineWidth
        
        let n = vDSP_Length(values.count)
        
        // normalize values in array (i.e. scale to 0-1)...
        var min: Float = 0
        if let minimum = minimum {
            min = minimum
        } else {
            vDSP_minv(values, 1, &min, n)
        }
        
        var max: Float = 0
        if let maximum = maximum {
            max = maximum
        } else {
            vDSP_maxv(values, 1, &max, n)
        }
        
        var scale = 1 / (max - min)
        var minusMin = -min
        
        var scaled = [Float](repeating: 0, count: values.count)
        vDSP_vasm(values, 1, &minusMin, 0, &scale, &scaled, 1, n)
        
        let path = CGMutablePath()
        let xScale = layer.frame.width / CGFloat(values.count)
        let points = scaled.enumerated().map {
            return CGPoint(x: xScale * hScale * CGFloat($0.offset),
                           y: layer.frame.height * CGFloat(1.0 - ($0.element.isFinite ? $0.element : 0)))
        }
        
        path.addLines(between: points)
        layer.path = path
    }
    
    // MARK: - Spectrogram
    
    // Lookup tables for color transforms.
    static var redTable: [Pixel_8] = (0 ... 255).map {
        return brgValue(from: $0).red
    }
    
    static var greenTable: [Pixel_8] = (0 ... 255).map {
        return brgValue(from: $0).green
    }
    
    static var blueTable: [Pixel_8] = (0 ... 255).map {
        return brgValue(from: $0).blue
    }
    
    /// Returns the RGB values from a blue -> red -> green color map for a specified value.
    ///
    /// `value` controls hue and brightness. Values near zero return dark blue, `127` returns red, and
    ///  `255` returns full-brightness green.
    static func brgValue(from value: Pixel_8) -> (red: Pixel_8,
                                                  green: Pixel_8,
                                                  blue: Pixel_8) {
        let normalizedValue = CGFloat(value) / 255
        
        // Define `hue` that's blue at `0.0` to red at `1.0`.
        let hue = 0.6666 - (0.6666 * normalizedValue)
        let brightness = sqrt(normalizedValue)

        let color = UIColor(hue: hue,
                            saturation: 1,
                            brightness: brightness,
                            alpha: 1)
        
        var red = CGFloat()
        var green = CGFloat()
        var blue = CGFloat()
        
        color.getRed(&red,
                     green: &green,
                     blue: &blue,
                     alpha: nil)
        
        return (Pixel_8(green * 255),
                Pixel_8(red * 255),
                Pixel_8(blue * 255))
    }
    
}
