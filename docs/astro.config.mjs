import { defineConfig } from "astro/config";
import starlight from "@astrojs/starlight";

export default defineConfig({
  site: "https://frankhildebrandt.github.io",
  base: "/CaddyApp",
  integrations: [
    starlight({
      title: "CaddyApp Docs",
      description: "Dokumentation für CaddyApp auf macOS.",
      customCss: ["./src/styles/custom.css"],
      social: [
        {
          icon: "github",
          label: "GitHub",
          href: "https://github.com/frankhildebrandt/CaddyApp"
        }
      ],
      sidebar: [
        {
          label: "Einführung",
          items: [
            { label: "Überblick", link: "/" },
            { label: "Erste Schritte", slug: "guides/getting-started" },
            { label: "Feature-Überblick", slug: "guides/features" }
          ]
        },
        {
          label: "Guides",
          items: [
            { label: "Routing und Caddy", slug: "guides/routing-and-caddy" },
            { label: "Service Discovery", slug: "guides/service-discovery" },
            { label: "Multipass-VMs", slug: "guides/multipass" },
            { label: "On-Demand-Apps", slug: "guides/on-demand-apps" }
          ]
        },
        {
          label: "Referenz",
          items: [
            { label: "YAML-Dateien und Feeds", slug: "reference/yaml-files-and-feeds" },
            { label: "Support und Monitoring", slug: "reference/support-and-monitoring" }
          ]
        }
      ]
    })
  ]
});
