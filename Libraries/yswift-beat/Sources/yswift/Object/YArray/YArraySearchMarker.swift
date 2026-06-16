//
//  File.swift
//  
//
//  Created by yuki on 2023/03/15.
//

import Foundation

// TODO: remove
protocol YText_or_YArray {
    var count: Int { get }
}
extension YText: YText_or_YArray {}
extension YOpaqueArray: YText_or_YArray {}

final class YArraySearchMarker {
    var timestamp: Int
    var item: YItem?
    var index: Int
    
    private static var globalSearchMarkerTimestamp = 0
    private static let maxSearchMarker = 80

    init(item: YItem?, index: Int) {
        self.item = item
        self.index = index
        
        item?.marker = true
        
        self.timestamp = YArraySearchMarker.globalSearchMarkerTimestamp
        YArraySearchMarker.globalSearchMarkerTimestamp += 1
    }

    static func markPosition(_ markers: RefArray<YArraySearchMarker>, item: YItem, index: Int) -> YArraySearchMarker {
        if markers.count >= YArraySearchMarker.maxSearchMarker {
            // override oldest marker (we don't want to create more objects)
            let marker = markers.min(by: { $0.timestamp < $1.timestamp })!
            marker.overwrite(item, index: index)
            return marker
        } else {
            // create marker
            let pm = YArraySearchMarker(item: item, index: index)
            markers.value.append(pm)
            return pm
        }
    }
    
    /**
     * Search marker help us to find positions in the associative array faster.
     * They speed up the process of finding a position without much bookkeeping.
     * A maximum of `maxSearchMarker` objects are created.
     * This function always returns a refreshed marker (updated timestamp)
     */
    static func find(_ yarray: YOpaqueObject, index: Int) -> YArraySearchMarker? {
        guard let _ = yarray._start, let arraySearchMarkers = yarray.serchMarkers, index != 0 else {
            return nil
        }
        
        let marker: YArraySearchMarker? = arraySearchMarkers.count == 0
            ? nil
            : arraySearchMarkers.value.jsReduce{ a, b in abs(index - a.index) < abs(index - b.index) ? a : b }
        
        var item: YItem? = yarray._start
        var pindex: Int = 0
        if let marker = marker {
            item = marker.item
            pindex = marker.index
            marker.refreshTimestamp() // we used it, we might need to use it again
        }
        // iterate to right if possible
        while let uitem = item, uitem.right != nil, pindex < index {
            if !uitem.deleted && uitem.countable {
                if index < pindex + uitem.length { break }
                pindex += uitem.length
            }
            item = uitem.right as? YItem
        }
        
        // iterate to left if necessary (might be that pindex > index)
        while let uitem = item, uitem.left != nil, pindex > index {
            item = uitem.left as? YItem
            if let uitem = item, !uitem.deleted, uitem.countable {
                pindex -= uitem.length
            }
        }
        
        // we want to make sure that p can't be merged with left, because that would screw up everything
        // in that cas just return what we have (it is most likely the best marker anyway)
        // iterate to left until p can't be merged with left
        while let uitem = item, let left = uitem.left, left.id.client == uitem.id.client, left.id.clock + left.length == uitem.id.clock {
            item = left as? YItem
            if let uitem = item, !uitem.deleted && uitem.countable { pindex -= uitem.length }
        }

        guard let item = item, let lobject = item.parent?.object as? YText_or_YArray else { return nil }

        let len = lobject.count / YArraySearchMarker.maxSearchMarker
        if let marker = marker, abs(marker.index - pindex) < len {
            // adjust existing marker
            marker.overwrite(item, index: pindex)
            return marker
        } else {
            // create marker
            return YArraySearchMarker.markPosition(arraySearchMarkers, item: item, index: pindex)
        }
    }
    
    static func updateChanges(_ markers: RefArray<YArraySearchMarker>, index: Int, len: Int) {
        for i in (0..<markers.count).reversed() {
            let marker = markers[i]

            if len > 0 {
                var item = marker.item
                if let uitem = item { uitem.marker = false }
                // Ideally we just want to do a simple position comparison, but this will only work if
                // search markers don't point to deleted items for formats.
                // Iterate marker to prev undeleted countable position so we know what to do when updating a position

                while (item != nil && (item!.deleted || !item!.countable)) {
                    item = item!.left as? YItem
                    if item != nil && !item!.deleted && item!.countable {
                        // adjust position. the loop should break now
                        marker.index -= item!.length
                    }
                }
                if item == nil || item!.marker == true {
                    // remove search marker if updated position is nil or if position is already marked
                    markers.value.remove(at: i)
                    continue
                }
                marker.item = item
                item!.marker = true
            }
            if index < marker.index || (len > 0 && index == marker.index) { // a simple index <= m.index check would actually suffice
                marker.index = max(index, marker.index + len)
            }
        }
    }

    func refreshTimestamp() {
        self.timestamp = YArraySearchMarker.globalSearchMarkerTimestamp
        YArraySearchMarker.globalSearchMarkerTimestamp += 1
    }
        
    /// This is rather complex so this function is the only thing that should overwrite a marker
    func overwrite(_ item: YItem, index: Int) {
        if (self.item != nil) { self.item!.marker = false }
        self.item = item
        item.marker = true
        self.index = index
        self.timestamp = YArraySearchMarker.globalSearchMarkerTimestamp
        YArraySearchMarker.globalSearchMarkerTimestamp += 1
    }
}
