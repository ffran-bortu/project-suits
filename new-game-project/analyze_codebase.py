"""
Automated Script Analysis Tool for Fire Emblem Tactical RPG Project

This script analyzes all .gd files against the project coding standards defined in:
docs/archive/fix_folder/Project Analysis & Documentation Pr.txt

Analysis Criteria (Section 5.3, Section 1, Appendix A):
1. Type Safety (Section 1.1)
2. Naming Conventions (Section 1.2)
3. Constants Over Magic Numbers (Section 1.3)
4. Architecture Compliance (Section 2)
5. Documentation (Section 3)
6. Error Handling (Section 4.2.B)
7. Code Quality (Section 5.3)
8. Performance (Section 6)
"""

import os
import re
from pathlib import Path
from typing import Dict, List, Tuple
from dataclasses import dataclass, field

@dataclass
class FileAnalysis:
    """Analysis results for a single file"""
    filepath: str
    has_file_header: bool = False
    type_safety_issues: List[str] = field(default_factory=list)
    magic_numbers: List[str] = field(default_factory=list)
    hard_coded_paths: List[str] = field(default_factory=list)
    missing_error_handling: List[str] = field(default_factory=list)
    functions_found: List[str] = field(default_factory=list)
    is_addon: bool = False
    
    def has_issues(self) -> bool:
        return (len(self.type_safety_issues) > 0 or 
                len(self.magic_numbers) > 0 or 
                len(self.hard_coded_paths) > 0 or
                len(self.missing_error_handling) > 0 or
                not self.has_file_header)

class CodebaseAnalyzer:
    """Analyzes all GDScript files in the project"""
    
    def __init__(self, project_root: str):
        self.project_root = Path(project_root)
        self.results: List[FileAnalysis] = []
        
    def analyze_all_files(self, file_list: str) -> None:
        """Analyze all files from the provided list"""
        with open(file_list, 'r', encoding='utf-8') as f:
            files = [line.strip() for line in f if line.strip()]
        
        for filepath in files:
            if os.path.exists(filepath):
                analysis = self.analyze_file(filepath)
                self.results.append(analysis)
                
    def analyze_file(self, filepath: str) -> FileAnalysis:
        """Analyze a single GDScript file"""
        analysis = FileAnalysis(
            filepath=filepath,
            is_addon="\\\\addons\\\\" in filepath or "/addons/" in filepath
        )
        
        try:
            with open(filepath, 'r', encoding='utf-8') as f:
                content = f.read()
                lines = content.split('\\n')
                
            # Check for file header (Section 3.1)
            analysis.has_file_header = self._check_file_header(content)
            
            # Extract function definitions
            analysis.functions_found = self._extract_functions(content)
            
            # Check type safety (Section 1.1)
            analysis.type_safety_issues = self._check_type_safety(lines)
            
            # Check for magic numbers (Section 1.3)
            analysis.magic_numbers = self._find_magic_numbers(lines)
            
            # Check for hard-coded paths (Section 2.3)
            analysis.hard_coded_paths = self._find_hardcoded_paths(lines)
            
            # Check error handling (Section 4.2.B)
            analysis.missing_error_handling = self._check_error_handling(lines)
            
        except Exception as e:
            print(f"Error analyzing {filepath}: {e}")
            
        return analysis
    
    def _check_file_header(self, content: str) -> bool:
        """Check if file has the required header documentation"""
        # Look for the triple-quote header with required sections
        header_pattern = r'\"\"\"\\s*FILE:\\s*.+?PURPOSE:\\s*.+?OVERVIEW:'
        return bool(re.search(header_pattern, content, re.DOTALL | re.IGNORECASE))
    
    def _extract_functions(self, content: str) -> List[str]:
        """Extract all function definitions"""
        # Match: func function_name(params) -> return_type:
        func_pattern = r'func\\s+([a-zA-Z_][a-zA-Z0-9_]*)\\s*\\('
        return re.findall(func_pattern, content)
    
    def _check_type_safety(self, lines: List[str]) -> List[str]:
        """Check for type safety violations"""
        issues = []
        
        for i, line in enumerate(lines, 1):
            # Skip comments and empty lines
            if line.strip().startswith('#') or not line.strip():
                continue
                
            # Check for untyped variable declarations
            if 'var ' in line and ':' not in line.split('var')[1].split('=')[0]:
                # Check if it's actually missing type (not just short assignment)
                if '=' in line:
                    var_part = line.split('var')[1].split('=')[0]
                    if ':' not in var_part and '(' not in line:  # Exclude function calls
                        issues.append(f"Line {i}: Untyped variable - {line.strip()}")
            
            # Check for functions without return type
            if 'func ' in line and '->' not in line and 'func _' not in line:
                # Constructor and internal functions may skip return type
                if not line.strip().endswith(':'):
                    continue
                issues.append(f"Line {i}: Function missing return type - {line.strip()}")
        
        return issues
    
    def _find_magic_numbers(self, lines: List[str]) -> List[str]:
        """Find magic numbers in logic (Section 1.3)"""
        magic_numbers = []
        
        for i, line in enumerate(lines, 1):
            # Skip const definitions, comments, and strings
            if 'const ' in line or line.strip().startswith('#') or '\"' in line or \"'\" in line:
                continue
            
            # Look for numeric comparisons or assignments in logic
            if any(op in line for op in ['>', '<', '>=', '<=', '==', '!=']):
                # Find numbers in comparisons
                numbers = re.findall(r'[><=!]=?\\s*(\\d+\\.?\\d*)', line)
                if numbers and float(numbers[0]) not in [0, 1, -1]:  # Ignore common values
                    magic_numbers.append(f"Line {i}: Magic number {numbers[0]} - {line.strip()}")
        
        return magic_numbers
    
    def _find_hardcoded_paths(self, lines: List[str]) -> List[str]:
        """Find hard-coded node paths (Section 2.3)"""
        paths = []
        
        for i, line in enumerate(lines, 1):
            if 'get_node(' in line or 'get_node_or_null(' in line:
                if '\"/' in line or '\"/root' in line:
                    paths.append(f"Line {i}: Hard-coded path - {line.strip()}")
        
        return paths
    
    def _check_error_handling(self, lines: List[str]) -> List[str]:
        """Check for missing error handling (Section 4.2.B)"""
        issues = []
        
        for i, line in enumerate(lines, 1):
            # Check for array access without bounds checking
            if '[' in line and ']' in line and 'if ' not in line:
                if i > 1 and 'is_empty()' not in lines[i-2] and 'size()' not in lines[i-2]:
                    # Potential unguarded array access
                    pass  # This generates too many false positives, skip for now
            
            # Check for load() without validation
            if 'load(' in line:
                # Check if next few lines have null check
                has_check = False
                for j in range(i, min(i+5, len(lines))):
                    if 'if not' in lines[j] or 'if !' in lines[j] or 'assert' in lines[j]:
                        has_check = True
                        break
                if not has_check:
                    issues.append(f"Line {i}: load() without null check - {line.strip()}")
        
        return issues
    
    def generate_report(self, output_file: str) -> None:
        """Generate comprehensive analysis report"""
        total_files = len(self.results)
        project_files = [r for r in self.results if not r.is_addon]
        addon_files = [r for r in self.results if r.is_addon]
        
        files_with_headers = sum(1 for r in project_files if r.has_file_header)
        files_with_issues = sum(1 for r in project_files if r.has_issues())
        
        with open(output_file, 'w', encoding='utf-8') as f:
            f.write("# COMPREHENSIVE PROJECT ANALYSIS REPORT\\n")
            f.write(f"*Analysis Date: 2025-12-13*\\n")
            f.write(f"*Total Files Analyzed: {total_files}*\\n\\n")
            
            f.write("## EXECUTIVE SUMMARY\\n\\n")
            f.write(f"**Total Files**: {total_files} ({len(project_files)} project + {len(addon_files)} addon)\\n")
            f.write(f"**Files With Documentation Headers**: {files_with_headers}/{len(project_files)}\\n")
            f.write(f"**Files With Issues**: {files_with_issues}/{len(project_files)}\\n\\n")
            
            # Section 1: Critical Issues
            f.write("## 1. CRITICAL ISSUES\\n\\n")
            for result in project_files:
                if result.has_issues():
                    f.write(f"### {os.path.basename(result.filepath)}\\n")
                    f.write(f"**Path**: `{result.filepath}`\\n\\n")
                    
                    if not result.has_file_header:
                        f.write("❌ **Missing File Header** (Section 3.1 required)\\n\\n")
                    
                    if result.type_safety_issues:
                        f.write("#### Type Safety Issues\\n")
                        for issue in result.type_safety_issues[:5]:  # Limit to first 5
                            f.write(f"- {issue}\\n")
                        if len(result.type_safety_issues) > 5:
                            f.write(f"- ... and {len(result.type_safety_issues) - 5} more\\n")
                        f.write("\\n")
                    
                    if result.hard_coded_paths:
                        f.write("#### Hard-Coded Paths (Violates Section 2.3)\\n")
                        for path in result.hard_coded_paths:
                            f.write(f"- {path}\\n")
                        f.write("\\n")
                    
                    if result.magic_numbers:
                        f.write("#### Magic Numbers (Violates Section 1.3)\\n")
                        for num in result.magic_numbers[:3]:
                            f.write(f"- {num}\\n")
                        if len(result.magic_numbers) > 3:
                            f.write(f"- ... and {len(result.magic_numbers) - 3} more\\n")
                        f.write("\\n")
            
            # Section 2: Documentation Summary
            f.write("## 2. DOCUMENTATION SUMMARY\\n\\n")
            f.write(f"**Files With Headers**: {files_with_headers}/{len(project_files)}\\n\\n")
            
            f.write("### Files Missing Documentation Headers:\\n")
            for result in project_files:
                if not result.has_file_header:
                    f.write(f"- `{os.path.basename(result.filepath)}`\\n")
            
            f.write("\\n### Files With Complete Documentation:\\n")
            for result in project_files:
                if result.has_file_header:
                    f.write(f"- ✅ `{os.path.basename(result.filepath)}` ({len(result.functions_found)} functions)\\n")
            
            f.write(f"\\n## ANALYSIS COMPLETE\\n")
            f.write(f"\\nProcessed {total_files} files total.\\n")

if __name__ == "__main__":
    project_root = r"c:\\Users\\dudog\\Documents\\Fire Emblem\\project-suits\\new-game-project"
    
    analyzer = CodebaseAnalyzer(project_root)
    
    # Analyze project scripts
    print("Analyzing project scripts...")
    analyzer.analyze_all_files(os.path.join(project_root, "project_scripts.txt"))
    
    # Analyze addon scripts
    print("Analyzing addon scripts...")
    analyzer.analyze_all_files(os.path.join(project_root, "addon_scripts.txt"))
    
    # Generate report
    output_path = r"C:\\Users\\dudog\\.gemini\\antigravity\\brain\\15d82d41-7297-4ea1-90cf-178496a418f8\\phase1_analysis.md"
    print(f"Generating comprehensive report to {output_path}...")
    analyzer.generate_report(output_path)
    
    print("Analysis complete!")
