# AI usage disclosure

AI assistants were used as helper tools. All commands were executed by me on my own machine, and every claim in the reports is backed by real output in `outputs/` and `awr/`.

## Tools
- Claude (Anthropic, via Claude Code / claude.ai): main assistant.
- DeepSeek: I used it for validation of certain queries and scripts.

## Where AI helped most
- AWR analysis (Part 2): explaining report sections (Load Profile, Top Foreground Events, SQL ordered by Elapsed Time, ADDM), helping to narrow down the two main problems, and proposing fixes. I ran every query and checked the findings against the AWR files.
- Scripts and queries: drafting SQL/bash (security checks, schema scripts, evidence queries, cleanup and fix scripts) and explaining each line before I ran it. I reviewed and ran them myself; `scripts/snapshot_at.sh` was written by me.
- Research: search phrases were proposed and run with AI assistance; I opened and read the cited pages and checked the conclusions against the lab output (see `docs/sources.md`).
- Documentation: help structuring the markdown reports; I verified the numbers against `outputs/`.

## Where I did the work myself
- Installation and setup: WSL, Docker, containers, folder and git setup, and running all commands. AI explained steps when I asked; I executed them.
- Running the workload and taking snapshots, including timing and debugging.
- Basic scripts and everyday tasks around the workload.

## What I verified and where AI was wrong or incomplete
- AI first suggested an index on CDR_USAGE; I pointed out that the project spec forbids indexes other than the SUBSCRIBER primary key. We kept the index only as a recommendation and applied a different fix.
- ADDM and AI both suggested a sequence problem; the evidence (cache size 1000, 0.3% wait) did not support it, so it was rejected.
- AI called the problem table SUBSCRIBER at one point; the query output showed CDR_USAGE.
- AI-provided awrrpt inputs were wrong for PDB-level reports (missing the AWR_PDB prompt) and the helper function `sqlsrc` was not available inside a script; both caused failures that I documented in `docs/unexpected_events.md`.
- AI claims about the free edition CPU limit (resmgr:cpu quantum) are marked as a hypothesis, not verified.

## Limits
- No password or secret was shared with AI; credentials stay in `.env`, which is not in the repository.
- Final conclusions and the presentation reasoning are mine and are based on the lab output.
