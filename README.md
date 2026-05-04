# risk

A compiled, statically typed programming language.

> Linux x86_64 only for now. Windows and ARM coming later.

## Install

```bash
curl -fsSL https://raw.githubusercontent.com/hesed-charis175/risk-releases/main/install.sh | bash
```

This installs `riskc` to `/usr/local/bin` and the standard library to `~/.risk/lib`.

## Usage

```bash
riskc path/to/file.risk
```

## Docs

[hesed-charis175.github.io/risk-releases](https://hesed-charis175.github.io/risk-releases)

## Standard library

The stdlib is installed automatically. Modules live in `~/.risk/lib`.

| Module | Description |
|--------|-------------|
| `tui`  | Terminal UI utilities |

## Releases

See [Releases](https://github.com/hesed-charis175/risk-releases/releases) for changelogs and binary downloads.
