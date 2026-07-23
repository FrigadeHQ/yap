#!/usr/bin/env swift

// Generates Yap's app icon as a .iconset of PNGs.
//
//   swift Tools/GenerateIcon.swift <output-iconset-dir>
//   iconutil -c icns <output-iconset-dir> -o Sources/Yap.icns
//
// Drawn with CoreGraphics rather than shipped as an opaque binary so the icon
// is reviewable and reproducible. A simple studio-condenser silhouette: capsule
// head with a grille, a slim stem, and a base — on a graphite squircle.

import AppKit
import CoreGraphics
import Foundation

// Design space is 1024×1024; every coordinate scales from there.
let design: CGFloat = 1024

func draw(size: CGFloat, into context: CGContext) {
    let s = size / design
    func x(_ v: CGFloat) -> CGFloat { v * s }

    context.setShouldAntialias(true)
    context.interpolationQuality = .high

    // MARK: Squircle background
    // Big Sur+ proportions: an 824pt shape centred in a 1024pt canvas.
    let plate = CGRect(x: x(100), y: x(100), width: x(824), height: x(824))
    let plateRadius = x(185.4)
    let platePath = CGPath(roundedRect: plate, cornerWidth: plateRadius, cornerHeight: plateRadius, transform: nil)

    context.saveGState()
    context.addPath(platePath)
    context.clip()

    let space = CGColorSpaceCreateDeviceRGB()
    let backdrop = CGGradient(
        colorsSpace: space,
        colors: [
            CGColor(red: 0.243, green: 0.267, blue: 0.341, alpha: 1), // #3E4457
            CGColor(red: 0.098, green: 0.110, blue: 0.149, alpha: 1), // #191C26
        ] as CFArray,
        locations: [0, 1]
    )!
    context.drawLinearGradient(
        backdrop,
        start: CGPoint(x: plate.midX, y: plate.maxY),
        end: CGPoint(x: plate.midX, y: plate.minY),
        options: []
    )
    context.restoreGState()

    // MARK: Microphone
    let bodyFill = CGGradient(
        colorsSpace: space,
        colors: [
            CGColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 1),
            CGColor(red: 0.847, green: 0.859, blue: 0.886, alpha: 1), // #D8DBE2
        ] as CFArray,
        locations: [0, 1]
    )!

    // Base — kept narrow; a wide one makes the whole thing read as a trophy.
    let base = CGRect(x: x(427), y: x(196), width: x(170), height: x(34))
    context.saveGState()
    context.addPath(CGPath(roundedRect: base, cornerWidth: x(17), cornerHeight: x(17), transform: nil))
    context.clip()
    context.drawLinearGradient(bodyFill,
                              start: CGPoint(x: base.midX, y: base.maxY),
                              end: CGPoint(x: base.midX, y: base.minY),
                              options: [])
    context.restoreGState()

    // Stem
    let stem = CGRect(x: x(496), y: x(220), width: x(32), height: x(140))
    context.saveGState()
    context.addPath(CGPath(rect: stem, transform: nil))
    context.clip()
    context.drawLinearGradient(bodyFill,
                              start: CGPoint(x: stem.midX, y: stem.maxY),
                              end: CGPoint(x: stem.midX, y: stem.minY),
                              options: [])
    context.restoreGState()

    // Head — a rounded rectangle, not a full capsule. This is what gives it the
    // squared-off Neumann look instead of an egg on a stick.
    let head = CGRect(x: x(372), y: x(340), width: x(280), height: x(470))
    let headPath = CGPath(roundedRect: head, cornerWidth: x(90), cornerHeight: x(90), transform: nil)
    context.saveGState()
    context.addPath(headPath)
    context.clip()
    context.drawLinearGradient(bodyFill,
                              start: CGPoint(x: head.minX, y: head.maxY),
                              end: CGPoint(x: head.maxX, y: head.minY),
                              options: [])

    // Grille: horizontal slots across the upper part of the head, clipped to it.
    // Skipped at small sizes where they'd turn to mud.
    if size >= 64 {
        context.setStrokeColor(CGColor(red: 0, green: 0, blue: 0, alpha: 0.16))
        context.setLineWidth(x(14))
        context.setLineCap(.round)
        var lineY = x(452)
        while lineY <= x(762) {
            context.move(to: CGPoint(x: head.minX + x(26), y: lineY))
            context.addLine(to: CGPoint(x: head.maxX - x(26), y: lineY))
            lineY += x(46)
        }
        context.strokePath()
    }
    context.restoreGState()

    // Band where the head meets the stem — the detail that reads as "studio mic".
    let band = CGRect(x: x(372), y: x(340), width: x(280), height: x(44))
    context.saveGState()
    context.addPath(headPath)
    context.clip()
    context.setFillColor(CGColor(red: 0, green: 0, blue: 0, alpha: 0.22))
    context.fill(band)
    context.restoreGState()
}

func makeImage(size: CGFloat) -> CGImage {
    let pixels = Int(size)
    let context = CGContext(
        data: nil,
        width: pixels,
        height: pixels,
        bitsPerComponent: 8,
        bytesPerRow: 0,
        space: CGColorSpaceCreateDeviceRGB(),
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    )!
    draw(size: size, into: context)
    return context.makeImage()!
}

func write(_ image: CGImage, to url: URL) {
    guard let dest = CGImageDestinationCreateWithURL(url as CFURL, "public.png" as CFString, 1, nil) else {
        fatalError("could not create destination at \(url.path)")
    }
    CGImageDestinationAddImage(dest, image, nil)
    guard CGImageDestinationFinalize(dest) else { fatalError("could not write \(url.path)") }
}

// MARK: - main

let args = CommandLine.arguments
guard args.count >= 2 else {
    print("usage: swift Tools/GenerateIcon.swift <output-iconset-dir>")
    exit(1)
}
let outputDir = URL(fileURLWithPath: args[1])
try? FileManager.default.createDirectory(at: outputDir, withIntermediateDirectories: true)

// name -> pixel size, per the .iconset convention.
let variants: [(String, CGFloat)] = [
    ("icon_16x16", 16), ("icon_16x16@2x", 32),
    ("icon_32x32", 32), ("icon_32x32@2x", 64),
    ("icon_128x128", 128), ("icon_128x128@2x", 256),
    ("icon_256x256", 256), ("icon_256x256@2x", 512),
    ("icon_512x512", 512), ("icon_512x512@2x", 1024),
]

for (name, size) in variants {
    let image = makeImage(size: size)
    write(image, to: outputDir.appendingPathComponent("\(name).png"))
    print("wrote \(name).png (\(Int(size))px)")
}
print("done -> \(outputDir.path)")
