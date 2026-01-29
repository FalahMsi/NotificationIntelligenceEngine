🔐 Security Policy

Notification Intelligence Engine (NIE)

This document describes how security issues are handled for the Notification Intelligence Engine repository.

NIE is a pure, deterministic computation engine with no I/O, no networking, and no persistent state.
Nevertheless, we take logic integrity, correctness, and misuse risks seriously — especially because this engine is intended for production scheduling and notification systems.

⸻

📦 Supported Versions

Only the following versions receive security-related reviews and fixes:
Version
Supported
1.x (current major)
✅ Yes
< 1.0
❌ No
Security fixes are always applied to the latest minor release of the current major version only.

⸻

🛡️ What We Consider a Security Issue

Because NIE is a logic engine (not a networked system), security issues are defined differently than traditional vulnerabilities.

We consider the following in scope:

✅ In Scope
	•	Incorrect notification trigger calculations that could:
	•	Trigger notifications at the wrong time
	•	Skip required notifications
	•	Trigger notifications too early or too late
	•	Timezone or calendar logic flaws that cause:
	•	Cross-day mislabeling (today / tomorrow / later)
	•	Incorrect behavior near midnight boundaries
	•	Cross-platform semantic drift:
	•	Swift, Kotlin, and TypeScript implementations producing different results for the same inputs
	•	Determinism violations:
	•	Same inputs producing different outputs
	•	Logic paths that violate the documented semantic contract

❌ Out of Scope
	•	UI/UX issues
	•	Performance optimizations
	•	Platform notification scheduling APIs
	•	Event persistence or storage
	•	Permission handling
	•	Network or infrastructure vulnerabilities
	•	Dependency vulnerabilities outside this repository

⸻

🚨 Reporting a Vulnerability

If you believe you have found a security or logic vulnerability, please report it responsibly.

📩 How to Report

Preferred method:
📧 Email: info.alharbi94@gmail.com

Include:
	1.	A clear description of the issue
	2.	A minimal reproducible example (inputs → incorrect output)
	3.	Platform(s) affected (Swift / Kotlin / TypeScript)
	4.	Expected vs actual behavior
	5.	Any relevant test vectors or timestamps

⚠️ Do NOT open a public GitHub issue for security-sensitive findings.

⸻

⏱️ Response Timeline

You can expect:
	•	Acknowledgement within 72 hours
	•	Initial assessment within 7 days
	•	Resolution or formal rejection within 14 days

If the issue is accepted:
	•	A fix will be released in the next patch/minor version
	•	A changelog entry will document the correction
	•	Credit will be given (if desired)

If the issue is declined:
	•	A detailed explanation will be provided

⸻

🔍 Disclosure Policy
	•	Please allow reasonable time for fixes before public disclosure
	•	Coordinated disclosure is strongly preferred
	•	Public disclosure before resolution may result in the report being rejected

⸻

🧠 Security Philosophy

NIE follows these security principles:
	•	Determinism over heuristics
	•	Absolute time over calendar shortcuts
	•	Explicit semantics over implicit platform behavior
	•	Cross-platform equivalence as a security guarantee
	•	Small surface area to reduce attack and misuse vectors

Security for NIE is primarily about correctness, predictability, and trust.

⸻

🤝 Responsible Use

This library is intended for:
	•	Production scheduling systems
	•	Enterprise notification workflows
	•	Time-critical reminder logic

Misuse of the engine (e.g., ignoring its semantic guarantees) is the responsibility of the consumer application.

⸻

📜 License

This repository is licensed under the MIT License.
Security reporting does not alter licensing terms.
