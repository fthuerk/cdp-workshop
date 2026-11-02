# Troubleshooting — Module I2 Ranger

## Permission denied on `ranger_lab.meter_readings` during sections 2–4

- Wait **30–60 seconds** after the trainer saves a policy, then re-run the query.
- Confirm you are in Hue as **`${ws_user}`** matching your `kinit` principal.
- Ask the trainer whether policies target group **`workshop`** (or your cohort’s `WORKSHOP_GROUP`) and your user is a member (`groups` on the edge node).

## Section 1 never shows an error (table readable immediately)

- A pre-existing allow policy on `ranger_lab` may be in place. Trainer should disable extra policies or use a fresh database from `setup/setup.sh`.

## Masking does not change column values

- Ranger masking does not apply to **`hive`** service users or principals listed in **Hive admin** / superuser lists — use a normal participant account.
- Confirm masking policies are on the **Masking** tab of the **Hive** service, not only HDFS.
- Wait for policy sync and run `SELECT` again (not a cached result set from an old Hue tab).

## Row filter — everyone sees all stations

- Row filter policy must be on **Row Level Filter** for table `meter_readings`.
- Expression must use **`current_user()`** matching Hive’s short user name (same as `${ws_user}`).
- Participants need **SELECT** on **`station_assignment`** (included in trainer allow policy).

## Row filter — `COUNT(*)` still shows 30

- With a working row filter, `COUNT(*)` counts **visible** rows only (often 14–16 for two stations), not 30. If you see 30, the filter is not active.

## Deny on `customer_master` does not block reads

- Deny must be under **Deny Conditions** on the policy (or a dedicated deny policy), not only removing the allow policy.
- Check policy **priority** and that deny matches group **`workshop`**.

## `check.sh` fails after the lab

- The script expects **final** trainer state: allow + **nullify** on `customer_name` + row filter. Running it after section 2 only will fail — that is expected.
- Export `WORKSHOP_USER` and `HS2_URL` if beeline cannot connect.

## Impala vs Hive

- This lab uses **Hive** in Hue. Impala has a separate Ranger service; policies created on Hive do not automatically apply to Impala.

## Trainer escalation

- Recreate data: `I2-basics-ranger/setup/setup.sh`
- Remove lab policies in Ranger UI or disable them for reuse
- HiveServer2 logs / Ranger admin sync if policies never take effect (>2 minutes)
