<h1 align="center">power-bi-agentic-development</h1>

<p align="center">
  A centralized marketplace for everything agentic Power BI development <br/>
  <i> Teach agents like Claude Code or GitHub Copilot to do literally anything in Power BI </i>
</p>

<p align="center">
  <img src="https://img.shields.io/badge/version-0.16.3-blue" alt="Version">
  <img src="https://img.shields.io/badge/tabular_editor-2%20%7C%203-orange" alt="Tabular Editor">
  <img src="https://img.shields.io/badge/license-GPL--3.0-green" alt="License">
</p>

> [!NOTE]
> **These skills are under active development with a daily release cadence.** Breaking changes, new additions, and restructuring may occur frequently.
>
> Please create an issue if you have any questions, issues, or just want help. I am currently on parental leave, but I will make time to help you, if you need it.

---

<p align="center">
  <img src="media/bg22-06-2.png" alt="" width="800">
</p>

## Installation

These skills are intended for use in Claude Code, Desktop, or Cowork. However, you can use them in other tools like GitHub Copilot, Codex, Gemini CLI.

### Claude Code

Enter the following commands in the terminal:

Add marketplace:
```bash
# Add marketplace source (if not already added)
claude plugin marketplace add data-goblin/power-bi-agentic-development
```

Then in Claude Code you can install the plugins via `/plugin` and navigating to the installed marketplace.

![Marketplace UI](media/marketplace-ui.png)

**TIP:** Make sure that you enable marketplace auto-update!

![Marketplace auto-update](media/marketplace-auto-update.png)

Alternative - Add plugins via command line: 

```bash
# Install plugins
claude plugin install tabular-editor@power-bi-agentic-development
claude plugin install pbi-desktop@power-bi-agentic-development
claude plugin install semantic-models@power-bi-agentic-development
claude plugin install reports@power-bi-agentic-development
claude plugin install pbip@power-bi-agentic-development
claude plugin install fabric-cli@power-bi-agentic-development
```

### GitHub Copilot

The standalone [Copilot CLI](https://docs.github.com/en/copilot/how-tos/copilot-cli) supports plugin installation from GitHub repos. Consult the Copilot documentation for specifics if you have difficulties with installation, or open an issue in this repo.

```bash
copilot plugin install data-goblin/power-bi-agentic-development
```

> **Note:** Some plugin features like agents and hooks may behave differently across tools. The core knowledge in the skill files is tool-agnostic.


## Overview

### Skills

| Skill | Plugin | Description |
|-------|--------|-------------|
| [`bpa-rules`](plugins/tabular-editor/skills/bpa-rules/) | tabular-editor | Create and improve Best Practice Analyzer rules for models |
| [`c-sharp-scripting`](plugins/tabular-editor/skills/c-sharp-scripting/) | tabular-editor | C# scripting and macros for TE |
| [`te2-cli`](plugins/tabular-editor/skills/te2-cli/) | tabular-editor | Tabular Editor 2 CLI usage and automation (not TE3) |
| [`te-docs`](plugins/tabular-editor/skills/te-docs/) | tabular-editor | Tabular Editor documentation search, TE3 config files (.tmuo, preferences). Uses [`pbi-search`](https://github.com/data-goblin/pbi-search) CLI |
| [`connect-pbid`](plugins/pbi-desktop/skills/connect-pbid/) | pbi-desktop | Explore, query, and modify a model in Power BI Desktop with only a skill |
| [`tmdl`](plugins/pbip/skills/tmdl/) | pbip | Author and edit TMDL files directly |
| [`pbip`](plugins/pbip/skills/pbip/) | pbip | Power BI Project (PBIP) format, structure, and file types |
| [`pbir-format`](plugins/pbip/skills/pbir-format/) | pbip | Author and edit PBIR metadata files directly (visual.json, report.json, themes, filters, report extensions / thin measures, visual calculations) |
| [`pbi-report-design`](plugins/reports/skills/pbi-report-design/) (Very WIP) | reports | Power BI report best practices, design and style. Very bare bones right now. |
| [`modifying-theme-json`](plugins/reports/skills/modifying-theme-json/) (WIP) | reports | Helping agents work with theme files |
| [`deneb-visuals`](plugins/reports/skills/deneb-visuals/) | reports | Deneb visuals with Vega and Vega-Lite specs |
| [`r-visuals`](plugins/reports/skills/r-visuals/) | reports | Custom R visuals in Power BI reports |
| [`python-visuals`](plugins/reports/skills/python-visuals/) | reports | Custom Python visuals in Power BI reports |
| [`svg-visuals`](plugins/reports/skills/svg-visuals/) | reports | SVG visuals via DAX measures in Power BI reports |
| [`review-report`](plugins/reports/skills/review-report/) (WIP) | reports | Review Power BI reports, focuses on usage metrics (if released) and best practices (if in dev) |
| [`pbir-cli`](plugins/reports/skills/pbir-cli/) | reports | Programmatic report manipulation via the [`pbir` CLI](https://github.com/data-goblin/pbir.tools-private-beta) (closed beta; not yet released) |
| [`standardize-naming-conventions`](plugins/semantic-models/skills/standardize-naming-conventions/) | semantic-models | Audit and standardize naming conventions in semantic models |
| [`review-semantic-model`](plugins/semantic-models/skills/review-semantic-model/) (Very WIP) | semantic-models | Review semantic models for quality, performance, AI readiness, and best practices |
| [`refreshing-semantic-model`](plugins/semantic-models/skills/refreshing-semantic-model/) | semantic-models | Trigger or troubleshoot refreshes |
| [`lineage-analysis`](plugins/semantic-models/skills/lineage-analysis/) | semantic-models | Trace downstream reports from a semantic model across workspaces |
| [`fabric-cli`](plugins/fabric-cli/skills/fabric-cli/) | fabric-cli | Fabric CLI (fab) for any remote operation in Power BI or Fabric (Fabric not required; works fully on Pro, PPU) |

### Commands

> In Claude Code, slash commands and skills have coalesced. Commands are simply more prescriptive workflows, but they take the same structure as a skill.
> Skills are not workflows nor should they be prescriptive.

| Command | Plugin | Description |
|---------|--------|-------------|
| [`/suggest-rule`](plugins/tabular-editor/commands/suggest-rule.md) | tabular-editor | Generate BPA rules from descriptions |
| [`/audit-context`](plugins/fabric-cli/commands/audit-context.md) | fabric-cli | Review project context files (CLAUDE.md, agents.md, memory files) |
| [`/migrating-fabric-trial-capacities`](plugins/fabric-cli/commands/migrating-fabric-trial-capacities.md) | fabric-cli | Migrate workspaces from trial to production capacity |

### Hooks

> Hooks run automatically to validate files after edits.

| Hook | Plugin | Trigger | Description |
|------|--------|---------|-------------|
| PBIR validation | pbip | `Write\|Edit` or `Bash` on `.Report/` `.json`/`.pbir` files | Validates PBIR structure, required fields, naming conventions, and schema URLs |
| Report binding validation | pbip | `Write\|Edit` or `Bash` on `definition.pbir` | Validates that a valid semantic model is connected to the report (byPath directory exists; byConnection model exists via `fab exists`) |
| TMDL validation | pbip | `Write\|Edit` or `Bash` on `.tmdl` files | Validates TMDL structural syntax; doesn't parse DAX/M |

> [!NOTE]
> Hook checks can be individually toggled via `plugins/pbip/hooks/config.yaml`. All checks are enabled by default. Set any check to `false` to disable it; for example, set `fab_exists: false` if you don't have the Fabric CLI installed.

### Agents

> Subagents for reviewing or providing feedback on agent (or less frequently human) work

| Agent | Plugin | Description |
|-------|--------|-------------|
| [`bpa-expression-helper`](plugins/tabular-editor/agents/bpa-expression-helper.md) | tabular-editor | Debug and improve BPA rule expressions |
| [`pbip-validator`](plugins/pbip/agents/pbip-validator.md) | pbip | Validate PBIP project structure, TMDL syntax, and PBIR schemas |
| [`query-listener`](plugins/pbi-desktop/agents/query-listener.md) | pbi-desktop | Listen to query traces from Power BI Desktop visuals in real time |
| [`semantic-model-auditor`](plugins/semantic-models/agents/semantic-model-auditor.md) | semantic-models | Audit semantic models for quality, memory, DAX, and design issues |
| [`deneb-reviewer`](plugins/reports/agents/deneb-reviewer.md) | reports | Review Deneb visual specs for Vega/Vega-Lite syntax and conventions |
| [`svg-reviewer`](plugins/reports/agents/svg-reviewer.md) | reports | Review SVG DAX measures for syntax and design quality |
| [`r-reviewer`](plugins/reports/agents/r-reviewer.md) | reports | Review R visual scripts (ggplot2) for Power BI conventions |
| [`python-reviewer`](plugins/reports/agents/python-reviewer.md) | reports | Review Python visual scripts (matplotlib/seaborn) for Power BI conventions |


## Use or re-use of these skills

These skills are intended for free community use.

You do not have the license to copy and incorporate them into your own products, trainings, courses, or tools. If you copy these skills - manually or by using an agent to rewrite them - you must include attribution and a link to this original project. That includes you, Microsoft.


<br>

---

<p align="center">
  <em>Built with assistance from <a href="https://claude.ai/claude-code">Claude Code</a>. AI-generated code has been reviewed but may contain errors. Use at your own risk.</em>
</p>

<p align="center">
  <em>Context files are human-written and revised by Claude Code after iterative use.</em>
</p>

---

<p align="center">
  <a href="https://github.com/data-goblin">Kurt Buhler</a> · <a href="https://data-goblins.com">Data Goblins</a> · part of <a href="https://tabulareditor.com">Tabular Editor</a>
</p>
