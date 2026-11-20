"""Minimal Markdown -> PDF converter for this project's two report documents.
Handles: #/## headings, pipe tables, bold **text**, and plain paragraphs/lists.
Not a general-purpose converter -- written narrowly for these two files.
"""
import os
import re
import sys
from reportlab.lib.pagesizes import LETTER
from reportlab.lib.utils import ImageReader
from reportlab.lib.styles import getSampleStyleSheet, ParagraphStyle
from reportlab.lib.units import inch
from reportlab.lib import colors
from reportlab.platypus import (
    SimpleDocTemplate, Paragraph, Spacer, Table, TableStyle, Image
)

BASE_DIR = "."

styles = getSampleStyleSheet()
styles.add(ParagraphStyle(name="H1", fontSize=16, spaceAfter=10, spaceBefore=4, fontName="Helvetica-Bold"))
styles.add(ParagraphStyle(name="H2", fontSize=13, spaceAfter=8, spaceBefore=12, fontName="Helvetica-Bold"))
styles.add(ParagraphStyle(name="H3", fontSize=11, spaceAfter=6, spaceBefore=8, fontName="Helvetica-Bold"))
styles.add(ParagraphStyle(name="Body9", parent=styles["Normal"], fontSize=9.5, leading=13, spaceAfter=8))
styles.add(ParagraphStyle(name="Meta", parent=styles["Normal"], fontSize=9, textColor=colors.grey, spaceAfter=14))


def inline(text):
    text = text.replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;")
    text = re.sub(r"\*\*(.+?)\*\*", r"<b>\1</b>", text)
    text = re.sub(r"(?<!\*)\*([^*]+?)\*(?!\*)", r"<i>\1</i>", text)
    text = re.sub(r"`(.+?)`", r"<font face='Courier'>\1</font>", text)
    return text


def parse_table(lines, i):
    header = [c.strip() for c in lines[i].strip().strip("|").split("|")]
    i += 2  # skip separator row
    rows = [header]
    while i < len(lines) and lines[i].strip().startswith("|"):
        rows.append([c.strip() for c in lines[i].strip().strip("|").split("|")])
        i += 1
    return rows, i


def build_story(md_text):
    story = []
    lines = md_text.split("\n")
    i = 0
    first = True
    while i < len(lines):
        line = lines[i]
        stripped = line.strip()
        if stripped == "":
            i += 1
            continue
        if stripped.startswith("# "):
            story.append(Paragraph(inline(stripped[2:]), styles["H1"]))
            i += 1
            continue
        if stripped.startswith("## "):
            story.append(Paragraph(inline(stripped[3:]), styles["H2"]))
            i += 1
            continue
        if stripped.startswith("### "):
            story.append(Paragraph(inline(stripped[4:]), styles["H3"]))
            i += 1
            continue
        img = re.match(r"^!\[[^\]]*\]\(([^)]+)\)$", stripped)
        if img:
            path = os.path.join(BASE_DIR, img.group(1))
            w, h = ImageReader(path).getSize()
            width = 6.5 * inch
            story.append(Spacer(1, 4))
            story.append(Image(path, width=width, height=width * h / w))
            story.append(Spacer(1, 10))
            i += 1
            continue
        if first and "|" not in stripped:
            story.append(Paragraph(inline(stripped), styles["Meta"]))
            first = False
            i += 1
            continue
        first = False
        if stripped.startswith("|"):
            rows, i = parse_table(lines, i)
            t = Table([[Paragraph(inline(c), styles["Body9"]) for c in r] for r in rows], hAlign="LEFT")
            t.setStyle(TableStyle([
                ("GRID", (0, 0), (-1, -1), 0.5, colors.grey),
                ("BACKGROUND", (0, 0), (-1, 0), colors.whitesmoke),
                ("FONTNAME", (0, 0), (-1, 0), "Helvetica-Bold"),
                ("VALIGN", (0, 0), (-1, -1), "TOP"),
            ]))
            story.append(t)
            story.append(Spacer(1, 10))
            continue
        if re.match(r"^\d+\. ", stripped) or stripped.startswith("- "):
            ordered = bool(re.match(r"^\d+\. ", stripped))
            rows = []
            n = 1
            while i < len(lines) and (re.match(r"^\d+\. ", lines[i].strip()) or lines[i].strip().startswith("- ")):
                item_lines = [re.sub(r"^(\d+\. |- )", "", lines[i].strip())]
                i += 1
                # pull in wrapped continuation lines belonging to this item
                while (i < len(lines) and lines[i].strip() != ""
                       and not re.match(r"^\d+\. ", lines[i].strip())
                       and not lines[i].strip().startswith(("- ", "#", "|"))):
                    item_lines.append(lines[i].strip())
                    i += 1
                txt = " ".join(item_lines)
                prefix = f"{n}. " if ordered else "• "
                rows.append(Paragraph(inline(prefix + txt), styles["Body9"]))
                n += 1
            for r in rows:
                story.append(r)
            story.append(Spacer(1, 6))
            continue
        # paragraph (may wrap multiple source lines)
        para_lines = [stripped]
        i += 1
        while i < len(lines) and lines[i].strip() != "" and not lines[i].strip().startswith(("#", "|", "- ")) and not re.match(r"^\d+\. ", lines[i].strip()):
            para_lines.append(lines[i].strip())
            i += 1
        story.append(Paragraph(inline(" ".join(para_lines)), styles["Body9"]))
    return story


def convert(md_path, pdf_path):
    global BASE_DIR
    BASE_DIR = os.path.dirname(os.path.abspath(md_path))  # image paths are relative to the .md file
    with open(md_path, "r", encoding="utf-8") as f:
        text = f.read()
    doc = SimpleDocTemplate(pdf_path, pagesize=LETTER,
                             leftMargin=0.75 * inch, rightMargin=0.75 * inch,
                             topMargin=0.75 * inch, bottomMargin=0.75 * inch)
    doc.build(build_story(text))
    print(f"Wrote {pdf_path}")


if __name__ == "__main__":
    convert(sys.argv[1], sys.argv[2])
