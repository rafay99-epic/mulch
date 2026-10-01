#!/usr/bin/env swift
// Renders the 1024px app icon: a leaf on a black squircle, green for Stable and
// orange for Dev so the two builds stay apart.
// usage: swift MakeIcon.swift <out.png> [stable|dev]

import AppKit

guard CommandLine.arguments.count >= 2 else {
    FileHandle.standardError.write(Data("usage: MakeIcon.swift <out.png> [stable|dev]\n".utf8))
    exit(1)
}

let leafColor: NSColor = CommandLine.arguments.dropFirst(2).first == "dev" ? .systemOrange : .systemGreen

let size = 1024.0
let image = NSImage(size: NSSize(width: size, height: size))
image.lockFocus()

let inset = size * 0.094
let plate = NSRect(x: inset, y: inset, width: size - inset * 2, height: size - inset * 2)
let squircle = NSBezierPath(roundedRect: plate, xRadius: plate.width * 0.225, yRadius: plate.height * 0.225)
NSColor.black.setFill()
squircle.fill()
NSColor.white.withAlphaComponent(0.14).setStroke()
squircle.lineWidth = size * 0.006
squircle.stroke()

let config = NSImage.SymbolConfiguration(pointSize: size * 0.42, weight: .medium)
    .applying(NSImage.SymbolConfiguration(paletteColors: [leafColor]))
if let leaf = NSImage(systemSymbolName: "leaf.fill", accessibilityDescription: nil)?.withSymbolConfiguration(config) {
    let leafSize = leaf.size
    leaf.draw(in: NSRect(
        x: plate.midX - leafSize.width / 2, y: plate.midY - leafSize.height / 2,
        width: leafSize.width, height: leafSize.height
    ))
}

image.unlockFocus()

guard let tiff = image.tiffRepresentation,
      let png = NSBitmapImageRep(data: tiff)?.representation(using: .png, properties: [:]) else { exit(1) }
try png.write(to: URL(filePath: CommandLine.arguments[1]))
