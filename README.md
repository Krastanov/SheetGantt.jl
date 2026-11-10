# SheetGantt

Render a Google Sheet as a Gantt chart. Plan rows require `Start_Date` and
`Target_Date` as ISO dates (`2025-03-12`) or year-month values (`2025-3`,
`2025-03`). Year-month values use the first day of the month. Missing or invalid
plan dates are rejected instead of silently assigning a month.

## Container

Build from the intended checkout, refreshing the base and Debian packages:

```sh
podman build --pull=always --no-cache -f Containerfile -t sheetgantt .
podman run --rm -p 8000:8000 sheetgantt
```

The image uses Julia 1.12 on Debian Trixie. Dependencies are resolved during the
build; retain the built image for reproducible deployment.

## Date parsing regression tests

```sh
julia --project=. -e 'using Pkg; Pkg.instantiate()'
julia --project=. test/date_parsing.jl
```
