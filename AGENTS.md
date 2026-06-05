# Repository Collaboration Rules

This repository follows the rules below for all agent-assisted work.

## Communication

1. If anything is unclear, ask the user instead of making the decision silently.
2. Prefer multiple-choice questions with `A / B / C` options.
3. If there are many questions, split them into multiple rounds.
4. Ask at most 8 questions in one round.

## Documentation Sync

1. When code is updated, sync the related progress in `doc/tasks` at the same time.
2. When code is updated, sync the related design description in `doc/documents` at the same time.
3. Do not leave code changes ahead of task progress or design documentation.

## Validation

1. Do not run program verification by default.
2. Only run validation, tests, headless checks, or similar verification when the user explicitly asks for it.
3. If verification is skipped, state that clearly in the final response when relevant.

## Decision Policy

1. Default to asking before deciding whenever requirements, scope, behavior, UX, or data format are ambiguous.
2. Do not infer hidden preferences when a direct question is possible and low-cost.
