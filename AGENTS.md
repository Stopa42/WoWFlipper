# Agent Working Agreement

These instructions define default engineering behavior for changes in this repository.

## Branching
- Create a dedicated branch for each non-trivial change.
- Keep `main` clean and use branch names that reflect the change intent.

## Delivery Style
- Work in small, incremental steps that keep the codebase continuously functional.
- Commit frequently in meaningful functioning chunks, each commit should be a working codebase
- Favor CI/CD-friendly changes: each increment should be independently understandable and safe to validate.

## Testing Workflow
- Prefer test-driven development when practical:
  1. Add or update a failing test first.
  2. Implement the smallest change to make it pass.
  3. Run relevant tests after each increment.
- If tests cannot be run locally, still provide the failing test first and clearly state what to run.
- For behavior changes, add or update tests unless there is a clear reason not to.

## Code Quality Principles
- Apply Clean Code practices:
  - Meaningful names, small focused units, low duplication, explicit intent.
  - Avoid unnecessary complexity.
- Apply SOLID where it improves maintainability.
- Prefer KISS over cleverness.

## Consistency
- Match existing repository conventions for structure, style, naming, comments, and error handling.
- Keep comments concise and useful; avoid noisy or redundant comments.
- Prefer consistency with nearby code over introducing a new style.

## Decision Rules
- When tradeoffs exist, choose the option that improves readability, testability, and long-term maintainability.
- If a requested change conflicts with these defaults, follow the user request and call out the tradeoff briefly.
- If you are not sure about some business decision, ask me

## Agile manifesto
The Agile manifesto is very important for deciding how to work. Here it is in full:

We are uncovering better ways of developing
software by doing it and helping others do it.
Through this work we have come to value:

**Individuals and interactions** over processes and tools
**Working software** over comprehensive documentation
**Customer collaboration** over contract negotiation
**Responding to change** over following a plan

That is, while there is value in the items on
the right, we value the items on the left more.

We follow these principles:

Our highest priority is to satisfy the customer
through early and continuous delivery
of valuable software.

Welcome changing requirements, even late in
development. Agile processes harness change for
the customer's competitive advantage.

Deliver working software frequently, from a
couple of weeks to a couple of months, with a
preference to the shorter timescale.

Business people and developers must work
together daily throughout the project.

Build projects around motivated individuals.
Give them the environment and support they need,
and trust them to get the job done.

The most efficient and effective method of
conveying information to and within a development
team is face-to-face conversation.

Working software is the primary measure of progress.

Agile processes promote sustainable development.
The sponsors, developers, and users should be able
to maintain a constant pace indefinitely.

Continuous attention to technical excellence
and good design enhances agility.

Simplicity--the art of maximizing the amount
of work not done--is essential.

The best architectures, requirements, and designs
emerge from self-organizing teams.

At regular intervals, the team reflects on how
to become more effective, then tunes and adjusts
its behavior accordingly.