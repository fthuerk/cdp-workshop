# Oozie in Hue — troubleshooting

## I do not find the Workflow or Schedule editor

Menu names depend on the Hue version: look under **Editor**, **Scheduler** or **Documents → New**. If the entries are missing, ask your instructor: the Oozie editors must be enabled in Hue.

## Submit fails with a permission or proxy-user error

The Oozie server must be allowed to act as your user. Ask your instructor; the lab cannot fix it.

## The workflow stays RUNNING or the action stays in PREP

Every action starts a launcher on YARN. If the cluster queue is full, the launcher waits. Check the YARN queue and wait, or ask your instructor.

## The second run (or any run) ends KILLED

Open the job, then the **Graph** tab: click the action marked red; it shows the error message. In section 2 this is expected for `fail_on_purpose`. Remove that action from the workflow and save.

## A `${...}` variable is asked for or stays unresolved

The workflow uses a variable that nobody sets. When you submit by hand, type a value. In a coordinator, define the parameter in the **Parameters** section with the exact name from the workflow (case-sensitive).

## The schedule shows no actions

Check **Start** and **End**: the window must contain at least one interval, and the end must lie after the start. Times are in the time zone shown in the editor.

## The data-triggered action stays WAITING although I created the files

- The path must match the dataset path exactly (`/user/<your_user>/oozie_lab/landing`).
- `_SUCCESS` must be a **file**, not a folder, directly inside that folder.
- The folder name uses the nominal time of the action, which can be a different day than today if the start date was earlier.

## Section 6: `oozie: command not found`, `Oozie URL is not available`, or `401`

- `echo "${OOZIE_URL}"` must show the URL from your handout. Variables are per terminal: set them again in a new one.
- `klist` must show a valid ticket; otherwise `kinit "${WORKSHOP_USER}"` again.

## Section 6: `oozie validate` or `-run` reports an error

- Leftover `<...>` placeholders in `csv-load.properties` are the usual cause. Open the file and replace every one of them.
- Paste `workflow.xml` unchanged: the `${...}` expressions are filled in by Oozie.
- `-run` says the application path does not exist: `oozie.wf.application.path` must point to the **folder** `hdfs://.../user/<your_user>/oozie_lab_cli/csv-load`, and `hdfs dfs -ls "${CLI_HDFS}"` must show `workflow.xml`.
- A `${...}` variable stays unresolved: compare the names in `workflow.xml` with the left side of the lines in `csv-load.properties` (case-sensitive).

## Section 6: the `csv-to-table` action ends `KILLED` or `ERROR`

- Take the **Ext ID** from `oozie job -info "${WF_ID}"` and read `yarn logs -applicationId <ext-id>`. The Spark application is a second YARN application next to the launcher; its log has the Python error.
- `Path does not exist`: check `csvDir` with `hdfs dfs -ls`. The folder must contain CSV files with a header line.
- Database or table not found, or a GSS error towards the Metastore: the `hcat` credential or `hive-site.xml` is missing. Check that `hdfs dfs -ls "${CLI_HDFS}"` lists `hive-site.xml` and ask your instructor whether the `hcat` credential is enabled.
- `Permission denied` on the warehouse folder: you may only create tables in your own database (`database` must be your user name).

## Section 6: the `load-managed` action ends `KILLED` or `ERROR`

- `GSS initiate failed` or `Could not open client transport`: compare `jdbcURL` and `jdbcPrincipal` with the values in the **XML** tab of your section 4 workflow in Hue.
- `Table not found`: the Spark step has to create the external table first; check `extTable` and `database` in both steps (they come from the same properties file).

## I cannot find `coordinator.xml`

Submit the workflow or schedule first. Then open the job in the Job Browser and use its **XML** tab.
