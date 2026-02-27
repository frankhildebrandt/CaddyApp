# CaddyApp Repository Feed

This folder is published via GitHub Pages and contains YAML indexes for custom app repositories.

- Repository index: `repositories.yaml`
- App index: `apps/index.yaml`
- App definitions: `apps/*.yaml`

## On-Demand App Spec Notes

- `spec.startMode: run_command` supports two input styles:
  - `runArguments`: single runtime command argument string.
  - `runSteps`: ordered list of runtime command argument strings (preferred for multi-step pod/container setup).
- Multi-step setups should use `runSteps` instead of chaining everything into one command with `&&`.
