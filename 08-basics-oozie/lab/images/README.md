# Screenshots for the Hue Oozie lab

Place the files in this folder with exactly these names (PNG). The prefix is the lab section. The lab shows them with `![...](images/<file>)`. Crop to the relevant area; keep user names out of the picture or use the demo user.

| File | Lab section | Shows |
|------|-------------|-------|
| `0_hue_oozie_navigation.png` | 0 | **Done.** Left menu with Scheduler / Workflow / Schedule / Bundle |
| `0_jobs_browser_with_workflow_tab.png` | 0 | **Done.** Job Browser with the Workflows / Schedules / Bundles tabs |
| `1_workflow.png` | 1.1 | **Done.** Workflow with `make_dir`, `say_hello`, kill node |
| `1_transitions.png` | 1.1 | **Done.** Transitions tab of an action (OK / KO) |
| `1_3_xml_tab.png` | 1.3 | **Done.** XML tab of the job |
| `1_2_finished_job_browser.png` | 1.2 | **Done.** Finished workflow, Graph tab |
| `1_3_shell_action_properties.png` | 1.2 | **Done.** Shell action Properties with `externalId` |
| `2_fail_on_purpose.png` | 2 | **Done.** KILLED workflow, failed action in red |
| `3_1_coordinator.png` | 3.1 | **Done.** Schedule editor: workflow, crontab, time range, parameter |
| `3_2_schedules_list.png` | 3.3 | **Done.** Coordinator Actions tab with nominal times |
| `4_2_hive_workflow.png` | 4.2 | **Done** (redo with `load_partition` names). Hive action with script file and parameters |
| `4_3_hive_coordinator.png` | 4.3 | **Done.** Schedule with `wf_date` and `landing_dir` as Input Path |
| `4_5_coordinator_waiting.png` | 4.5 | **Done.** Actions WAITING, `missingDependencies` visible |
| `4_5_copy_file_to_landing.png` | 4.5 | **Done.** Copy dialog, target `landing` folder |
| `4_5_coordinator_landing_first_success.png` | 4.5 | **Done.** First action SUCCEEDED, others WAITING |
| `4_5_partition_and_row_count.png` | 4.5 | **Done.** `SHOW PARTITIONS` and row count |
| `stretch_fork_join.png` | Stretch | Workflow canvas with fork and join |
