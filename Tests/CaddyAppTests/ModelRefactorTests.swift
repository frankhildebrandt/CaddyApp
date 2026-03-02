import XCTest
@testable import CaddyApp

final class ModelRefactorTests: XCTestCase {
    func testCustomConfigDraftBundleRejectsDuplicateRouteHosts() {
        let bundle = CustomConfigDraftBundle(
            routes: [
                CustomRouteDraft(host: "api.localhost", upstream: "127.0.0.1:8080"),
                CustomRouteDraft(host: "api.localhost", upstream: "127.0.0.1:8081")
            ],
            onDemandApps: [],
            multipassServices: [],
            appRepositories: []
        )

        let error = bundle.validateRoutes()
        XCTAssertNotNil(error)
        XCTAssertTrue((error?.localizedDescription ?? "").contains("Doppelter Host"))
    }

    func testOnDemandAppNormalizationTrimsAndFiltersSteps() {
        let app = OnDemandAppDraft(
            name: "  Grafana  ",
            unitName: "  grafana  ",
            host: "  grafana.localhost ",
            targetHost: " 127.0.0.1 ",
            targetPort: 3000,
            runArguments: "  run -d grafana  ",
            runSteps: ["  one  ", "  ", " two "]
        )

        let normalized = app.normalized()
        XCTAssertEqual(normalized.name, "Grafana")
        XCTAssertEqual(normalized.unitName, "grafana")
        XCTAssertEqual(normalized.host, "grafana.localhost")
        XCTAssertEqual(normalized.targetHost, "127.0.0.1")
        XCTAssertEqual(normalized.runArguments, "run -d grafana")
        XCTAssertEqual(normalized.runSteps, ["one", "two"])
    }

    func testOnDemandPresetInsertUniquifiesHost() {
        let existing = OnDemandAppDraft(
            name: "Grafana",
            unitName: "caddyapp-grafana",
            host: "grafana.localhost",
            targetPort: 3000,
            runArguments: "run"
        )
        let incoming = existing

        let uniqued = incoming.uniquedForInsert(existingApps: [existing])
        XCTAssertEqual(uniqued.host, "grafana2.localhost")
        XCTAssertEqual(uniqued.unitName, "caddyapp-grafana-2")
        XCTAssertEqual(uniqued.name, "Grafana 2")
    }

    func testMultipassDefaultForVMBuildsExpectedHost() {
        let existing = MultipassServiceDraft(vmName: "Dev VM", serviceName: "service", host: "service.dev-vm.mp.localhost", targetPort: 8080)
        let draft = MultipassServiceDraft.defaultForVM("Dev VM", existingServices: [existing])

        XCTAssertEqual(draft.vmName, "Dev VM")
        XCTAssertEqual(draft.serviceName, "service2")
        XCTAssertEqual(draft.host, "service2.dev-vm.mp.localhost")
    }

    func testProxyRouteFactoryBuildsWildcardForMultipassService() {
        let routes = ProxyRouteFactory.build(
            runtimeTargets: [],
            customRoutes: [],
            onDemandApps: [],
            multipassServices: [
                MultipassServiceDraft(
                    vmName: "vm",
                    serviceName: "svc",
                    host: "svc.vm.mp.localhost",
                    targetPort: 8080
                )
            ],
            gatewayPort: 49215
        )

        XCTAssertEqual(routes.count, 2)
        XCTAssertTrue(routes.contains { $0.host == "svc.vm.mp.localhost" })
        XCTAssertTrue(routes.contains { $0.host == "*.svc.vm.mp.localhost" })
    }

    func testDashboardWarningsBuilderIncludesInstallWarning() {
        let warnings = DashboardWarningsBuilder.build(
            caddyInstall: CaddyInstallStatus(isInstalled: false, version: nil, binaryPath: nil, suggestedInstallCommand: "brew install caddy"),
            tlsStatus: TLSStatus(
                localCARootPath: "",
                rootCertificatePresent: true,
                systemKeychainTrustStatus: .trusted,
                systemKeychainTrustDetails: "",
                caddyTrustCommand: "",
                installHint: ""
            ),
            runtimeTargets: [],
            autoSetupReport: AutoSetupReport(attempted: false, operations: [])
        )

        XCTAssertTrue(warnings.contains { $0.contains("Caddy is not installed") })
        XCTAssertTrue(warnings.contains { $0.contains("No Multipass or Podman targets discovered") })
    }

    func testOnDemandAppPresetIconFallback() {
        XCTAssertEqual(OnDemandAppPresetIcon.forKey("grafana"), "chart.xyaxis.line")
        XCTAssertEqual(OnDemandAppPresetIcon.forKey("unknown"), "shippingbox")
    }
}
