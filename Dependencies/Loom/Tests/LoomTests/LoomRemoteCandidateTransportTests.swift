//
//  LoomRemoteCandidateTransportTests.swift
//  Loom
//
//  Created by Ethan Lipnik on 3/9/26.
//

@testable import Loom
import Foundation
import Testing

@Suite("Loom Remote Candidate Transport")
struct LoomRemoteCandidateTransportTests {
    @Test("TCP remote candidates round-trip through codable")
    func tcpCandidateRoundTrips() throws {
        let candidate = LoomRemoteCandidate(
            transport: .tcp,
            address: "203.0.113.10",
            port: 22
        )

        let encoded = try JSONEncoder().encode(candidate)
        let decoded = try JSONDecoder().decode(LoomRemoteCandidate.self, from: encoded)

        #expect(decoded == candidate)
    }

    @Test("Direct candidate collector honors explicit listening TCP port overrides")
    func collectorUsesListeningPortOverrides() async {
        let configuration = LoomNetworkConfiguration(
            controlPort: 0,
            enabledDirectTransports: [.tcp]
        )

        let candidates = await LoomDirectCandidateCollector.collect(
            configuration: configuration,
            listeningPorts: [.tcp: 2022],
            publicHostForTCP: "relay.example.com"
        )

        #expect(
            candidates == [
                LoomRemoteCandidate(
                    transport: .tcp,
                    address: "relay.example.com",
                    port: 2022
                )
            ]
        )
    }
}
