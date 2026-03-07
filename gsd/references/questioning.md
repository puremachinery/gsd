# Questioning

Use this guide when turning a vague project idea into a concrete planning brief.

## Goals

- turn fuzzy language into testable requirements
- identify the real user and workflow
- surface constraints before planning starts
- make scope and exclusions explicit
- get to a point where `PROJECT.md` can be written confidently

## Techniques

### Challenge vagueness

Ask what a broad phrase means in practice.

Examples:
- "simple" -> what is the smallest useful version?
- "fast" -> what response time or workflow matters?
- "team support" -> what roles, permissions, or collaboration behavior?

### Make abstract concrete

Push toward examples, inputs, outputs, and observable behaviors.

Examples:
- What does the user type, click, or see?
- What data exists before the action?
- What changes after success?

### Surface assumptions

Call out hidden choices so they become explicit decisions.

Look for assumptions about:
- user type
- platform
- persistence and storage
- online vs offline behavior
- integrations
- scale
- security/privacy expectations

### Find the edges

Define what is intentionally out of scope for v1.

Useful prompts:
- What is deliberately excluded?
- What would be nice later but not now?
- What failure modes are acceptable in v1?

### Reveal motivation

Understand why this project matters.

Ask about:
- the original problem or frustration
- what success looks like
- what would make the project feel worthwhile

## Context Checklist

Before you stop questioning, make sure you can answer:

- What is being built?
- Who is it for?
- What core value must work?
- What are the critical workflows?
- What data or state must exist?
- What constraints shape the solution?
- What is explicitly out of scope?
- What decisions are already made?
- What unknowns still matter?

## Stop Condition

You have enough context when you can write a `PROJECT.md` that includes:

- the project definition
- the user and problem
- the core value
- the key constraints
- the v1 scope
- the out-of-scope list
- the initial decisions
