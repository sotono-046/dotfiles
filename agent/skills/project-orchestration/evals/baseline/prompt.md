---
name: orchestration
description: "Three-layer multi-agent orchestration: Listener for abstract dialogue and context summarization, Assigner (coordinator) for technical task breakdown and one-to-one agent assignment, Executors for focused work. Use when handling complex, multi-step projects that need role separation, context isolation, or coordination of specialized agents (inspired by Outer/Inner Loop and coordinator patterns)."
type: orchestrator
lifecycle: active
---

# Orchestration — Three-Layer Multi-Agent Coordination

Orchestrate complex work by separating concerns into three layers to minimize context pollution, improve clarity, and enable focused execution.

**Layers:**
1. **Listener** (聞く役 / Context Gatherer): Dialogues with the user on abstract, non-technical ideas. Clarifies intent, gathers requirements, produces a clean structured summary. Inspired by Outer Loop (Grok Bot as context carrier) and understanding checks.
2. **Assigner** (振り分ける役 / Site Supervisor / Coordinator): Interprets the summary technically. Breaks work into discrete tasks. Assigns exactly one task to one specialized Executor agent. Manages dependencies, handoffs, and integration. Inspired by coordinator agents in projects.
3. **Executors** (実行役): Specialized agents that receive only the necessary context for their single task and produce deliverables + evidence.

Use when a request is multi-faceted, requires technical interpretation of vague goals, or benefits from parallel/specialized agents. Prefer this over a single monolithic agent for non-trivial projects.

## Core Workflow

1. **Engage Listener**
   - Start dialogue or create/use a Listener bot.
   - Ask clarifying questions. Summarize back in user's own words (like /in-your-own-words).
   - Produce a Context Pack: goals, success criteria, constraints, non-goals, glossary of terms, open questions, non-technical requirements.
   - Do **not** inject your own hypotheses about causes or solutions into the pack.
   - Save artifacts (e.g., CONTEXT.md, GLOSSARY.md) for handoff.

2. **Hand off to Assigner**
   - Pass the Context Pack + any relevant prior context.
   - Assigner creates technical interpretation, ADR-style decisions if needed, task breakdown.
   - Define for each task: description, inputs, expected outputs, acceptance criteria / checks, assigned Executor type, dependencies.
   - Strictness is defined by explicit checks and required artifacts, not vague instructions like "be careful".

3. **Assign and Execute**
   - Create or select specialized Executor bots/agents. One task → one agent.
   - Provide minimal, focused context only (the task brief + necessary subsets of Context Pack).
   - Executors work independently, return results + verification evidence.
   - Assigner collects, integrates, resolves conflicts, and iterates if needed.

4. **Close Loop**
   - Assigner or Listener presents final results to user, with evidence.
   - Update shared context for future sessions.

## Role Definitions and Guidelines

### Listener
- Focus: understanding, not solving.
- Techniques: restate intent, list assumptions to confirm, extract glossary, identify non-goals.
- Output format: structured Markdown Context Pack.
- Reference: Outer Loop patterns where a bot carries high-level intent to inner technical work.

### Assigner (Coordinator)
- Focus: decomposition and assignment.
- Create task list with clear boundaries.
- Prefer one-task-one-agent to isolate context and specialize.
- Use verification layers (checks that must pass before proceeding).
- Inspired by grill-with-docs style for specs before deep work.

### Executors
- Specialized by domain (e.g., researcher, coder, reviewer, documenter, tester).
- Receive precise brief only.
- Return: deliverable + evidence of checks passed.
- Do not expand scope.

## When Using Grok Bots
- Prefer long-lived bots for each role so memory persists.
- Listener bot: conversation-focused, context summarization.
- Assigner bot: coordinator that owns the project plan and task assignments.
- Executor bots: narrow purpose (update description accordingly).
- Use bot_send_prompt (async) + bot_await_turn for handoffs.
- Store shared artifacts in a common place or pass via prompts carefully.

## Common Issues
| Issue | Fix |
|-------|-----|
| Context bloat in one agent | Enforce layer separation; pass only Context Pack summaries |
| Vague "do carefully" | Require explicit acceptance criteria and evidence |
| Task scope creep | One task per agent; Assigner enforces boundaries |
| Lost intent | Listener restates and confirms before handoff |
| Hypotheses biasing agents | Exclude speculative causes from briefs |

See `references/context-pack-template.md` for the Context Pack structure and `references/role-prompts.md` for example system prompt snippets. Start with this workflow for any multi-agent orchestration request.
