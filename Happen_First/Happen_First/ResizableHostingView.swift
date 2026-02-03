//
//  ResizableHostingView.swift
//  Happen_First
//
//  Created by Vanessaw on 1/2/2026.
//

import Cocoa
import SwiftUI
/// A non-generic NSHostingView wrapper that supports:
/// - Dragging the whole window by dragging background area
/// - Resizing from any of the four corners by dragging the corners
final class ResizableHostingView: NSHostingView<AnyView> {
    // corner hit area in points
    private let cornerSize: CGFloat = 16.0
    // minimum window size
    private let minSize = CGSize(width: 300, height: 120)
    // state for ongoing gesture
    private enum DragMode {
        case none
        case move(initialLocation: NSPoint, initialWindowFrame: NSRect)
        case resize(corner: Corner, initialLocation: NSPoint, initialWindowFrame: NSRect)
    }
    private enum Corner {
        case topLeft, topRight, bottomLeft, bottomRight
    }
    private var dragMode: DragMode = .none
    // Allow clicks even if the window is not key
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { return true }
    // detect whether the point is in a corner region (in view coords)
    private func cornerHit(at point: NSPoint) -> Corner? {
        let bounds = self.bounds
        // convert point is already in view coords for local events
        let tlRect = NSRect(x: bounds.minX, y: bounds.maxY - cornerSize, width: cornerSize, height: cornerSize)
        let trRect = NSRect(x: bounds.maxX - cornerSize, y: bounds.maxY - cornerSize, width: cornerSize, height: cornerSize)
        let blRect = NSRect(x: bounds.minX, y: bounds.minY, width: cornerSize, height: cornerSize)
        let brRect = NSRect(x: bounds.maxX - cornerSize, y: bounds.minY, width: cornerSize, height: cornerSize)
        if tlRect.contains(point) { return .topLeft }
        if trRect.contains(point) { return .topRight }
        if blRect.contains(point) { return .bottomLeft }
        if brRect.contains(point) { return .bottomRight }
        return nil
    }
    // Helper to convert NSEvent location to view coords
    private func locationInView(from event: NSEvent) -> NSPoint {
        guard self.window != nil else { return NSPoint.zero }
        let locWin = event.locationInWindow
        return self.convert(locWin, from: nil)
    }
    
    // Mouse down: decide move vs resize
    override func mouseDown(with event: NSEvent) {
        guard let window = self.window else { return }
        let locInView = locationInView(from: event)
        let locInWindow = event.locationInWindow
        let winFrame = window.frame
        if let corner = cornerHit(at: locInView) {
            dragMode = .resize(corner: corner, initialLocation: locInWindow, initialWindowFrame: winFrame)
        } else {
            // only start move if left mouse
            dragMode = .move(initialLocation: locInWindow, initialWindowFrame: winFrame)
        }
    }
    override func mouseDragged(with event: NSEvent) {
        guard let window = self.window else { return }
        let locInWindow = event.locationInWindow
        switch dragMode {
        case .none:
            return
        case .move(let initialLocation, let initialWindowFrame):
            let dx = locInWindow.x - initialLocation.x
            let dy = locInWindow.y - initialLocation.y
            var newFrame = initialWindowFrame
            newFrame.origin.x += dx
            newFrame.origin.y += dy
            // move immediately
            window.setFrame(newFrame, display: true, animate: false)
        case .resize(let corner, let initialLocation, let initialWindowFrame):
            // compute delta in window coordinates
            let dx = locInWindow.x - initialLocation.x
            let dy = locInWindow.y - initialLocation.y
            var newFrame = initialWindowFrame
            switch corner {
            case .topRight:
                newFrame.size.width  += dx
                newFrame.size.height += dy
            case .topLeft:
                newFrame.origin.x += dx
                newFrame.size.width  -= dx
                newFrame.size.height += dy
            case .bottomRight:
                newFrame.origin.y += dy
                newFrame.size.height -= dy
                newFrame.size.width  += dx
            case .bottomLeft:
                newFrame.origin.x += dx
                newFrame.size.width  -= dx
                newFrame.origin.y += dy
                newFrame.size.height -= dy
            }
            // Enforce min size
            if newFrame.size.width < minSize.width {
                // adjust origin when shrinking from left corners
                let diff = minSize.width - newFrame.size.width
                if corner == .topLeft || corner == .bottomLeft {
                    newFrame.origin.x -= diff
                }
                newFrame.size.width = minSize.width
            }
            if newFrame.size.height < minSize.height {
                let diff = minSize.height - newFrame.size.height
                if corner == .bottomLeft || corner == .bottomRight {
                    newFrame.origin.y -= diff
                }
                newFrame.size.height = minSize.height
            }
            // Apply immediately without animation
            window.setFrame(newFrame, display: true, animate: false)
        }
    }
    override func mouseUp(with event: NSEvent) {
        dragMode = .none
    }
    // Update cursor when moving over corners to show resize affordance
    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        // remove existing tracking areas and add a general one to receive mouseEntered/Exited/Moved
        trackingAreas.forEach { self.removeTrackingArea($0) }
        let options: NSTrackingArea.Options = [.mouseMoved, .activeInKeyWindow, .inVisibleRect]
        let area = NSTrackingArea(rect: self.bounds, options: options, owner: self, userInfo: nil)
        self.addTrackingArea(area)
    }
    override func mouseMoved(with event: NSEvent) {
        let loc = locationInView(from: event)
        if let corner = cornerHit(at: loc) {
            switch corner {
            case .topLeft:
                // use frameResize for corner cursors
                NSCursor.frameResize(position: .topLeft, directions: .all).set()
            case .topRight:
                NSCursor.frameResize(position: .topRight, directions: .all).set()
            case .bottomLeft:
                NSCursor.frameResize(position: .bottomLeft, directions: .all).set()
            case .bottomRight:
                NSCursor.frameResize(position: .bottomRight, directions: .all).set()
            }
        } else {
            // if not over a corner, show default arrow
            NSCursor.arrow.set()
        }
    }
}


