# Godot 4.5 Refactor Mission
Read 'best_practices.txt' to optimize code as best you can
**Goal:** Refactor the selected script/folder to improve performance, readability, and type safety without breaking scene dependencies.

**Phase 1: Analysis & Safety Check**
1.  **Scan for Dependencies:** Before changing anything, search all `.tscn` files to see where the selected script(s) are attached or referenced. List these scenes.
2.  **Identify Improvements:** Analyze the GDScript code for:
    * Missing static types (e.g., convert `var health` to `var health: int`). *Priority: High (Performance).*
    * Magic numbers (extract to `const` or `@export`).
    * Unused variables or signals.
    * Functions longer than 50 lines.

**Phase 2: Execution (Auto-Approve)**
*Instruction: Apply the following changes one file at a time.*
1.  **Apply Static Typing:** Update variables and function signatures to use strict typing (`: Node`, `: Vector2`, `-> void`).
2.  **Format Code:** Ensure the code follows the official GDScript style guide (snake_case functions, PascalCase classes).
3.  **Optimize:** If you see heavy logic in `_process(delta)`, check if it can be moved to `_physics_process` or a signal-based update.

**Phase 3: Verification (Crucial)**
1.  **Parse Check:** Run the Godot command line to check for script parse errors:
    * `godot --headless --check-only --script [path_to_script]`
2.  **Orphan Check:** detailed check of the `.tscn` files identified in Phase 1 to ensure no properties were renamed that are set in the Inspector (Look for "missing property" risks).

**Phase 4: Artifact Generation**
* Create a file named `REFACTOR_LOG.md` containing:
    * List of files modified.
    * Performance wins (e.g., "Added types to 15 variables").
    * **Manual Verification List:** A checklist of which specific Scenes I need to play-test to ensure logic holds.

**Phase 5: Bug Hunt**
*in the same folder where this file is, find 'bug_hunt.md' and follow all the instructions there. only after you do all of those you stop and report back*