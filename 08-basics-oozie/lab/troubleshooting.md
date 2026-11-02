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

## I cannot find `coordinator.xml`

Submit the workflow or schedule first. Then open the job in the Job Browser and use its **XML** tab.
