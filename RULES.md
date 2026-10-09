# Tower Stack — Official Rules

The authoritative source of truth for Tower Stack. If the implementation
conflicts with this document, fix the implementation.

## 1. Objective

Stack swinging blocks into the tallest tower you can. Each block swings on
the crane; tap to drop it. Land it on the tower below — any overhang gets
sliced off. A total miss topples the run.

## 2. Setup

- A base block (72% of screen width) sits centered on the ground.
- The next block swings side to side above the tower top.
- Solo modes use one builder; Pass & Play and Vs Bot use 2+ builders, each
  with their own tower; turns rotate after every drop.

## 3. Turn order

1. Solo (Classic / Blitz / Zen): the same builder drops every block.
2. Pass & Play (2–4 builders, any mix of humans and bots): builders take
   turns, one drop each, in seat order. A builder who misses is eliminated;
   play continues with the survivors.
3. Vs Bot: you and the Crane Bot alternate drops.
4. The engine advances turns itself — the UI never skips or repeats a turn.

## 4. Legal moves

- Tap anywhere while a block is swinging to drop it at its current position.
- The block falls straight down onto the tower top.

## 5. Illegal moves

- Tapping while no block is swinging (landing animation, crash beat, pause,
  game over) does nothing.
- Tapping during another player's turn does nothing (theirs is the only
  active tower).
- Human taps never trigger a bot's drop; bots drop only through the engine.

## 6. Captures

Not applicable — Tower Stack has no captures.

## 7. Special rules

- **Perfect drop:** if the block lands within the perfect window (Chill 13px,
  Classic 7.5px, Turbo 5px, Master 3.2px of the block below on BOTH edges),
  it snaps to full width — nothing is trimmed. Consecutive perfects build a
  combo (x2, x3, …) shown on screen.
- **Slice:** any overhang is sliced off and tumbles away with rotation.
  The tower continues with the trimmed width.
- **Miss:** zero overlap — the block tumbles off and the builder is
  eliminated (or the run ends in solo modes).
- **Zen mode:** blocks NEVER shrink — every landed block keeps full width.
  Only perfects count toward combos.
- **60-Second Blitz:** the clock runs 60 seconds. A miss resets the tower
  to the base block but the clock keeps running; the score is the total
  blocks stacked.

## 8. Scoring

- 1 point per block stacked (height).
- Perfect drops additionally feed the combo counter (visible feedback).
- Blitz score = total blocks stacked across all resets within 60 seconds.
- Records kept per mode: best classic climb, best blitz score, best zen tower.

## 9. Winning conditions

- Classic / Zen: no winner — beat your own best height.
- Blitz: highest score when time expires (beats your best blitz).
- Pass & Play / Vs Bot: last builder standing wins. If every builder
  topples, the tallest tower among them wins (draw if equal).

## 10. Draw conditions

Pass & Play: all builders eliminated with equal tallest towers → draw,
reported as "Everyone toppled!".

## 11. AI strategy

The Crane Bot aims for the center of the block below with Gaussian-ish
error scaled by skill (RULES §3 — the bot must play the same swinging block
the human sees; it never places blocks by fiat):

- **Easy:** large error (σ ≈ 0.30 × block width) — clumsy, often trims.
- **Medium:** moderate error (σ ≈ 0.14) with occasional misjudgment.
- **Hard:** tiny error (σ ≈ 0.055), near-perfect; ~4% chance of a bad
  misjudgment so it can still lose.
- The bot visibly "aims" (aim marker pulses at its target) for ~950ms, then
  the crane swings to the aim point and drops.

## 12. Edge cases

- First block of a run always lands on the base block (no skill needed).
- A block exactly at the screen edge clamps inside the view.
- Pause freezes swing, bot aim, landing and crash timers; resume re-arms the
  current phase — a paused game can never lose a pending transition.
- Backgrounding pauses the engine the same way.
- The watchdog (3s) recovers any phase found without a live timer:
  dropping → finish landing; crashing → resolve the miss; swinging bot turn
  → re-arm the bot; blitz with expired clock → finish. Stuck states are
  impossible by construction.

## 13. Test cases

1. Drop exactly centered → perfect, full width kept, combo 1.
2. Drop offset by 10% of width → trimmed to overlap, combo reset.
3. Drop fully off the tower → miss: block tumbles, run ends (solo).
4. Two consecutive perfects → combo x2 popup.
5. Zen mode offset drop → full width kept, no trim.
6. Blitz miss → tower resets to base, score keeps counting, clock runs.
7. Party: player 1 misses → eliminated, player 2's tower untouched, turn passes.
8. Party: last player standing → wins immediately.
9. Pause mid-swing → swing freezes; resume → swing continues.
10. Bot turn → aim marker shows ~950ms, then a visible drop occurs.
11. Background the app mid-drop → no stuck state on return.
12. Restart from game over → fresh base block, height 0, ready phase.
