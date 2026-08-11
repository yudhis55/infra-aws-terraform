# Locked experiment profiles

`final-load-profile.json` is the preregistered upper envelope for calibration
and the three final trials. Its active load lasts 26 minutes. The scaling
collector derives its duration from that active load, the complete 20-minute
scale-in threshold, and a two-sample margin at the fixed 60-second grain.
Scale-in latency is measured from load completion to the first sample
where both desired and running ECS task counts have decreased from their peaks
with no pending task. It does not claim full restoration to baseline within the
observation window. After each observation window, the orchestrator enforces
the ten-minute minimum cooldown and then waits for the ECS service and ASG to
return to the exact calibration baseline before beginning the next trial. This
convergence gate is a trial precondition and is not included in performance
aggregates. A threshold miss is retained as an experimental result; it does not
prevent collection of the remaining locked trials.

The profile digest is part of the campaign scientific input. Changing any VU,
duration, threshold, endpoint, or cooldown after campaign freeze invalidates
both provisioning cycles and requires a new campaign.
