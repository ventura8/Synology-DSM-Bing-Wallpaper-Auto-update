import os
import re
import sys
import xml.dom.minidom
import xml.etree.ElementTree as ET
from pathlib import Path
from re import Match

REPO_ROOT = Path(__file__).resolve().parent.parent
SHELL_FUNCTION_PATTERN = re.compile(r"^\s*([A-Za-z_][A-Za-z0-9_]*)\s*\(\)\s*\{")
POWERSHELL_FUNCTION_PATTERN = re.compile(r"^\s*function\s+([A-Za-z_][A-Za-z0-9_-]*)\b", re.IGNORECASE)
SHELL_DECISION_PATTERN = re.compile(r"\b(if|elif|for|while|until|case)\b|&&|\|\|")
POWERSHELL_DECISION_PATTERN = re.compile(r"\b(if|elseif|for|foreach|while|switch|catch)\b", re.IGNORECASE)


def count_braces(line: str) -> int:
    return line.count("{") - line.count("}")


def collect_blocks(path: Path, pattern: re.Pattern[str]) -> list[list[str]]:
    blocks: list[list[str]] = []
    lines = path.read_text(encoding="utf-8").splitlines()
    index = 0

    while index < len(lines):
        match = pattern.match(lines[index])
        if match is None:
            index += 1
            continue

        block_lines = [lines[index]]
        brace_balance = count_braces(lines[index])
        index += 1

        while index < len(lines) and brace_balance > 0:
            block_lines.append(lines[index])
            brace_balance += count_braces(lines[index])
            index += 1

        blocks.append(block_lines)

    return blocks


def calculate_complexity(block_lines: list[str], decision_pattern: re.Pattern[str]) -> int:
    complexity = 1
    for line in block_lines:
        complexity += len(decision_pattern.findall(line))
    return complexity


def get_file_complexity(path: Path) -> int:
    if path.suffix == ".sh":
        blocks = collect_blocks(path, SHELL_FUNCTION_PATTERN)
        pattern = SHELL_DECISION_PATTERN
    elif path.suffix in {".ps1", ".psm1"}:
        blocks = collect_blocks(path, POWERSHELL_FUNCTION_PATTERN)
        pattern = POWERSHELL_DECISION_PATTERN
    else:
        return 0

    if not blocks:
        return 0

    return max(calculate_complexity(block_lines, pattern) for block_lines in blocks)


def load_coverage_root(xml_file: str) -> ET.Element:
    if not os.path.exists(xml_file):
        print(f"Error: {xml_file} not found")
        sys.exit(1)

    try:
        tree = ET.parse(xml_file)
    except ET.ParseError as error:
        print(f"Error parsing XML: {error}")
        sys.exit(1)

    return tree.getroot()


def require_packages(root: ET.Element) -> ET.Element:
    packages_el = root.find("packages")
    if packages_el is None:
        print("No <packages> element found")
        sys.exit(1)

    return packages_el


def set_workspace_source(root: ET.Element) -> None:
    sources = root.find("sources")
    if sources is None:
        sources = ET.SubElement(root, "sources")
    else:
        sources.clear()

    source = ET.SubElement(sources, "source")
    source.text = "/github/workspace"


def collect_classes(packages_el: ET.Element) -> list[ET.Element]:
    all_classes: list[ET.Element] = []
    for package in packages_el.findall("package"):
        classes_el = package.find("classes")
        if classes_el is None:
            continue
        all_classes.extend(classes_el.findall("class"))

    return all_classes


def normalize_filename(filename: str) -> str:
    if filename.startswith("/app/"):
        return filename[5:]
    if filename.startswith("app/"):
        return filename[4:]
    return filename


def resolve_complexity(filename: str, fallback: str | None) -> str:
    if not filename:
        return fallback or "0.0"

    file_path = REPO_ROOT / Path(filename)
    if not file_path.exists():
        return fallback or "0.0"

    complexity = get_file_complexity(file_path)
    if complexity <= 0:
        return fallback or "0.0"

    return f"{float(complexity):.1f}"


def rebuild_packages(packages_el: ET.Element, all_classes: list[ET.Element]) -> None:
    packages_el.clear()

    for cls in all_classes:
        filename = normalize_filename(cls.get("filename") or "")
        cls.set("filename", filename)
        complexity = resolve_complexity(filename, cls.get("complexity"))
        cls.set("complexity", complexity)

        new_pkg = ET.SubElement(packages_el, "package")
        new_pkg.set("name", filename)

        for attr in ["line-rate", "branch-rate"]:
            new_pkg.set(attr, cls.get(attr) or "0.0")
        new_pkg.set("complexity", complexity)

        new_classes = ET.SubElement(new_pkg, "classes")
        new_classes.append(cls)


def set_root_complexity(root: ET.Element, all_classes: list[ET.Element]) -> None:
    complexities = [float(cls.get("complexity", "0") or 0) for cls in all_classes]
    if complexities:
        root.set("complexity", f"{max(complexities):.1f}")


def fix_coverage_tag(match: Match[str]) -> str:
    attrs = {}
    for key, value in re.findall(r'(\S+)="([^"]*)"', match.group(1)):
        attrs[key] = value

    ordered_keys = [
        "lines-valid",
        "lines-covered",
        "line-rate",
        "branches-valid",
        "branches-covered",
        "branch-rate",
        "timestamp",
        "complexity",
        "version",
    ]

    new_tag = "<coverage"
    for key in ordered_keys:
        new_tag += f' {key}="{attrs.get(key, "0")}"'

    for key, value in attrs.items():
        if key not in ordered_keys:
            new_tag += f' {key}="{value}"'
    new_tag += ">"
    return new_tag


def render_coverage_xml(root: ET.Element) -> str:
    xml_str = ET.tostring(root, encoding="unicode")
    dom = xml.dom.minidom.parseString(xml_str)
    pretty_xml = dom.toprettyxml(indent="  ")
    pretty_xml = "\n".join(line for line in pretty_xml.splitlines() if line.strip())

    if pretty_xml.startswith("<?xml"):
        pretty_xml = pretty_xml.split("\n", 1)[1]

    pretty_xml = re.sub(r"<coverage([^>]*)>", fix_coverage_tag, pretty_xml, count=1)
    return '<?xml version="1.0" encoding="UTF-8"?>\n' + pretty_xml + "\n"


def generate_badge(line_rate: str, output_path: str = "badge.svg") -> None:
    try:
        coverage = float(line_rate) * 100
    except ValueError:
        coverage = 0.0

    color = "#e05d44"  # red
    if coverage >= 95:
        color = "#4c1"  # brightgreen
    elif coverage >= 90:
        color = "#97ca00"  # green
    elif coverage >= 75:
        color = "#dfb317"  # yellow
    elif coverage >= 50:
        color = "#fe7d37"  # orange

    coverage_str = f"{int(coverage)}%"

    # Calculate widths based on text length
    # Heuristic: ~7.5px per character for Verdana 11px
    # "Coverage": ~59-61px

    label_text = "Coverage"
    value_text = coverage_str

    # Estimate widths
    # 6px approx per char + padding
    label_width = 61
    value_width = int(len(value_text) * 8.5) + 10  # 4 chars (100%) -> 34+10=44px. 3 chars -> 25+10=35px

    total_width = label_width + value_width

    # Center positions
    label_x = label_width / 2.0 * 10
    value_x = (label_width + value_width / 2.0) * 10

    svg = f"""<svg xmlns="http://www.w3.org/2000/svg" width="{total_width}" height="20" role="img" aria-label="{label_text}: {value_text}">
    <title>{label_text}: {value_text}</title>
    <linearGradient id="s" x2="0" y2="100%">
        <stop offset="0" stop-color="#bbb" stop-opacity=".1"/>
        <stop offset="1" stop-opacity=".1"/>
    </linearGradient>
    <clipPath id="r">
        <rect width="{total_width}" height="20" rx="3" fill="#fff"/>
    </clipPath>
    <g clip-path="url(#r)">
        <rect width="{label_width}" height="20" fill="#555"/>
        <rect x="{label_width}" width="{value_width}" height="20" fill="{color}"/>
        <rect width="{total_width}" height="20" fill="url(#s)"/>
    </g>
    <g
        fill="#fff"
        text-anchor="middle"
        font-family="Verdana,Geneva,DejaVu Sans,sans-serif"
        text-rendering="geometricPrecision"
        font-size="110"
    >
        <text
            aria-hidden="true"
            x="{int(label_x)}"
            y="150"
            fill="#010101"
            fill-opacity=".3"
            transform="scale(.1)"
            textLength="{label_width*10 - 100}"
        >{label_text}</text>
        <text x="{int(label_x)}" y="140" transform="scale(.1)" fill="#fff" textLength="{label_width*10 - 100}">{label_text}</text>
        <text
            aria-hidden="true"
            x="{int(value_x)}"
            y="150"
            fill="#010101"
            fill-opacity=".3"
            transform="scale(.1)"
            textLength="{value_width*10 - 100}"
        >{value_text}</text>
        <text x="{int(value_x)}" y="140" transform="scale(.1)" fill="#fff" textLength="{value_width*10 - 100}">{value_text}</text>
    </g>
</svg>"""

    with open(output_path, "w", encoding="utf-8") as f:
        f.write(svg + "\n")
    print(f"Generated badge: {output_path} ({coverage_str})")


def transform_coverage(xml_file: str) -> None:
    root = load_coverage_root(xml_file)

    # Extract total line-rate for badge before processing
    root_line_rate = root.get("line-rate", "0")
    generate_badge(root_line_rate)

    packages_el = require_packages(root)
    set_workspace_source(root)
    all_classes = collect_classes(packages_el)
    rebuild_packages(packages_el, all_classes)
    set_root_complexity(root, all_classes)

    # Reset timestamp to 0 to avoid future/invalid date issues
    root.set("timestamp", "0")
    final_xml = render_coverage_xml(root)

    # Write to file
    with open(xml_file, "w", encoding="utf-8") as f:
        f.write(final_xml)

    print(f"Successfully transformed {xml_file}: Split {len(all_classes)} classes into separate packages.")


if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Usage: python transform_coverage.py <cobertura.xml>")
        sys.exit(1)

    transform_coverage(sys.argv[1])
