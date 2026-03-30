APP_NAME := CaddyApp
APP_BUNDLE_NAME := $(APP_NAME).app
APP_BUNDLE_ID := com.frankhildebrandt.CaddyApp
APP_VERSION := 0.1.0
MIN_MACOS := 14.0
BUILD_ROOT := _build
SWIFT_SCRATCH := $(BUILD_ROOT)/swiftpm
PUBLISH_DEBUG_DIR := $(BUILD_ROOT)/debug
PUBLISH_RELEASE_DIR := $(BUILD_ROOT)/release
PUBLISH_PRODUCTION_DIR := $(BUILD_ROOT)/production
DMG_BACKGROUND_IMAGE := assets/AppIcon-preview.png
BUILD_HOME := $(abspath $(BUILD_ROOT)/home)
BUILD_CACHE_DIR := $(BUILD_HOME)/.cache
CLANG_MODULE_CACHE_DIR := $(abspath $(BUILD_ROOT)/clang-module-cache)
SWIFTPM_CACHE_DIR := $(abspath $(BUILD_ROOT)/spm-cache)
SWIFTPM_CONFIG_DIR := $(abspath $(BUILD_ROOT)/spm-config)
SWIFTPM_SECURITY_DIR := $(abspath $(BUILD_ROOT)/spm-security)
BUILD_ENV := HOME=$(BUILD_HOME) XDG_CACHE_HOME=$(BUILD_CACHE_DIR) CLANG_MODULE_CACHE_PATH=$(CLANG_MODULE_CACHE_DIR)
USER_HOME := $(shell printf '%s\n' "$$HOME")
SWIFT_PACKAGE_FLAGS := --disable-sandbox --manifest-cache local --cache-path $(SWIFTPM_CACHE_DIR) --config-path $(SWIFTPM_CONFIG_DIR) --security-path $(SWIFTPM_SECURITY_DIR) --only-use-versions-from-resolved-file
SWIFT := swift
SWIFT_RUN := $(SWIFT) run
SWIFT_BUILD := $(SWIFT) build
SWIFT_TEST := $(SWIFT) test

.DEFAULT_GOAL := help

.PHONY: help prepare-build-env prepare-swiftpm-cache build run release production dmg icon test clean reset fmt lint check docs docs-install docs-dev docs-build docs-preview docs-list open-package open-app

help: ## Zeigt verfuegbare Ziele
	@awk 'BEGIN {FS = ":.*## "; printf "\nTargets:\n"} /^[a-zA-Z0-9_-]+:.*## / {printf "  %-16s %s\n", $$1, $$2}' $(MAKEFILE_LIST)

prepare-build-env:
	mkdir -p $(BUILD_HOME) $(BUILD_CACHE_DIR) $(CLANG_MODULE_CACHE_DIR) $(SWIFTPM_CACHE_DIR) $(SWIFTPM_CONFIG_DIR) $(SWIFTPM_SECURITY_DIR)

prepare-swiftpm-cache: prepare-build-env
	@if [ -d "$(USER_HOME)/Library/Caches/org.swift.swiftpm/repositories" ] && [ -z "$$(find $(SWIFTPM_CACHE_DIR)/repositories -mindepth 1 -maxdepth 1 2>/dev/null)" ]; then \
		mkdir -p $(SWIFTPM_CACHE_DIR)/repositories; \
		cp -R "$(USER_HOME)/Library/Caches/org.swift.swiftpm/repositories/." "$(SWIFTPM_CACHE_DIR)/repositories/"; \
	fi

build: prepare-swiftpm-cache ## Debug-Build erstellen
	$(BUILD_ENV) $(SWIFT_BUILD) $(SWIFT_PACKAGE_FLAGS) --scratch-path $(SWIFT_SCRATCH)
	./scripts/generate_app_icon.sh
	mkdir -p $(PUBLISH_DEBUG_DIR)
	./scripts/make_macos_app_bundle.sh \
		$(SWIFT_SCRATCH)/debug/$(APP_NAME) \
		$(PUBLISH_DEBUG_DIR)/$(APP_BUNDLE_NAME) \
		$(APP_NAME) \
		$(APP_BUNDLE_ID) \
		$(APP_VERSION) \
		$(MIN_MACOS)

run: prepare-swiftpm-cache ## App lokal starten
	$(BUILD_ENV) $(SWIFT_RUN) $(SWIFT_PACKAGE_FLAGS) --scratch-path $(SWIFT_SCRATCH)

release: prepare-swiftpm-cache ## Release-Build erstellen
	$(BUILD_ENV) $(SWIFT_BUILD) $(SWIFT_PACKAGE_FLAGS) --scratch-path $(SWIFT_SCRATCH) -c release
	./scripts/generate_app_icon.sh
	mkdir -p $(PUBLISH_RELEASE_DIR)
	./scripts/make_macos_app_bundle.sh \
		$(SWIFT_SCRATCH)/release/$(APP_NAME) \
		$(PUBLISH_RELEASE_DIR)/$(APP_BUNDLE_NAME) \
		$(APP_NAME) \
		$(APP_BUNDLE_ID) \
		$(APP_VERSION) \
		$(MIN_MACOS)

production: prepare-swiftpm-cache ## Produktions-Build als Universal-App + ZIP erzeugen
	$(BUILD_ENV) $(SWIFT_BUILD) $(SWIFT_PACKAGE_FLAGS) --scratch-path $(SWIFT_SCRATCH) -c release --arch arm64 --arch x86_64
	./scripts/generate_app_icon.sh
	mkdir -p $(PUBLISH_PRODUCTION_DIR)
	./scripts/make_macos_app_bundle.sh \
		$(SWIFT_SCRATCH)/apple/Products/Release/$(APP_NAME) \
		$(PUBLISH_PRODUCTION_DIR)/$(APP_BUNDLE_NAME) \
		$(APP_NAME) \
		$(APP_BUNDLE_ID) \
		$(APP_VERSION) \
		$(MIN_MACOS)
	cd $(PUBLISH_PRODUCTION_DIR) && rm -f $(APP_NAME).zip && ditto -c -k --sequesterRsrc --keepParent $(APP_BUNDLE_NAME) $(APP_NAME).zip

dmg: production ## DMG mit Hintergrundbild und Programme-Link erzeugen
	./scripts/make_dmg.sh \
		$(PUBLISH_PRODUCTION_DIR)/$(APP_BUNDLE_NAME) \
		$(PUBLISH_PRODUCTION_DIR)/$(APP_NAME).dmg \
		$(APP_NAME) \
		$(DMG_BACKGROUND_IMAGE)

icon: ## App-Icon (.icns) aus SVG erzeugen
	./scripts/generate_app_icon.sh

test: prepare-swiftpm-cache ## Tests ausfuehren (falls vorhanden)
	$(BUILD_ENV) $(SWIFT_TEST) $(SWIFT_PACKAGE_FLAGS) --scratch-path $(SWIFT_SCRATCH)

clean: ## Build-Artefakte loeschen
	$(BUILD_ENV) $(SWIFT) package $(SWIFT_PACKAGE_FLAGS) clean --scratch-path $(SWIFT_SCRATCH) || true

reset: clean ## Build-Ordner komplett entfernen
	rm -rf .build $(BUILD_ROOT)

fmt: ## Swift-Formatierung (optional, falls swift-format installiert ist)
	@if command -v swift-format >/dev/null 2>&1; then \
		swift-format format -i $$(find Sources -name '*.swift'); \
	else \
		echo 'swift-format nicht installiert'; \
	fi

lint: ## Basischecks fuer Swift-Code (Build als Mindest-Lint)
	$(BUILD_ENV) $(SWIFT_BUILD) $(SWIFT_PACKAGE_FLAGS) --scratch-path $(SWIFT_SCRATCH)

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
