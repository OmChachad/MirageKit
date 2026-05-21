//
//  LoomSSHTestFixtures.swift
//  LoomTests
//
//  Created by Ethan Lipnik on 3/10/26.
//

import Foundation
@testable import Loom

enum LoomSSHTestFixtures {
    static let requiredDeviceID = UUID(
        uuidString: "AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE"
    )!

    static let trustedHostAuthority = """
    ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIBRqjbco+Jkg1Km2o4iqUmPuWlWN5amobKkRDooVuv1a ethan@Altair.local
    """

    static let untrustedHostAuthority = """
    ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIIQ5mXtYZTJBGPaR+gIzZZKr1vFf/1bXW+pTbgdOQETw ethan@Altair.local
    """

    static let rawHostKey = """
    ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIAWWCBWRRDOrWJwhhINdu5upnN0KeJgmvre1sSFvCqVv ethan@Altair.local
    """

    static let validHostCertificate = """
    ssh-ed25519-cert-v01@openssh.com AAAAIHNzaC1lZDI1NTE5LWNlcnQtdjAxQG9wZW5zc2guY29tAAAAIGwH5yobnf8sk001XtS0R8aqOB9aZP1ybc5UCiZr/9/NAAAAIAWWCBWRRDOrWJwhhINdu5upnN0KeJgmvre1sSFvCqVvAAAAAAAAAAAAAAACAAAABXZhbGlkAAAANAAAADBsb29tLWRldmljZS9hYWFhYWFhYS1iYmJiLWNjY2MtZGRkZC1lZWVlZWVlZWVlZWUAAAAAabDy1AAAAABrkNUuAAAAAAAAAAAAAAAAAAAAMwAAAAtzc2gtZWQyNTUxOQAAACAUao23KPiZINSptqOIqlJj7lpVjeWpqGypEQ6KFbr9WgAAAFMAAAALc3NoLWVkMjU1MTkAAABAvy0eq6iS0b/40hSxYYXVWN5jBryh1RYsyPB/112QHyHFEPuLouou+GA/VkylG3uZWKwaDueDFRuBQBzHi8N6Bg== ethan@Altair.local
    """

    static let wrongPrincipalHostCertificate = """
    ssh-ed25519-cert-v01@openssh.com AAAAIHNzaC1lZDI1NTE5LWNlcnQtdjAxQG9wZW5zc2guY29tAAAAIOIqKIaNBFmb07IE4mv4QeR+vxQYkDFCt1FVEa2Fnrf0AAAAIAWWCBWRRDOrWJwhhINdu5upnN0KeJgmvre1sSFvCqVvAAAAAAAAAAAAAAACAAAAD3dyb25nLXByaW5jaXBhbAAAADQAAAAwbG9vbS1kZXZpY2UvZmZmZmZmZmYtMTExMS0yMjIyLTMzMzMtNDQ0NDQ0NDQ0NDQ0AAAAAGmw8tQAAAAAa5DVLgAAAAAAAAAAAAAAAAAAADMAAAALc3NoLWVkMjU1MTkAAAAgFGqNtyj4mSDUqbajiKpSY+5aVY3lqahsqREOihW6/VoAAABTAAAAC3NzaC1lZDI1NTE5AAAAQCFsN3Imvh+jjybZbrwrYY6s8/jCGXlRWJLQHFOWnoFWW3B5V01SqAfVuHyTT2ANW3DSv/TFkQOtJM0ze7SjVQ4= ethan@Altair.local
    """

    static let criticalOptionHostCertificate = """
    ssh-ed25519-cert-v01@openssh.com AAAAIHNzaC1lZDI1NTE5LWNlcnQtdjAxQG9wZW5zc2guY29tAAAAIGC42hBNkki4+ie8tqJgTlw/AcyE7bhQuZnjCUBkEDkhAAAAIAWWCBWRRDOrWJwhhINdu5upnN0KeJgmvre1sSFvCqVvAAAAAAAAAAAAAAACAAAACGNyaXRpY2FsAAAANAAAADBsb29tLWRldmljZS9hYWFhYWFhYS1iYmJiLWNjY2MtZGRkZC1lZWVlZWVlZWVlZWUAAAAAabDy1AAAAABrkNUuAAAAIgAAAA1mb3JjZS1jb21tYW5kAAAADQAAAAkvYmluL3RydWUAAAAAAAAAAAAAADMAAAALc3NoLWVkMjU1MTkAAAAgFGqNtyj4mSDUqbajiKpSY+5aVY3lqahsqREOihW6/VoAAABTAAAAC3NzaC1lZDI1NTE5AAAAQFjdaxUk1DBg7UzJ2d5ML2+00/5tPIK8Q5I/3R3vuzKE7ZfnztDnuU2/R3jbKMUIGnHcVIUWC44OiG06EhOlHgI= ethan@Altair.local
    """

    static let expiredHostCertificate = """
    ssh-ed25519-cert-v01@openssh.com AAAAIHNzaC1lZDI1NTE5LWNlcnQtdjAxQG9wZW5zc2guY29tAAAAIPfwW/wZdtpaweY4qI5F81S+Cx8fFdWb/EX7psZD/pdRAAAAIAWWCBWRRDOrWJwhhINdu5upnN0KeJgmvre1sSFvCqVvAAAAAAAAAAAAAAACAAAAB2V4cGlyZWQAAAA0AAAAMGxvb20tZGV2aWNlL2FhYWFhYWFhLWJiYmItY2NjYy1kZGRkLWVlZWVlZWVlZWVlZQAAAABpp7iuAAAAAGmvoa4AAAAAAAAAAAAAAAAAAAAzAAAAC3NzaC1lZDI1NTE5AAAAIBRqjbco+Jkg1Km2o4iqUmPuWlWN5amobKkRDooVuv1aAAAAUwAAAAtzc2gtZWQyNTUxOQAAAEBZy5wJJC+REQd0WxssKH+oCpUSVJLAdgDlsnKHyTeaTq45WLaj0yurWHed/1PoOZzEuMiK6jWEE651wuRk/oEO ethan@Altair.local
    """

    static var serverTrustConfiguration: LoomSSHServerTrustConfiguration {
        LoomSSHServerTrustConfiguration(
            trustedHostAuthorities: [trustedHostAuthority],
            requiredPrincipal: LoomSSHServerTrustConfiguration.requiredPrincipal(for: requiredDeviceID)
        )
    }
}
