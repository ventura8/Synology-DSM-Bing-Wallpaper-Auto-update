import sys
import xml.etree.ElementTree as ET
import os

# Force UTF-8 for stdout
sys.stdout.reconfigure(encoding='utf-8')

def get_uncovered_lines(cls):
    uncovered = []
    lines_el = cls.find("lines")
    if lines_el is None:
        return "N/A"
    
    for line in lines_el.findall("line"):
        if int(float(line.get("hits", 0))) == 0:
            uncovered.append(int(line.get("number")))
    
    if not uncovered:
        return "None"
    
    # Group into ranges for readability
    uncovered.sort()
    ranges = []
    if not uncovered: return "None"
    
    start = uncovered[0]
    end = uncovered[0]
    for i in range(1, len(uncovered)):
        if uncovered[i] == end + 1:
            end = uncovered[i]
        else:
            ranges.append(f"{start}-{end}" if start != end else f"{start}")
            start = uncovered[i]
            end = uncovered[i]
    ranges.append(f"{start}-{end}" if start != end else f"{start}")
    
    return ", ".join(ranges)

def generate_markdown_table(xml_file):
    if not os.path.exists(xml_file):
        print(f"Error: {xml_file} not found.")
        sys.exit(1)

    try:
        tree = ET.parse(xml_file)
        root = tree.getroot()
    except ET.ParseError as e:
        print(f"Error parsing XML: {e}")
        sys.exit(1)

    # Header
    # Root attributes for overall rates
    total_line_rate = float(root.get("line-rate", 0)) * 100
    total_branch_rate = float(root.get("branch-rate", 0)) * 100
    lines_covered = int(float(root.get("lines-covered", 0)))
    lines_valid = int(float(root.get("lines-valid", 0)))
    branches_covered = int(float(root.get("branches-covered", 0)))
    branches_valid = int(float(root.get("branches-valid", 0)))

    # Header & Summary
    markdown = "# 📊 Code Coverage Report\n\n"
    markdown += "### 📈 Overall Statistics\n"
    markdown += f"- **Total Line Coverage:** `{total_line_rate:.1f}%` ({lines_covered}/{lines_valid})\n"
    markdown += f"- **Total Branch Coverage:** `{total_branch_rate:.1f}%` ({branches_covered}/{branches_valid})\n\n"
    
    markdown += "### 📄 Detailed Per-File Coverage\n\n"
    markdown += "| File | Line Coverage | Branch Coverage | Uncovered Lines |\n"
    markdown += "| :--- | :---: | :---: | :--- |\n"
    
    # Iterate over packages and classes
    for package in root.findall(".//package"):
        for cls in package.findall(".//class"):
            filename = cls.get("filename")
            
            # Rate calc
            line_rate = float(cls.get("line-rate", 0))
            branch_rate = float(cls.get("branch-rate", 0))
            uncovered_list = get_uncovered_lines(cls)
            
            line_pct = f"{line_rate * 100:.1f}%"
            branch_pct = f"{branch_rate * 100:.1f}%"
            
            # Icon calc
            icon = "🔴"
            if line_rate > 0.95:
                icon = "🟢"
            elif line_rate > 0.90:
                icon = "🟡"

            markdown += f"| {icon} `{filename}` | {line_pct} | {branch_pct} | `{uncovered_list}` |\n"

    print(markdown)

    # Append to GITHUB_STEP_SUMMARY if var exists
    summary_file = os.environ.get("GITHUB_STEP_SUMMARY")
    if summary_file:
        with open(summary_file, "a", encoding="utf-8") as f:
            f.write("\n" + markdown + "\n")

if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Usage: python3 generate_detailed_coverage.py <path_to_cobertura.xml>")
        sys.exit(1)
    
    generate_markdown_table(sys.argv[1])
