APP_NAME := CaddyApp
APP_BUNDLE_NAME := $(APP_NAME).app
APP_BUNDLE_ID := com.frankhildebrandt.CaddyApp
APP_VERSION := 0.1.0
MIN_MACOS := 14.0
BUILD_ROOT := _build
SWIFT_SCRATCH := $(BUILD_ROOT)/swiftpm
PUBLISH_DEBUG_DIR := $(BUILD_ROOT)/debug
PUBLISH_RELEASE_DIR := $(BUILD_ROOT)/release
SWIFT := swift
SWIFT_RUN := $(SWIFT) run
SWIFT_BUILD := $(SWIFT) build
SWIFT_TEST := $(SWIFT) test

.DEFAULT_GOAL := help

.PHONY: help build run release icon test clean reset fmt lint check docs docs-install docs-dev docs-build docs-preview docs-list open-package open-app

help: ## Zeigt verfuegbare Ziele
	@awk 'BEGIN {FS = ":.*## "; printf "\nTargets:\n"} /^[a-zA-Z0-9_-]+:.*## / {printf "  %-16s %s\n", $$1, $$2}' $(MAKEFILE_LIST)

build: ## Debug-Build erstellen
	$(SWIFT_BUILD) --scratch-path $(SWIFT_SCRATCH)
	./scripts/generate_app_icon.sh
	mkdir -p $(PUBLISH_DEBUG_DIR)
	./scripts/make_macos_app_bundle.sh \
		$(SWIFT_SCRATCH)/debug/$(APP_NAME) \
		$(PUBLISH_DEBUG_DIR)/$(APP_BUNDLE_NAME) \
		$(APP_NAME) \
		$(APP_BUNDLE_ID) \
		$(APP_VERSION) \
		$(MIN_MACOS)

run: ## App lokal starten
	$(SWIFT_RUN) --scratch-path $(SWIFT_SCRATCH)

release: ## Release-Build erstellen
	$(SWIFT_BUILD) --scratch-path $(SWIFT_SCRATCH) -c release
	./scripts/generate_app_icon.sh
	mkdir -p $(PUBLISH_RELEASE_DIR)
	./scripts/make_macos_app_bundle.sh \
		$(SWIFT_SCRATCH)/release/$(APP_NAME) \
		$(PUBLISH_RELEASE_DIR)/$(APP_BUNDLE_NAME) \
		$(APP_NAME) \
		$(APP_BUNDLE_ID) \
		$(APP_VERSION) \
		$(MIN_MACOS)

icon: ## App-Icon (.icns) aus SVG erzeugen
	./scripts/generate_app_icon.sh

test: ## Tests ausfuehren (falls vorhanden)
	$(SWIFT_TEST) --scratch-path $(SWIFT_SCRATCH)

clean: ## Build-Artefakte loeschen
	$(SWIFT) package clean --scratch-path $(SWIFT_SCRATCH) || true

reset: clean ## Build-Ordner komplett entfernen
	rm -rf .build $(BUILD_ROOT)

fmt: ## Swift-Formatierung (optional, falls swift-format installiert ist)
	@if command -v swift-format >/dev/null 2>&1; then \
		swift-format format -i $$(find Sources -name '*.swift'); \
	else \
		echo 'swift-format nicht installiert'; \
	fi

lint: ## Basischecks fuer Swift-Code (Build als Mindest-Lint)
	$(SWIFT_BUILD) --scratch-path $(SWIFT_SCRATCH)

check: build ## Build + Tests als Sammelziel
	$(MAKE) test

docs: docs-build ## Astro-Dokumentation bauen

docs-install: ## Doku-Abhaengigkeiten installieren
	npm --prefix docs install

docs-dev: ## Astro-Dokumentation lokal starten
	npm --prefix docs run dev

docs-build: ## Astro-Dokumentation bauen
	npm --prefix docs run build

docs-preview: ## Gebaute Astro-Dokumentation lokal previewen
	npm --prefix docs run preview

docs-list: ## Feature-Dokumente auflisten
	@find docs/features -maxdepth 1 -type f | sort

open-package: ## Package in Xcode oeffnen
	open Package.swift

open-app: build ## Gebautes Debug-.app in Finder/Launcher oeffnen
	open $(PUBLISH_DEBUG_DIR)/$(APP_BUNDLE_NAME)
