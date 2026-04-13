---
name: prd-writer
description: Write Product Requirements Documents (PRDs) with a minimalistic structure. Use when asked to create a PRD, product spec, feature spec, requirements document, or product proposal. Scales from small features to large initiatives.
---

# PRD Writer

Create concise, actionable PRDs. The structure scales naturally (small features need brief sections, large initiatives need more detail).

## Template

```markdown
# [Feature/Product Name]

## Outcome
What success looks like. One or two sentences describing the measurable result.

## Problem Statement
The user pain or business problem being solved. Be specific about who experiences this and when.

## Out of Scope
What this PRD explicitly does NOT cover. List anything that might reasonably be assumed in scope but isn't. This prevents scope creep and clarifies boundaries.

## Use Cases

### [Use Case 1 Title]
**Actor:** [Who]
**Scenario:** [Brief description of what they're trying to do and how the feature helps]

### [Use Case 2 Title]
...

## Open Questions
Unresolved decisions, unknowns, or items needing stakeholder input. Number them for easy reference in discussions.

1. [Question about X]
2. [Question about Y]
```

## Writing Guidelines

- **Outcome**: Lead with the metric or observable change. Avoid vague statements like "improve user experience."
- **Problem Statement**: Include the "so what" (why this matters now, what happens if we don't solve it).
- **Out of Scope**: Be explicit. "Admin features" is better than omitting the section.
- **Use Cases**: Focus on the primary 2-4 scenarios. Each should be distinct (not variations of the same flow).
- **Open Questions**: Flag blocking decisions early. Include who might answer them if known.

## Scaling Guidance

**Small feature** (1-2 week effort): Each section can be 1-3 sentences. Use Cases might be just 1-2.

**Medium feature** (1-2 sprints): Expand Problem Statement with context. 3-4 Use Cases typical.

**Large initiative** (quarter+): Consider splitting into multiple PRDs. This template is the "overview PRD" linking to detailed specs.

## Top Insights

### From Bill Carr

*Bill Carr*

> "Whenever we're devising a new product or feature, we're going to start by writing a press release describing the feature and describing it in a way that speaks to the customer and to some degree the external press and world where the idea is, in my description of this, it better jump off the page..."

**Key insight:** The PR/FAQ process forces clarity on the customer benefit before any development begins.

**Apply this by:**

- Write a mock press release (PR) and a list of frequently asked questions (FAQ) before building
- Use the PR to describe the customer, the problem, and the solution in factual, data-rich language
- Include a hypothetical launch date to signal the project's complexity

### From Hamel Husain & Shreya Shankar

*Hamel Husain & Shreya Shankar*

> "This is the purest sense of what a product requirements document should be, is this eval judge that's telling you exactly what it should be, and it's automatic and running constantly."

**Key insight:** In AI development, executable evaluations are replacing static PRDs as the definitive source of product requirements.

**Apply this by:**

- Translate product requirements into specific LLM-as-a-judge prompts
- Use evals to define non-negotiable product behaviors

### From Vikrama Dhiman

*Vikrama Dhiman*

> "Is your PRD quality good enough? Are you writing that the draft notes that go and circulate to the care teams, to the marketing teams and so on? ... You must have that impact to impact through the artifacts that you work on."

**Key insight:** The quality of written artifacts like PRDs is a primary way to demonstrate your 'impact on impact' and professional craft.

**Apply this by:**

- Ensure PRDs are high-quality and circulate them to cross-functional teams like care and marketing
- Don't neglect the 'IC roots' of document creation even as you move into leadership

### From Aparna Chennapragada

*Aparna Chennapragada*

> "In this day and age, if you're not prototyping and building to see what you want to build, I think you're doing it wrong. I call it the prompt sets of the new PRDs. I really insist on folks saying if you're building new projects, new features of course come with prototypes and prompt sets."

**Key insight:** Traditional written requirements are being replaced by functional prototypes and prompt sets as the primary way to define and communicate product ideas.

**Apply this by:**

- Use 'demos before memos' to accelerate the product building loop
- Include prompt sets as a core requirement for new AI features
- Prioritize high-bandwidth prototyping to visualize ideas before writing documentation

### From Claire Vo

*Claire Vo*

> "I had used ChatGPT and a prompt to come up with a very serviceable PRD spec for this very technical product... I eventually ran into the monetization and access wall that is the GPT Store right now. And so... I thought, this is easy. We're just going to stand up a standalone app."

**Key insight:** AI can drastically accelerate the drafting of product requirements, allowing PMs to focus on high-level strategy and narrative.

**Apply this by:**

- Use AI to scaffold the basics of user stories and out-of-scope items
- Include a 'narrative' section in PRDs to pitch the product's value
- Customize AI prompts to learn from your specific company context and role
