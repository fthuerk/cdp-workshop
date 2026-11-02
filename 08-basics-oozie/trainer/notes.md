# Trainer notes — Module 08 Oozie in Hue

## Timing (~70 min)

| Section | Min | Note |
|---------|-----|------|
| Concept | 5 | Server, launcher on YARN, workflow vs coordinator; Hue only generates XML |
| 0 Orient | 3 | Menu names differ per Hue version; show it once on the projector |
| 1 Workflow + XML | 20 | The mapping table (UI field → XML element) is the core |
| 2 Break it | 6 | A failing action is added on purpose |
| 3 Time-based schedule | 12 | Start 2–3 minutes ahead; the first action appears quickly |
| 4 Hive load on arrival | 20 | Participants copy the CSV first, create `_SUCCESS` last |
| 5 Clean up | 3 | Make sure nobody leaves a 5-minute coordinator running |

If you run short, skip section 4 and show it as a demo, or skip the stretch.

## Before the session

- Oozie service running; Hue shows the **Workflow** and **Schedule** editors and the Job Browser.
- Each participant can write to `/user/<name>` and can run shell and fs actions (proxy user for Oozie is set up).
- Capacity: every action starts a launcher on YARN. With a full class a few launchers wait for resources; check the queue (module 03) if actions stay in PREP/RUNNING for long.
- Take the screenshots listed in [lab/images/README.md](../lab/images/README.md) on your cluster and put them in `lab/images/`. Adjust the XML snippets in the lab if your Hue generates a different schema version.

## Check-question answers

1. **Job types:** workflows, coordinators (tab "Schedules"), bundles.
2. **Error transition:** `<error to="Kill"/>` in the action; the kill node ends the workflow as KILLED.
3. **Launcher:** every action runs inside its own YARN application; the shell command runs in the launcher's container.
4. **End states:** SUCCEEDED via `<end>`, KILLED via `<kill>`.
5. **Catch-up:** a start in the past creates an action for every missed interval; they run as concurrency allows.
6. **Done-flag:** written last by the producer, so the consumer never sees an incomplete folder.
7. **WAITING:** the action stays WAITING until the input exists or the timeout is reached; the nominal time never changes.

## Pitfalls

- **Section 4 needs more than the earlier ones:** HiveServer2 must be reachable from Oozie, the **hive2** credential must be offered in the action's Credentials tab, and `LOAD DATA INPATH` must be allowed to move files from `/user/<name>/oozie_lab/landing` into the warehouse (HDFS permissions or Ranger URL/HDFS policy; the Hive user needs write access on the source folder). The single landing folder is a simplification: all waiting actions watch the same flag. In the test run only the oldest waiting action started and moved the flag away, so the others kept waiting. That means an old, still waiting day gets today's file (and partition `dt` of its own nominal day). Test the whole section 4 once with a normal user before the session.

- **Break-it (section 2):** `mkdir` on an existing folder does not fail in Oozie, so the lab adds a shell action `fail_on_purpose` (`ls /does/not/exist`). If a participant forgets to remove it, the schedules in sections 3 and 4 end KILLED too.
- **`${wf_date}` asked on manual submit:** expected; type any string, for example `manual`.
- **Time zone:** Hue stores the times in UTC or the browser zone depending on version; if the first action is "in the past", catch-up starts it at once. That is fine and a good moment to explain nominal time.
- **Concurrency 1:** a 5-minute schedule with a slow workflow queues actions; explain `throttle` and `concurrency`.
- **Done-flag not recognized:** a path typo in the dataset (`${YEAR}${MONTH}${DAY}` must produce the folder name) or a flag created as a folder instead of a file.
- **Hue differences:** the Hue editor versions (older "Oozie editor" vs. newer **Scheduler** menu) place the fields differently. The XML is the same; always fall back to "find it in the Storage Browser".
- Hue cannot define user-specific filesystem credentials, and it does not offer Hive2 or Spark credentials for Kerberos in every setup. Mention this when you go to module 11.
