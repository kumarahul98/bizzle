# Artifact Registry cleanup policy

Cloud Functions 2nd gen builds a container image on every deploy and stores it
in the `gcf-artifacts` Artifact Registry repo. Nothing prunes them by default,
so the repo grows with every deploy and bills slowly — it had reached 128 MB
across 6 versions before this policy was applied (2026-07-20).

## The policy

`artifact-cleanup-policy.json` keeps the **3 most recent versions** and deletes
everything else.

Two rules are required, not one. Artifact Registry has no single "keep N"
setting: you write a DELETE rule that matches everything, plus a KEEP rule that
carves out the exceptions. **KEEP takes precedence over DELETE**, so the net
effect is "retain exactly 3".

## Why 3, and why it is safe

The currently-serving image is always the newest, so it can never be pruned.
This matters more than it sounds — deleting the image a deployed function is
running from breaks cold starts and scale-up, which is the standard footgun
with these policies. Keeping 3 leaves the live image plus two rollback targets.

## Applying it

`firebase functions:artifacts:setpolicy` CANNOT express this — it only supports
age-based retention (`--days`). Count-based retention needs gcloud:

```sh
gcloud artifacts repositories set-cleanup-policies gcf-artifacts \
  --location=us-central1 --project=travey-298a7 \
  --policy=backend/artifact-cleanup-policy.json
```

Verify with:

```sh
gcloud artifacts repositories describe gcf-artifacts \
  --location=us-central1 --project=travey-298a7 \
  --format="json(cleanupPolicies,cleanupPolicyDryRun)"
```

`cleanupPolicyDryRun: true` would mean the policy only logs what it *would*
delete. Its absence (or `false`) means deletion is live.

## Timing

Cleanup runs asynchronously, roughly daily — the version count does not drop
the moment the policy is set. This is expected, not a failure.

## Not managed by firebase.json

This is applied via gcloud and lives outside the Firebase CLI IaC. It is
committed here so the intended state is recoverable if the policy is ever
cleared in the console; the file is the source of truth, not the cloud.
