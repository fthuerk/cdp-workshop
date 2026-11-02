# Trainer live demos — Oozie

Optional extras while participants run the lab. Use `${WORKSHOP_ROOT}` and the URLs from your cluster handout. Run demos with your own trainer account and your own `OOZIE_URL`.

---

## 1. Hue Workflow editor — drag and drop

**Goal:** Show that the XML from the lab can also be built in a UI, and where that stops.

In Hue open **Scheduler → Workflow**, drag a **Shell** and a **Hive** action onto the canvas, save, and submit. Then open the generated `workflow.xml` in the HDFS file browser.

**Talking point:** The UI is fine for a first draft. Production workflows end up as files in Git (`workflow.xml`, `job.properties`), deployed with a script. Hue cannot define user-specific filesystem credentials; those are written by hand in the XML (see the Cloudera Oozie configuration guide, file system credentials).

---

## 2. Email action and error notification

**Goal:** Close the loop "pipeline failed, a person knows".

Needs SMTP settings in Oozie (`oozie.email.smtp.host`, `oozie.email.from.address`, optional auth and TLS). Copy `meter-daily` to your home directory and replace the `fail` transition of the Spark action by a new node:

```xml
<action name="notify">
  <email xmlns="uri:oozie:email-action:0.2">
    <to>ops@example.org</to>
    <subject>Pipeline ${wf:name()} failed: ${wf:id()}</subject>
    <body>Node ${wf:lastErrorNode()} failed: ${wf:errorMessage(wf:lastErrorNode())}</body>
  </email>
  <ok to="fail"/>
  <error to="fail"/>
</action>
```

**Talking point:** Both transitions of the email node lead to `fail` — a broken mail server must not hide the original failure.

---

## 3. Bundle — start two coordinators together

**Goal:** Show the third Oozie application type.

A bundle is an XML file that references coordinators. A minimal example for the two coordinators of the lab:

```xml
<bundle-app name="meter-bundle" xmlns="uri:oozie:bundle:0.2">
  <coordinator name="landing-check-coord">
    <app-path>${appRoot}/coord/landing-check-coord</app-path>
  </coordinator>
  <coordinator name="meter-daily-coord">
    <app-path>${appRoot}/coord/meter-daily-coord</app-path>
  </coordinator>
</bundle-app>
```

Submit with `oozie.bundle.application.path` and `appRoot` (the full HDFS URI of your `oozie` folder) in the properties file. Suspend, resume and kill act on all coordinators at once.

**Talking point:** One bundle per data product ("everything for the meter feed") gives operations a single switch; common in production, rarely needed in a first pipeline.

---

## 4. Rerun of a coordinator action

**Goal:** Show why nominal time matters.

After section 7 finished: `oozie job -rerun "<coordinator-id>" -action 2` re-creates the second slot. Show that the new workflow writes to the **same** `workDir` (named after the nominal time) and that the Created time is new.

---

## 5. Oozie web UI and the Job Browser

**Goal:** Operational views.

Open the Oozie web UI (or Hue Job Browser). Show the coordinator action list with filters on status, the DAG of a workflow, and the **Configuration** tab — where an unresolved variable is easiest to see.

---

## 6. Where does this go next? (discussion, 5 min)

Show the [deep-dive](deep-dive.md) section 8: the Apache project is retired (Attic, 2025), Cloudera still ships and supports its own Oozie build, and Cloudera's path for new pipelines is Cloudera Data Engineering with Airflow; an `oozie2cde` migration API exists. Ask the group which of their Oozie workflows are simple enough to convert and which depend on coordinator data triggers (those need an Airflow sensor design).
