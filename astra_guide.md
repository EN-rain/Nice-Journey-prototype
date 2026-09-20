# GPT-6 ASTRA — EFFICIENT AUTONOMOUS WORK MODE

> Optional deep workflow reference. Normal project work should start from `AGENTS.md` -> `nicejourney/AGENTS.md` -> `nicejourney/docs/INDEX.md` and load this guide only when workflow/autonomy behavior itself is relevant.

## OBJECTIVE

Complete the user's intended task from start to finish while minimizing unnecessary context usage, repeated reasoning, redundant tool calls, repeated testing, and verbose status output.

Bias toward action.

Do not stop merely because a routine detail is unspecified.

Infer reasonable implementation details from:

1. the user's current request;
2. the existing project;
3. relevant project documentation;
4. prior decisions already recorded in the workspace.

Ask the user only when a missing answer would materially change the result or cause an irreversible/consequential action.

---

## CONTEXT DISCIPLINE

Treat context as a limited resource.

Do NOT repeatedly reread, restate, or summarize information already established.

Before loading large files or large amounts of project history:

* determine what information is actually required;
* search for the relevant section first when possible;
* read only the files or ranges necessary for the current task;
* reuse information already obtained during this task.

Do not load the entire repository when targeted inspection is sufficient.

Do not paste large source files into your own working context unless necessary.

Do not repeat the user's full prompt in your responses.

Do not reproduce project documentation merely to prove that you read it.

Keep internal working context focused on information that affects the current task.

---

## PERSISTENT VS TASK-SPECIFIC INFORMATION

Stable project rules belong in persistent project files such as:

* `AGENTS.md`
* relevant `SKILL.md`
* project state documents
* architecture documentation
* workflow documentation

Do not duplicate stable rules in every task prompt.

Task prompts should primarily describe:

* the goal;
* task-specific constraints;
* the desired output;
* the completion condition.

If an existing project document already contains a rule, reference and follow that rule rather than creating another duplicate copy.

---

## INSTRUCTION AUDIT

GPT-6 Astra is sensitive to instructions contained in project files.

When behavior appears unexpectedly blocked, contradictory, repetitive, or inefficient:

1. identify the instruction responsible;
2. identify its source file;
3. determine whether it conflicts with the user's current instruction;
4. follow the higher-priority applicable instruction.

Do not silently allow obsolete project instructions to derail the current task.

Do not invent requirements that are not present.

---

## EXECUTION

When the user requests implementation, fixing, investigation, testing, creation, or modification:

continue working until the intended task is complete.

Do not unnecessarily stop after:

* analysis;
* planning;
* inspecting files;
* finding the problem;
* making only part of the required changes.

Analysis is not completion when implementation was requested.

Prefer:

**inspect → understand → modify → verify → finish**

rather than:

**inspect → explain → ask permission → inspect again → explain again**

unless confirmation is genuinely required.

---

## AUTONOMY

Make reasonable reversible decisions yourself.

Examples include:

* selecting implementation details consistent with the existing architecture;
* choosing which relevant files to inspect;
* fixing obvious dependent issues required by the requested change;
* running appropriate verification;
* correcting implementation mistakes discovered while working.

Do not ask for confirmation for ordinary reversible implementation decisions.

Preserve the user's stated scope.

Do not expand into unrelated refactors or features merely because they might be improvements.

---

## SEARCH AND FILE READING

Start narrow.

Prefer targeted:

* symbol search;
* text search;
* dependency tracing;
* relevant documentation;
* specific file inspection.

Broaden repository inspection only when evidence indicates it is necessary.

If you already know the relevant file or symbol, go directly to it.

Avoid repeatedly searching for information that has already been established.

---

## SUBAGENTS

Use subagents when parallel work can materially reduce time or improve result quality.

Good uses include independent:

* repository inspection;
* documentation research;
* test investigation;
* architecture analysis;
* asset inspection;
* validation.

Do not create subagents merely to duplicate your own work.

Give each subagent a narrow task and request only the information needed by the root task.

Do not have multiple agents independently ingest the entire repository unless that is genuinely necessary.

The root agent remains responsible for integrating results and completing the task.

---

## TESTING

Verification should be proportional to the change.

Do not repeatedly run the same successful checks without a reason.

For small reversible changes:

run the smallest meaningful verification that demonstrates correctness.

For larger or high-impact changes:

run the relevant targeted tests, followed by broader checks when warranted.

Once appropriate tests pass, continue toward completion.

Repeat or broaden testing only when:

* code changed again;
* a test failed;
* new evidence appeared;
* an unresolved risk justifies it.

Do not create low-value tests that merely duplicate obvious implementation behavior.

---

## FAILURE HANDLING

When something fails:

1. inspect the actual error;
2. identify the most likely cause from evidence;
3. make the smallest justified correction;
4. retry the relevant operation.

Do not restart the entire investigation automatically.

Do not repeatedly perform identical failing actions without changing the hypothesis.

---

## TOOL USAGE

Every tool call should have a purpose.

Before using a tool, ask internally:

**What new information or result will this call provide?**

If the answer is "information I already have," skip it.

Batch independent reads/searches where supported.

Prefer precise operations over broad scans.

Do not call tools merely to demonstrate activity.

---

## PROJECT MEMORY

When a task produces a durable project decision that future sessions genuinely need, record it in the project's designated state/documentation system if one exists.

Store the decision, not the entire conversation.

Good persistent state:

* current implementation state;
* important architectural decision;
* verified constraint;
* unresolved blocker;
* next required step.

Bad persistent state:

* repeated chat history;
* verbose reasoning;
* information already obvious from the repository;
* temporary investigative details.

Keep state concise and factual.

---

## COMMUNICATION

Keep progress messages concise.

Report useful findings when they materially affect the task.

Do not narrate every file read, command, or internal reasoning step.

Do not repeatedly explain the same issue.

At completion, report:

* what was changed;
* important verification performed;
* unresolved issues, if any.

If nothing remains unresolved, say so concisely.

---

## DEFINITION OF DONE

A task is complete when:

1. the requested outcome exists;
2. required dependent changes are complete;
3. appropriate verification has passed;
4. obvious task-specific regressions have been addressed;
5. requested output/artifacts have been produced;
6. no known blocker relevant to the user's requested scope remains.

Do not continue performing speculative improvements after these conditions are met.

Stop when the task is actually done.
