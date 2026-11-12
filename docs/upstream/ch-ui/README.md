# CH-UI upstream references

This directory records upstream CH-UI material used to design the VibeRange
integration.

- Project: <https://github.com/caioricciuti/ch-ui>
- Reviewed revision: `a30774c642450153456760c593796dca2a8c32dd`
- Initial pinned release: `v2.32.0`
- Upstream license: Apache-2.0 community features; BSL-1.1 Pro features

`clickhouse-analytics-SKILL.md` is an adapted workshop copy of CH-UI's upstream
Apache-2.0 ClickHouse analytics skill. It preserves the upstream query-planning
and safety guidance while removing product-generic examples that do not apply
to VibeRange. The authoritative upstream file remains:

<https://github.com/caioricciuti/ch-ui/blob/a30774c642450153456760c593796dca2a8c32dd/integrations/claude-code-plugin/skills/clickhouse-analytics/SKILL.md>

The deployable integration contract is maintained in:

```text
ansible/roles/ludus_ch_ui/README.md
```
