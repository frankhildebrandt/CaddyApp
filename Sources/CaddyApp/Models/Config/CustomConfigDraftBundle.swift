import Foundation

struct CustomConfigDraftBundle {
    var routes: [CustomRouteDraft]
    var onDemandApps: [OnDemandAppDraft]
    var multipassServices: [MultipassServiceDraft]
    var appRepositories: [AppRepositoryDraft]

    func normalized() -> CustomConfigDraftBundle {
        CustomConfigDraftBundle(
            routes: routes.map { $0.normalized() },
            onDemandApps: onDemandApps.map { $0.normalized() },
            multipassServices: multipassServices.map { $0.normalized() },
            appRepositories: appRepositories.map { $0.normalized() }
        )
    }

    func validateRoutes() -> CustomConfigValidationError? {
        for (index, route) in routes.enumerated() {
            if route.host.isEmpty || route.upstream.isEmpty {
                return .message("Route \(index + 1): Host und Upstream dürfen nicht leer sein.")
            }
            if route.host.contains(where: \.isWhitespace) {
                return .message("Route \(index + 1): Host darf keine Leerzeichen enthalten.")
            }
            if route.upstream.contains(where: \.isWhitespace) {
                return .message("Route \(index + 1): Upstream darf keine Leerzeichen enthalten.")
            }
        }

        let duplicateHosts = Dictionary(grouping: routes.map(\.host)) { $0 }
            .filter { !$0.key.isEmpty && $0.value.count > 1 }
            .map(\.key)
            .sorted()
        if let duplicateHost = duplicateHosts.first {
            return .message("Doppelter Host in Custom Routes: \(duplicateHost)")
        }
        return nil
    }

    func validateOnDemandApps(existingRouteHosts: [String]) -> CustomConfigValidationError? {
        let routeHostSet = Set(existingRouteHosts.map { $0.lowercased() })

        for (index, app) in onDemandApps.enumerated() {
            let row = index + 1
            if app.name.isEmpty { return .message("On-Demand App \(row): Name darf nicht leer sein.") }
            if app.host.isEmpty { return .message("On-Demand App \(row): Host darf nicht leer sein.") }
            if app.unitName.isEmpty { return .message("On-Demand App \(row): Container/Pod Name darf nicht leer sein.") }
            if app.targetHost.isEmpty { return .message("On-Demand App \(row): Target Host darf nicht leer sein.") }
            if app.targetPort <= 0 || app.targetPort > 65535 { return .message("On-Demand App \(row): Target Port ist ungültig.") }
            if app.idleTimeoutSeconds < 15 { return .message("On-Demand App \(row): Idle Timeout muss mindestens 15 Sekunden sein.") }
            if app.host.contains(where: \.isWhitespace) { return .message("On-Demand App \(row): Host darf keine Leerzeichen enthalten.") }
            if app.targetHost.contains(where: \.isWhitespace) { return .message("On-Demand App \(row): Target Host darf keine Leerzeichen enthalten.") }
            if app.startMode == .runCommand && app.runArguments.isEmpty && app.runSteps.isEmpty {
                return .message("On-Demand App \(row): Run Arguments oder Run Steps dürfen im Modus 'Run Command' nicht leer sein.")
            }
            if app.runtime == .docker && app.unitKind == .pod {
                return .message("On-Demand App \(row): Docker unterstützt hier keine Pods. Bitte Container wählen oder Podman nutzen.")
            }
            if routeHostSet.contains(app.host.lowercased()) {
                return .message("On-Demand App \(row): Host kollidiert mit Custom Route: \(app.host)")
            }
        }

        let duplicateHosts = Dictionary(grouping: onDemandApps.map { $0.host.lowercased() }) { $0 }
            .filter { !$0.key.isEmpty && $0.value.count > 1 }
            .map(\.key)
            .sorted()
        if let duplicateHost = duplicateHosts.first {
            return .message("Doppelter Host in On-Demand Apps: \(duplicateHost)")
        }

        let duplicateUnits = Dictionary(grouping: onDemandApps.map { "\($0.runtime.rawValue):\($0.unitKind.rawValue):\($0.unitName.lowercased())" }) { $0 }
            .filter { !$0.key.hasSuffix(":") && $0.value.count > 1 }
            .map(\.key)
            .sorted()
        if let duplicateUnit = duplicateUnits.first {
            return .message("Doppelter Runtime/Unit-Name in On-Demand Apps: \(duplicateUnit)")
        }

        return nil
    }

    func validateMultipassServices(existingHosts: [String]) -> CustomConfigValidationError? {
        let occupiedHosts = Set(existingHosts.map { $0.lowercased() })
        for (index, service) in multipassServices.enumerated() {
            let row = index + 1
            if service.vmName.isEmpty { return .message("Multipass Service \(row): VM Name darf nicht leer sein.") }
            if service.serviceName.isEmpty { return .message("Multipass Service \(row): Service Name darf nicht leer sein.") }
            if service.host.isEmpty { return .message("Multipass Service \(row): Host darf nicht leer sein.") }
            if service.targetPort <= 0 || service.targetPort > 65535 { return .message("Multipass Service \(row): Port ist ungültig.") }
            if service.idleTimeoutSeconds < 15 { return .message("Multipass Service \(row): Idle Timeout muss mindestens 15 Sekunden sein.") }
            if service.host.contains(where: \.isWhitespace) { return .message("Multipass Service \(row): Host darf keine Leerzeichen enthalten.") }
            if occupiedHosts.contains(service.host.lowercased()) {
                return .message("Multipass Service \(row): Host kollidiert mit bestehender Route: \(service.host)")
            }
        }

        let duplicates = Dictionary(grouping: multipassServices.map { $0.host.lowercased() }) { $0 }
            .filter { !$0.key.isEmpty && $0.value.count > 1 }
            .map(\.key)
            .sorted()
        if let duplicate = duplicates.first {
            return .message("Doppelter Host in Multipass Services: \(duplicate)")
        }

        return nil
    }

    func validateRepositories() -> CustomConfigValidationError? {
        for (index, repository) in appRepositories.enumerated() {
            let row = index + 1
            if repository.name.isEmpty {
                return .message("Repository \(row): Name darf nicht leer sein.")
            }
            if repository.enabled && repository.entryURL.isEmpty {
                return .message("Repository \(row): URL darf bei aktivem Repository nicht leer sein.")
            }
            if repository.entryURL.contains(where: \.isWhitespace) {
                return .message("Repository \(row): URL darf keine Leerzeichen enthalten.")
            }
            if !repository.entryURL.isEmpty, URL(string: repository.entryURL) == nil {
                return .message("Repository \(row): Ungültige URL.")
            }
        }

        let duplicateURLs = Dictionary(grouping: appRepositories.map { $0.entryURL.lowercased() }) { $0 }
            .filter { !$0.key.isEmpty && $0.value.count > 1 }
            .map(\.key)
            .sorted()
        if let duplicateURL = duplicateURLs.first {
            return .message("Doppelte Repository-URL: \(duplicateURL)")
        }

        return nil
    }
}
