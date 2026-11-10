---
theme: default
title: Apache Livy - Spark as a REST service
info: |
  Apache Livy: introduction for the Livy lab (module 09).
class: text-left
highlighter: shiki
drawings:
  persist: false
transition: slide-left
mdc: true
routerMode: hash
lineNumbers: false
colorSchema: auto
---

# Apache Livy

Spark as a REST service on the CDP cluster

<div class="pt-8 text-gray-500">
Introduction to the Livy lab (module 09)
</div>

<!--
About 15 minutes of theory before the lab. Press "o" for the slide overview, "d" for dark mode, "f" for fullscreen.
-->

---

# Livy in the platform

<img src="/images/navigation_site_livy.png" class="rounded shadow mx-auto max-h-[25rem] mt-1" />

<div class="text-center text-sm mt-2">

Livy is the **REST entry point for Spark**: it sits in the tools layer and starts Spark applications on YARN for its clients.

</div>

---
src: ./pages/01-theory.md
---
