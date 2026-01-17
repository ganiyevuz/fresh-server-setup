# 🚀 Fresh Server Setup

![OS](https://img.shields.io/badge/Linux-Ubuntu%20%7C%20Debian-informational?logo=linux)
![License](https://img.shields.io/github/license/ganiyevuz/fresh-server-setup)
![ShellCheck](https://img.shields.io/github/actions/workflow/status/ganiyevuz/fresh-server-setup/shellcheck.yml?label=ShellCheck)


Automated **fresh Linux server setup** script for developers.
Designed to bootstrap a new server quickly with sane defaults, essential tools, and a repeatable workflow.

No `git clone`. No manual steps. Just **one command**.

---

## ✨ Features

* One-command installation (`curl | bash`)
* Optimized for **fresh servers**
* Idempotent (safe to re-run)
* Minimal interaction
* Developer-friendly defaults
* Easy to extend and customize

---

## 📦 What This Script Does

Depending on configuration, the script can:

* Update system packages
* Install essential tools (curl, git, build tools, etc.)
* Configure shell environment
* Prepare server for development / production use
* Apply common best practices for fresh servers

> The script is intentionally kept simple and readable so you can audit or modify it easily.

---

## ⚡ Quick Install (Recommended)

Run directly from GitHub:

```bash
curl -LsSf https://raw.githubusercontent.com/ganiyevuz/fresh-server-setup/main/setup.sh | bash
```

If `sudo` is required:

```bash
curl -LsSf https://raw.githubusercontent.com/ganiyevuz/fresh-server-setup/main/setup.sh | sudo bash
```

---

## 🔐 Safer Install (Inspect Before Running)

```bash
curl -LsSf https://raw.githubusercontent.com/ganiyevuz/fresh-server-setup/main/setup.sh -o setup.sh
chmod +x setup.sh
less setup.sh
./setup.sh
```

---

## 🧩 Passing Arguments (Optional)

If the script supports flags or options:

```bash
curl -LsSf https://raw.githubusercontent.com/ganiyevuz/fresh-server-setup/main/setup.sh | bash -s -- --flag value
```

---

## 📌 Version Pinning (Best Practice)

For production or CI usage, pin to a **tag** or **commit SHA**:

```bash
curl -LsSf https://raw.githubusercontent.com/ganiyevuz/fresh-server-setup/<TAG>/setup.sh | bash
```

or

```bash
curl -LsSf https://raw.githubusercontent.com/ganiyevuz/fresh-server-setup/<COMMIT_SHA>/setup.sh | bash
```

---

## 🛠 Supported Systems

* Ubuntu (primary target)
* Debian-based systems

> Other distributions may work but are not officially tested.

---

## 🧪 Re-running the Script

This setup is designed to be **idempotent** — running it multiple times should not break your system.

---

## 📂 Repository Structure

```text
fresh-server-setup/
├── setup.sh     # Main installer script
└── README.md
```

---

## 🔍 Philosophy

* **Transparent**: readable shell code
* **Fast**: minimal overhead
* **Composable**: easy to fork and extend
* **No magic**: everything happens in plain bash

---

## 🤝 Contributing

Contributions are welcome.

* Fork the repo
* Create a feature branch
* Submit a pull request

---

## ⚠️ Disclaimer

This script modifies system packages and configuration.
Always review the script before running it on production servers.

---
