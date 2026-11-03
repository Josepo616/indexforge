//
//  Instrumentation.swift
//  Rastro
//
//  Created by JoseAlvarez on 9/10/26.
//


import OSLog

/// Signposts show up as named intervals in Instruments' os_signpost track,
/// which is what makes a live profiling demo readable.
nonisolated enum Instrumentation {

    static let subsystem = "com.ravn.Rastro"

    static let indexing = OSSignposter(
        subsystem: subsystem,
        category: "Indexing"
    )

    static let searching = OSSignposter(
        subsystem: subsystem,
        category: "Searching"
    )

    static let logger = Logger(subsystem: subsystem, category: "Rastro")
}