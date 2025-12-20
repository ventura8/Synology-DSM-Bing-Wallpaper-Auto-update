import xml.etree.ElementTree as ET
import sys
import os

def generate_badge(line_rate, output_path="badge.svg"):
    try:
        coverage = float(line_rate) * 100
    except ValueError:
        coverage = 0.0

    color = "#e05d44" # red
    if coverage >= 95:
        color = "#4c1" # brightgreen
    elif coverage >= 90:
         color = "#97ca00" # green
    elif coverage >= 75:
        color = "#dfb317" # yellow
    elif coverage >= 50:
        color = "#fe7d37" # orange

    coverage_str = f"{int(coverage)}%"

    # Calculate widths based on text length
    # Heuristic: ~7.5px per character for Verdana 11px
    # "Coverage": ~59-61px

    label_text = "Coverage"
    value_text = coverage_str

    # Estimate widths
    # 6px approx per char + padding
    label_width = 61 
    value_width = int(len(value_text) * 8.5) + 10 # 4 chars (100%) -> 34+10=44px. 3 chars -> 25+10=35px

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
    <g fill="#fff" text-anchor="middle" font-family="Verdana,Geneva,DejaVu Sans,sans-serif" text-rendering="geometricPrecision" font-size="110">
        <text aria-hidden="true" x="{int(label_x)}" y="150" fill="#010101" fill-opacity=".3" transform="scale(.1)" textLength="{label_width*10 - 100}">{label_text}</text>
        <text x="{int(label_x)}" y="140" transform="scale(.1)" fill="#fff" textLength="{label_width*10 - 100}">{label_text}</text>
        <text aria-hidden="true" x="{int(value_x)}" y="150" fill="#010101" fill-opacity=".3" transform="scale(.1)" textLength="{value_width*10 - 100}">{value_text}</text>
        <text x="{int(value_x)}" y="140" transform="scale(.1)" fill="#fff" textLength="{value_width*10 - 100}">{value_text}</text>
    </g>
</svg>"""

    with open(output_path, "w") as f:
        f.write(svg)
    print(f"Generated badge: {output_path} ({coverage_str})")

def transform_coverage(xml_file):
    if not os.path.exists(xml_file):
        print(f"Error: {xml_file} not found")
        sys.exit(1)

    try:
        tree = ET.parse(xml_file)
        root = tree.getroot()
    except ET.ParseError as e:
        print(f"Error parsing XML: {e}")
        sys.exit(1)

    # Extract total line-rate for badge before processing
    root_line_rate = root.get("line-rate", "0")
    generate_badge(root_line_rate)

    packages_el = root.find('packages')
    if packages_el is None:
        print("No <packages> element found")
        sys.exit(1)

    # Fix sources to match GitHub Actions workspace or local mount
    sources = root.find('sources')
    if sources is None:
        sources = ET.SubElement(root, 'sources')
    else:
        sources.clear()
    
    source = ET.SubElement(sources, 'source')
    source.text = '/github/workspace'

    # Collect all classes from all existing packages
    all_classes = []
    for pkg in packages_el.findall('package'):
        classes_el = pkg.find('classes')
        if classes_el is not None:
            all_classes.extend(classes_el.findall('class'))

    # Clear existing packages
    packages_el.clear()

    # Create new package per class
    for cls in all_classes:
        filename = cls.get('filename')
        # Sanitize path for CI: strip /app/ which is the docker workdir
        if filename.startswith('/app/'):
            filename = filename[5:]
        elif filename.startswith('app/'):
            filename = filename[4:]
            
        cls.set('filename', filename)
        
        # Use relative filename as package name
        pkg_name = filename 
        
        new_pkg = ET.SubElement(packages_el, 'package')
        new_pkg.set('name', pkg_name)
        
        # Copy rate attributes
        for attr in ['line-rate', 'branch-rate', 'complexity']:
            if val := cls.get(attr):
                new_pkg.set(attr, val)
            else:
                new_pkg.set(attr, '0.0')

        new_classes = ET.SubElement(new_pkg, 'classes')
        new_classes.append(cls)

    # Reset timestamp to 0 to avoid future/invalid date issues
    root.set('timestamp', '0')

    # Use minidom to pretty print and avoid encoding issues
    import xml.dom.minidom
    xml_str = ET.tostring(root, encoding='unicode')
    dom = xml.dom.minidom.parseString(xml_str)
    pretty_xml = dom.toprettyxml(indent="  ")
    
    # Remove empty lines caused by minidom + existing whitespace
    pretty_xml = "\n".join([line for line in pretty_xml.splitlines() if line.strip()])
    
    # Strip any existing declaration to avoid duplicates
    if pretty_xml.startswith('<?xml'):
        pretty_xml = pretty_xml.split('\n', 1)[1]
    
    # CodeCoverageSummary requires specific attribute order for the coverage element
    # distinct from minidom's alphabetical sorting.
    # We reconstruct the coverage tag with keys in order:
    # lines-valid, lines-covered, line-rate, branches-valid, branches-covered, branch-rate, timestamp, complexity, version
    import re
    def fix_coverage_tag(match):
        attrs = {}
        # Simple regex to extract key="val"
        for k, v in re.findall(r'(\S+)="([^"]*)"', match.group(1)):
            attrs[k] = v
            
        ordered_keys = [
            'lines-valid', 'lines-covered', 'line-rate',
            'branches-valid', 'branches-covered', 'branch-rate',
            'timestamp', 'complexity', 'version'
        ]
        
        new_tag = '<coverage'
        for k in ordered_keys:
            val = attrs.get(k, '0') # Default to 0 if missing (e.g. branches-valid)
            new_tag += f' {k}="{val}"'
            
        # Add any remaining keys
        for k, v in attrs.items():
            if k not in ordered_keys:
                new_tag += f' {k}="{v}"'
        new_tag += '>'
        return new_tag

    pretty_xml = re.sub(r'<coverage([^>]*)>', fix_coverage_tag, pretty_xml, count=1)

    final_xml = '<?xml version="1.0" encoding="UTF-8"?>\n' + pretty_xml + '\n'

    # Write to file
    with open(xml_file, 'w', encoding='utf-8') as f:
        f.write(final_xml)
        
    print(f"Successfully transformed {xml_file}: Split {len(all_classes)} classes into separate packages.")

if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Usage: python transform_coverage.py <cobertura.xml>")
        sys.exit(1)
    
    transform_coverage(sys.argv[1])
