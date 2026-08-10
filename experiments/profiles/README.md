# Locked experiment profiles

`final-load-profile.json` is the preregistered upper envelope for calibration
and the three final trials. Its active load lasts 26 minutes; the remaining
19 minutes of the 45-minute per-trial envelope are reserved for observed
scale-in. Scale-in latency is measured from load completion to the first sample
where both desired and running ECS task counts have decreased from their peaks
with no pending task. It does not claim full restoration to baseline within the
observation window. The separate ten-minute cooldown begins after the trial
observation window and is not included in performance aggregates.

The profile digest is part of the campaign scientific input. Changing any VU,
duration, threshold, endpoint, or cooldown after campaign freeze invalidates
both provisioning cycles and requires a new campaign.
