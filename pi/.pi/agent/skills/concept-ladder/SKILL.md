---
name: concept-ladder
description: Explain unfamiliar complex topics as a 3–5-rung concept ladder. Use when the user asks a broad or general conceptual question outside their apparent specialty, or explicitly asks for an ELI5-to-expert/PhD explanation.
---

# Concept Ladder

Build one mental model at increasing resolution. Each rung must remain true at its scale, prepare the next rung, and add explanatory power rather than paraphrase an earlier rung.

## Steps

1. **Set the spine.** Infer an accessible starting point from the prompt and any known user background. Identify the one question the ladder will answer, why it matters, and a running example that can survive increasing scrutiny. This step is complete when the concept has one causal spine and the example genuinely illustrates it.

2. **Build 3–5 rungs.** Always span the full ladder; add or merge middle rungs to suit the topic:
   - **ELI5:** concrete intuition in ordinary language.
   - **Beginner:** the smallest useful vocabulary and mental model.
   - **Working knowledge:** mechanism, causal flow, and a representative example.
   - **Advanced:** formalism, assumptions, trade-offs, and important edge cases.
   - **Expert/PhD:** the field's precise framing, competing models or interpretations, limits of the explanation, and live research questions where relevant.

   Define each term on first use. Carry the running example upward, showing what each new rung reveals. Use equations, notation, or code only where they increase understanding, and define every symbol. This step is complete when every rung answers the same core question at greater resolution and the final rung reaches an expert lens.

3. **Stress-test the ladder.** Check that simplified claims are refined before they become misleading, analogy boundaries are explicit, transitions explain why the next model is needed, and disputed or uncertain claims are labeled. This step is complete when no rung requires the user to unlearn a false model later.

4. **Present the lesson.** Open with a one-sentence map, then use clear level headings so the user can stop at the right depth. Close with **The through-line**: 2–4 bullets connecting the intuition, mechanism, and expert framing. Keep each rung focused; put depth into conceptual resolution rather than encyclopedic coverage.
