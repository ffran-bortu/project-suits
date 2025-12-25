# Godot 4.5 Bug Hunter Mission

**Goal:** Analyze the codebase for logical errors, syntax issues, and Godot 4.x migration risks using the installed CLI tools.

**Phase 1: Automated Scans (Turbo Mode)**
1.  **Linter Scan:** Run `python -m gdtoolkit.linter [folder_path]` on the target folder.
    * *Focus:* Look for "unused signal," "variable shadowing," and "function has no return type" warnings.
2.  **Headless Compilation:** Run `godot --headless --check-only --script [script_path]` for key scripts.
    * *Focus:* This catches deep syntax errors that the linter might miss.

**Phase 2: Logic Analysis (The "Human" Check)**
Review the code for these specific Godot 4.5 pitfalls:
* **Await Hazards:** Look for `await` calls on signals that might never emit (causing a soft freeze).
* **Tween Memory Leaks:** Ensure tweens are created with `create_tween()` and checked for validity if referenced later.
* **Callable Bindings:** specific check for `.connect()` syntax. Ensure it uses the Godot 4 style: `signal.connect(method)` instead of the old string-based style.
* **Physics Safety:** Verify that physics bodies are NOT modifying `global_position` directly inside `_process` (must use `_physics_process` or `PhysicsServer`).

**Phase 3: The Fix Plan**
Create a report titled `BUG_REPORT.md` listing:
1.  **Critical Errors:** Syntax or crashes found by the CLI tools.
2.  **Logic Risks:** Potential infinite awaits or physics race conditions.
3.  **Suggested Fixes:** Code snippets showing the corrected implementation.

**Action:** Do not apply fixes yet. Just generate the report.