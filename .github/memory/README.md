# Development Memory System

This directory provides a lightweight memory system for development work in this repository.

## Purpose

Track patterns, decisions, and lessons learned while building, testing, linting, and debugging. The goal is to improve consistency over time and reduce repeated investigation.

## Two Types of Memory

1. Persistent memory: `.github/copilot-instructions.md`

- Long-lived principles, repo-level standards, and baseline workflows.
- Changes are infrequent and intentional.

1. Working memory: `.github/memory/`

- Day-to-day discoveries and implementation learnings.
- Updated as work progresses.

## Directory Structure

- `session-notes.md`
- Historical summaries of completed work sessions.
- Committed to git.

- `patterns-discovered.md`
- Accumulated coding and architecture patterns found in this repo.
- Committed to git.

- `scratch/working-notes.md`
- Active session notebook for in-progress tasks.
- Not committed to git.

- `scratch/.gitignore`
- Ignores all scratch content to keep active notes ephemeral.

## When To Use Each File

### During TDD

Use `scratch/working-notes.md` to track:

- Current failing test and expected behavior.
- Hypotheses for implementation changes.
- Quick notes on red-green-refactor iterations.

When the session ends:

- Move durable findings to `session-notes.md`.
- Add recurring test or implementation patterns to `patterns-discovered.md`.

### During Linting

Use `scratch/working-notes.md` to track:

- Lint failures encountered.
- Rule interpretation decisions.
- One-off command results.

When the session ends:

- Record stable linting conventions and preferred fixes in `patterns-discovered.md`.
- Summarize major lint cleanup outcomes in `session-notes.md`.

### During Debugging

Use `scratch/working-notes.md` to track:

- Reproduction steps.
- Logs, assumptions, and eliminated causes.
- Temporary mitigation options.

When the session ends:

- Document root cause and final fix in `session-notes.md`.
- Add reusable debugging heuristics to `patterns-discovered.md`.

## How AI Uses This Memory

- Reads persistent principles from `.github/copilot-instructions.md` first.
- Reads historical outcomes from `session-notes.md` to avoid repeating dead ends.
- Reads reusable patterns from `patterns-discovered.md` to suggest consistent solutions.
- Uses `scratch/working-notes.md` as current context during active implementation.

## Commit Policy

- `session-notes.md` is for completed session summaries and is committed.
- `scratch/working-notes.md` is for active work and is not committed.

This split keeps ongoing notes flexible while preserving useful historical learnings.
