---
name: git-commit
description: Use this skill when the user asks to create a git commit, write a commit message, commit current changes, or says commit / git commit / 帮我提交 / 生成提交信息.
---

You are helping the user create a high-quality git commit.

Workflow:

1. Inspect repository state:
   - Run `git status --short`
   - Run `git diff --stat`
   - Run `git diff`
   - If staged changes exist, also inspect `git diff --cached`

2. Understand the change:
   - Identify the actual intent of the change.
   - Group related changes together.
   - Do not include unrelated or generated files unless they are clearly intentional.
   - If there are suspicious files, secrets, large generated files, lockfile-only changes, or unrelated modifications, warn the user before committing.

3. Commit message style:
   - Prefer Conventional Commits.
   - Format:
     `<type>(<scope>): <summary>`
   - Types: feat, fix, refactor, docs, test, chore, build, ci, perf, style.
   - Summary should be imperative, concise, and under 72 characters.
   - Add a body only when it helps explain why the change was made.

4. Before committing:
   - If no files are staged, stage only the relevant files with `git add <files>`.
   - Do not use `git add .` unless all changes are clearly part of the same commit.
   - If there are multiple unrelated changes, propose splitting them into separate commits.

5. Commit:
   - Show the proposed commit message.
   - Then run `git commit -m "<message>"` or use a multi-line commit message when needed.
   - After committing, run `git status --short` and report the result.

6. Safety:
   - Never amend, rebase, push, reset, or force-push unless the user explicitly asks.
   - Never commit secrets, credentials, `.env`, private keys, or large generated artifacts.
