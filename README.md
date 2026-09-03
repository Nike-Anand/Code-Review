
# PRAssist.ai

> AI-powered Pull Request Review & Approval on the Go

PRAssist.ai is a mobile-first AI assistant that helps developers and engineering managers review pull requests, understand potential issues, and make faster merge decisions without being tied to a laptop.

The system combines **GitLab**, **Microsoft Teams notifications**, a **Node.js backend**, **Ollama + Mistral 7B**, and a **Flutter mobile application** into one lightweight workflow.


<video src="km_20260903-1_1440p_15f_20260903_160752.mp4#t=30" autoplay loop muted playsinline width="100%"></video>
---

## 🚀 Why PRAssist.ai?

Production pull requests do not wait for reviewers to return to their desks.

A reviewer might be:

- 🏖️ On vacation
- 🚌 Travelling
- 🏢 Away from their workstation
- 🌙 Unavailable when an important PR is raised

PRAssist.ai brings the review workflow to the phone and provides a clear AI-assisted decision:

- 🟢 **GREEN → Approve**
- 🟡 **YELLOW → Request Changes**
- 🔴 **RED → Block**

---

## ✨ Key Features

### 🤖 AI-Powered PR Analysis

Analyzes pull-request information and repository context using **Mistral 7B through Ollama**.

### 📱 Mobile PR Review

Review important PRs from a Flutter mobile application instead of depending on a laptop.

### 🟢🟡🔴 Clear Verdict System

| Verdict | Meaning | Action |
|---|---|---|
| 🟢 **GREEN** | No critical issues detected | Approve & Merge |
| 🟡 **YELLOW** | Issues or improvements identified | Request Changes |
| 🔴 **RED** | Critical issues detected | Block PR |

### 🔔 Notifications

GitLab and Microsoft Teams events can trigger notifications so reviewers can react to important PR activity.

### 🔍 Context-Aware Review

The backend can collect PR details, changed files, diffs, repository structure, documentation, requirements, and related context before asking the AI to review the change.

### ⚡ One-Tap Decision

Once the review is complete, the reviewer can approve, request changes, or block the PR directly from the mobile workflow.

### 🗂️ Review History

Analysis results, decisions, comments, and activity can be retained for tracking and auditing.

---

## 🏗️ System Architecture

```text
                    ┌─────────────────────┐
                    │       GitLab        │
                    │   Merge Request     │
                    └──────────┬──────────┘
                               │
                         Webhook / API
                               │
                               ▼
┌───────────────────────────────────────────────────────────┐
│                  LOCAL BACKEND (LAPTOP)                   │
│                                                           │
│  ┌──────────────┐     ┌──────────────────────┐            │
│  │ GitLab API   │ ──► │ Repository Context   │            │
│  │ Client       │     │ & PR Information     │            │
│  └──────────────┘     └──────────┬───────────┘            │
│                                  │                        │
│                                  ▼                        │
│                         ┌────────────────┐                │
│                         │ Prompt Builder  │                │
│                         └───────┬────────┘                │
│                                 │                         │
│                                 ▼                         │
│                         ┌────────────────┐                │
│                         │ Ollama          │                │
│                         │ Mistral 7B      │                │
│                         └───────┬────────┘                │
│                                 │                         │
│                                 ▼                         │
│                         ┌────────────────┐                │
│                         │ Result Processor│                │
│                         │ Verdict / Issues│                │
│                         └───────┬────────┘                │
└─────────────────────────────────┼─────────────────────────┘
                                  │
                           REST / Local Wi-Fi
                                  │
                                  ▼
                    ┌─────────────────────────┐
                    │     Flutter Mobile App  │
                    │                         │
                    │  Notifications          │
                    │  PR Analysis            │
                    │  Findings & Comments    │
                    │  Approve / Changes      │
                    │  Activity / History     │
                    └───────────┬─────────────┘
                                │
                         Decision / Action
                                │
                                ▼
                    ┌─────────────────────────┐
                    │        GitLab           │
                    │ Updated PR / Merge      │
                    └─────────────────────────┘
````

---

## 🧠 AI Analysis

PRAssist.ai uses a local **Mistral 7B** model through **Ollama**.

The analysis can consider:

* Pull request title
* Pull request description
* Changed files
* Code changes / diff
* Repository structure
* Related files
* README and documentation
* Project requirements
* Coding standards
* Previous context
* Potential conflicts
* Missing functionality
* Test coverage

The model produces a structured review containing:

```text
VERDICT: GREEN / YELLOW / RED

REASON:
Explanation of the review result

ISSUES:
Potential problems identified

RECOMMENDATION:
Suggested next action
```

---

---

<p align="center">

**PRAssist.ai**

*Intelligent PR review. Faster decisions. Anywhere.*

</p>
```

