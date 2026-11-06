---
name: design-eval
description: "Use before the first prompt of any build that depends on a model's reading or judgement (extraction, classification, summarisation, scoring, agents), and again when a change touches what a model is told, its output schema or how its output is scored. Defines the evaluation first: definitions that match the labels, the product's own labels, a sized development set and a pinned holdout, an error taxonomy, a pre-registered headline, run records and a stopping rule. Produces docs/EVAL.md; no prompt is written before it exists."
---

# Design the evaluation before the prompt

Why this exists: on one extraction product, the evaluation was designed after the prompt. It scored the model's own definitions against labels that asked different questions, at a sample size that could not resolve a 15-point change, so seven prompt versions moved the headline by two points. Every step below closes one of those gaps.

Write `docs/EVAL.md` with the sections below, in order, before any prompt exists: all nine in the full lane, or sections 1, 5 and 7 in the light lane described next. Stop where it says STOP and show the user what you have. If the project already has a `docs/EVAL.md`, bring it up to date instead of starting again.

**Light lane.** If the model's output is only shown, so that no figure from it is published and no buyer acts on it (a caption, a summary line, a suggestion the user edits before it counts), sections 1, 5 and 7 are enough: the question each output answers, the error taxonomy and the run records, with a development set of real items chosen for their errors (section 4's first bullet) on which to classify disagreements, judged against section 1's definitions by whoever reads them. Everything below applies in full once a figure is published or a decision rests on the output, and a product that starts in the light lane moves to the full one before its first such figure.

## 1. The question each output answers

- For every field, class or score the model produces, write the question it answers in one sentence.
- If an existing label set will score it, copy that label's definition verbatim as the field's definition, and add only the reporting format after it. If the product needs a different definition, the label set cannot score it: say so and plan labels (section 2).
- Never score against a proxy label and call the result accuracy. A proxy may be shown, named as a proxy, and never pooled into a headline.
- STOP: the user confirms these questions are what the product is for.

## 2. The product's own labels

- Name the outputs the buyer acts on. For each with no external label, plan the labelling: who marks, how many items (section 3), the marking sheet with verdict and note columns, and when it happens. Labels made before any model output exists for those items are independent; labels made by verifying model output measure precision only, and the plan says so.
- Give the user's marking time in hours.

## 3. Size the evaluation for the decision

- Decide the smallest improvement worth acting on, in points of precision or recall or in disagreements per 100 checks.
- For each field, give the annotated count needed to show it: the 95% Wilson interval width at the planned count, and the paired test's sensitivity at the planned pairs (McNemar's test for paired right/wrong outcomes; a paired bootstrap for scores). A field with fewer than 10 annotated items is "too few to measure" and is always reported as such.
- If the count is unaffordable, say that iteration by measurement is not possible for that field and set a different stopping rule for it.
- STOP: the cost of labels and runs, cheapest sound route first, with its number.

## 4. Three sets

- A development set: items chosen for their errors, iterated on freely. Nothing measured on it is a claim; it is reported as a development signal.
- A holdout: drawn by a recorded seed after the prompt is pinned (its hash in a test), disjoint from every other set, touched once per published claim. The repository records the draw and the pin, and their order.
- The product labels from section 2.
- A sample is drawn before any run on it. A prompt is pinned before any draw that follows it.

## 5. An error taxonomy before any change

- Before the first run, write the taxonomy fitted to the task: the classes every disagreement will fall into, with "the label is wrong or inconsistent", "the definitions differ" and "other" always among them. For an extractor, for example: the model missed the clause; the model over-read; the label is wrong or inconsistent; the definitions differ; the quote or span is truncated; other. A classifier, a summariser or a scorer needs its own classes.
- After a run, classify every disagreement into it.
- Change one thing, aimed at the largest class. Measure again on the development set with a change report by field: resolved, remaining, introduced.
- A revision that adds features is not a fix. It needs an error class of its own.

## 6. Pre-register the headline

- Before any result returns, write down the measure, its denominator, the comparison (paired, on which fields), the test and the interval. Figures on non-identical checks are never pooled without saying so.
- Write the sentence that will be published, with blanks for the numbers.

## 7. Run records

- Every run records the prompt hash, model, effort, output-schema hash, sample identity, the estimate made before it from counted tokens, the cost after it, and cache reads and writes.
- One item is run before any paid run. Batch and caching are the default. Every run resumes without paying twice.
- Where a checker gates the model's output against a limit the prompt states (a word count, a sentence count, a list length), the prompt's number is the target and the checker's is a guard set above it. A fake model writes to the prompt's number and can never show the gap; a few real calls can, and they are how the guard is sized.

## 8. Label noise

- Read 20 to 30 labels yourself against the definitions before chasing accuracy, and record the share you disagree with. That is the ceiling, and a field at the ceiling is finished.

## 9. The stopping rule

- Set it in advance. For example: stop when the paired test across fields gives p above 0.2 twice in a row, or when most remaining errors are label noise, or when the budget cap is reached.
- A review finding becomes work only after the question "would the audience see this in thirty seconds or fifteen minutes?" is answered yes.

## Output

`docs/EVAL.md` with the nine sections, the marking sheet, and the first-run plan with its cost; in the light lane, sections 1, 5 and 7, the development set and the first-run plan. Then, and only then, the first prompt.
