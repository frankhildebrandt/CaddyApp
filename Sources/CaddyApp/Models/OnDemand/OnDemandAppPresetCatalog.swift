import Foundation

enum OnDemandAppPresetCatalog {
    static let all: [OnDemandAppPreset] = [
        OnDemandAppPreset(
            key: "loki",
            title: "Loki",
            iconSystemName: "text.alignleft",
            summary: "Log aggregation backend (Grafana Loki) on port 3100.",
            app: OnDemandAppDraft(
                name: "Loki",
                runtime: .podman,
                unitKind: .container,
                unitName: "caddyapp-loki",
                host: "loki.localhost",
                targetPort: 3100,
                idleTimeoutSeconds: 600,
                enabled: true,
                startMode: .runCommand,
                runArguments: "run -d --name caddyapp-loki -p 3100:3100 grafana/loki:latest",
                healthPath: "/ready"
            ),
            notes: "Starts Loki on port 3100."
        ),
        OnDemandAppPreset(
            key: "grafana",
            title: "Grafana",
            iconSystemName: "chart.xyaxis.line",
            summary: "Grafana OSS dashboard UI on port 3000.",
            app: OnDemandAppDraft(
                name: "Grafana",
                runtime: .podman,
                unitKind: .container,
                unitName: "caddyapp-grafana",
                host: "grafana.localhost",
                targetPort: 3000,
                idleTimeoutSeconds: 900,
                enabled: true,
                startMode: .runCommand,
                runArguments: "run -d --name caddyapp-grafana -p 3000:3000 grafana/grafana-oss:latest",
                healthPath: "/login"
            ),
            notes: "Grafana OSS; add volumes/env vars after inserting the preset if needed."
        ),
        OnDemandAppPreset(
            key: "kimai",
            title: "Kimai",
            iconSystemName: "clock.badge.checkmark",
            summary: "Time tracking app with bundled MariaDB pod setup.",
            app: OnDemandAppDraft(
                name: "Kimai",
                runtime: .podman,
                unitKind: .pod,
                unitName: "caddyapp-kimai",
                host: "kimai.localhost",
                targetPort: 8001,
                idleTimeoutSeconds: 900,
                enabled: true,
                startMode: .runCommand,
                runArguments: "",
                runSteps: [
                    "pod create --name caddyapp-kimai -p 8001:8001",
                    "run -d --pod caddyapp-kimai --name caddyapp-kimai-db -e MARIADB_DATABASE=kimai -e MARIADB_USER=kimai -e MARIADB_PASSWORD=kimai -e MARIADB_ROOT_PASSWORD=kimai mariadb:11",
                    "run --rm --pod caddyapp-kimai --name caddyapp-kimai-db-wait mariadb:11 sh -lc 'until mariadb-admin ping -h 127.0.0.1 -u root -pkimai --silent; do sleep 2; done'",
                    "run -d --pod caddyapp-kimai --name caddyapp-kimai-app -e ADMINMAIL=admin@kimai.localhost -e ADMINPASS=kimaiadmin -e DATABASE_URL='mysql://kimai:kimai@127.0.0.1:3306/kimai?charset=utf8mb4&serverVersion=11.4.2-MariaDB' kimai/kimai2:apache"
                ],
                healthPath: "/"
            ),
            notes: "Podman preset creates a pod with Kimai + MariaDB and waits for DB readiness before app start. Default credentials are for local dev only; change env vars before productive use."
        ),
        OnDemandAppPreset(
            key: "ephe",
            title: "Ephe",
            iconSystemName: "doc.text.magnifyingglass",
            summary: "Builds and serves Ephe from source in a Node container on port 3000 (first start is slower).",
            app: OnDemandAppDraft(
                name: "Ephe",
                runtime: .podman,
                unitKind: .container,
                unitName: "caddyapp-ephe",
                host: "ephe.localhost",
                targetPort: 3000,
                idleTimeoutSeconds: 900,
                enabled: true,
                startMode: .runCommand,
                runArguments: "run -d --name caddyapp-ephe -p 3000:3000 node:22-alpine sh -lc \"apk add --no-cache git && npm i -g pnpm && if [ ! -d /opt/ephe ]; then git clone --depth=1 https://github.com/unvalley/ephe.git /opt/ephe; fi && cd /opt/ephe && pnpm install && pnpm run build && pnpm exec vite preview --host 0.0.0.0 --port 3000 --strictPort\"",
                healthPath: "/"
            ),
            notes: "No official container image detected. Preset builds/serves Ephe inside a Node container via git clone + pnpm (first startup can take longer)."
        ),
        OnDemandAppPreset(
            key: "penpot",
            title: "Penpot",
            iconSystemName: "pencil.and.ruler",
            summary: "Collaborative design platform with frontend/backend/exporter plus Postgres+Valkey on port 9001.",
            app: OnDemandAppDraft(
                name: "Penpot",
                runtime: .podman,
                unitKind: .pod,
                unitName: "caddyapp-penpot",
                host: "penpot.localhost",
                targetPort: 9001,
                idleTimeoutSeconds: 1800,
                enabled: true,
                startMode: .runCommand,
                runArguments: "",
                runSteps: [
                    "pod create --name caddyapp-penpot -p 9001:8080",
                    "run -d --pod caddyapp-penpot --name caddyapp-penpot-postgres -e POSTGRES_INITDB_ARGS=--data-checksums -e POSTGRES_DB=penpot -e POSTGRES_USER=penpot -e POSTGRES_PASSWORD=penpot -v caddyapp-penpot-postgres:/var/lib/postgresql/data:Z postgres:15",
                    "run -d --pod caddyapp-penpot --name caddyapp-penpot-valkey -e VALKEY_EXTRA_FLAGS='--maxmemory 128mb --maxmemory-policy volatile-lfu' valkey/valkey:8.1",
                    "run -d --pod caddyapp-penpot --name caddyapp-penpot-backend -e PENPOT_FLAGS='disable-email-verification disable-secure-session-cookies' -e PENPOT_SECRET_KEY='caddyapp-penpot-insecure-dev-key-change-me' -e PENPOT_PUBLIC_URI='http://penpot.localhost' -e PENPOT_DATABASE_URI='postgresql://127.0.0.1/penpot' -e PENPOT_DATABASE_USERNAME=penpot -e PENPOT_DATABASE_PASSWORD=penpot -e PENPOT_REDIS_URI='redis://127.0.0.1/0' -e PENPOT_OBJECTS_STORAGE_BACKEND=fs -e PENPOT_OBJECTS_STORAGE_FS_DIRECTORY=/opt/data/assets -e PENPOT_TELEMETRY_ENABLED=true -e PENPOT_TELEMETRY_REFERER=caddyapp -v caddyapp-penpot-assets:/opt/data/assets:Z penpotapp/backend:latest",
                    "run -d --pod caddyapp-penpot --name caddyapp-penpot-exporter -e PENPOT_SECRET_KEY='caddyapp-penpot-insecure-dev-key-change-me' -e PENPOT_PUBLIC_URI='http://127.0.0.1:8080' -e PENPOT_REDIS_URI='redis://127.0.0.1/0' penpotapp/exporter:latest",
                    "run -d --pod caddyapp-penpot --name caddyapp-penpot-frontend -e PENPOT_FLAGS='disable-email-verification disable-secure-session-cookies' -e PENPOT_HTTP_SERVER_MAX_BODY_SIZE=367001600 -e PENPOT_HTTP_SERVER_MAX_MULTIPART_BODY_SIZE=367001600 -v caddyapp-penpot-assets:/opt/data/assets:Z penpotapp/frontend:latest"
                ],
                healthPath: "/"
            ),
            notes: "Uses the official Penpot multi-service container stack translated from the upstream docker-compose to a single Podman pod (first startup can take longer)."
        )
    ]
}

