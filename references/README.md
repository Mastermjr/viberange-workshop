# Optional upstream references

`references/ludus` is a Git submodule pointing to the authoritative Bad Sector
Labs Ludus GitLab repository. It exists for maintainers to inspect the exact
upstream template and schema patterns used when deriving VibeRange assets.

It is **not** required by Ludus Source installation, blueprint deployment, or
Packer builds: all derived files needed by VibeRange are checked into the main
repository. A normal Source clone may leave optional submodules uninitialized.

Maintainers who need the reference can run:

```bash
git submodule update --init references/ludus
```

The Source-owned template READMEs describe which assets are baked and which
range-specific state remains the responsibility of first-boot roles.
