---
name: clickhouse-analytics
source: https://github.com/caioricciuti/ch-ui/blob/a30774c642450153456760c593796dca2a8c32dd/integrations/claude-code-plugin/skills/clickhouse-analytics/SKILL.md
license: Apache-2.0
---

# ClickHouse analytics through CH-UI

The `ch-ui` MCP server exposes one ClickHouse connection with read-only
tools. Every query runs with `readonly=2`, a row cap and a 60 second limit,
and is recorded in CH-UI's query history. You cannot break anything, but you
can waste time on full scans. Plan first.

## The loop

1. **Find the data.** `search_catalog` with a short term from the question
   (`orders`, `latency`, `signup`). It returns tables, columns, saved queries
   and dashboards. If a **verified** saved query matches the question, run it
   with `run_saved_query` and stop.
2. **Understand the table.** `describe_table` before writing SQL. Read the
   `sorting_key` and `partition_key` in `table_info`, the `sample_rows`, and
   `storage.rows`. Filter on the sorting key whenever you can; it is the
   only index ClickHouse has by default.
3. **Size the query.** On tables above ~10M rows call `estimate_query` with
   the SELECT. If `total_rows` is large, tighten the WHERE clause, then run
   with `max_bytes` set to roughly twice the estimate's bytes as a safety
   budget.
4. **Run.** `run_select` with an explicit `LIMIT` and only the columns you
   need. Use `format: "csv"` for wide results. `truncated: true` means the
   answer is incomplete: aggregate or filter instead of asking for more rows.
5. **Check the plan** if a query is slow: `explain_query` shows whether the
   primary key or a skip index was used.

Never page through raw rows to compute something ClickHouse can aggregate.

## ClickHouse SQL that models get wrong

- Time bucketing: `toStartOfHour(ts)`, `toStartOfDay(ts)`, `toDate(ts)`.
- Distinct counts: `uniq(x)` (approximate, fast) or `uniqExact(x)`.
- Percentiles: `quantile(0.95)(latency_ms)`, `quantiles(0.5, 0.95)(x)`.
- Conditional aggregates: `countIf(cond)`, `sumIf(v, cond)`, `avgIf(v, cond)`.
- Strings and numbers do not coerce; cast explicitly.
- Dates: `today()`, `now()`, `now() - INTERVAL 7 DAY`.
- Arrays: `arrayJoin(arr)`, `has(arr, x)`, `length(arr)`.
- `LIMIT n BY key` gives the top n per group without a window function.
- Use `FINAL` carefully on replacing/collapsing tables; it is expensive.
- Identifiers with unusual characters need backticks.
- Do not add a `FORMAT` clause when an API tool selects the response format.

## Reading tool output

- Treat `describe_table.table_info.create_table_query` as the source of truth
  for engine, keys, and TTL.
- A large difference between rows read and rows returned means the query needs
  a sorting-key or time filter.
- Prefer verified saved queries when one answers the question.

## Creating things

With a write-scope key, CH-UI can create draft saved queries and dashboards.
Ask before creating anything that was not requested, and report exactly what
was created and where it can be reviewed.
