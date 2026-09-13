#!/usr/bin/env python3
"""Keeps the READMEs and the website in step with the changelog.

CHANGELOG.md (English) and CHANGELOG.tr.md (Turkish) are the only files that
hold release notes. This script rewrites the generated blocks between
`<!-- changelog:NAME:start -->` and `<!-- changelog:NAME:end -->`:

  README.md, README.tr.md   the latest release, under "What's new"
  docs/index.html           every release, and the header link to them

Usage:
  python3 scripts/changelog.py                     rewrite the blocks
  python3 scripts/changelog.py --check             exit 1 if any is stale
  python3 scripts/changelog.py --notes 1.1.0       one release as Markdown,
                                   [--lang tr]      e.g. for a GitHub release
"""
import argparse
import html
import pathlib
import re
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
REPO_URL = "https://github.com/lunanoir21/quickshell-quay"

RELEASE = re.compile(r"^## \[(?P<version>[^\]]+)\](?:\s+-\s+(?P<date>\d{4}-\d{2}-\d{2}))?\s*$")
GROUP = re.compile(r"^### (?P<name>.+?)\s*$")
BULLET = re.compile(r"^- (?P<text>.+)$")
LINK_DEFINITION = re.compile(r"^\[[^\]]+\]:\s")

LANGS = {
    "en": {
        "source": "CHANGELOG.md",
        "readme": "README.md",
        "title": "What's new in {version}",
        "meta": "_Released {date} · [Full changelog]({source})_",
    },
    "tr": {
        "source": "CHANGELOG.tr.md",
        "readme": "README.tr.md",
        "title": "{version} sürümündeki yenilikler",
        "meta": "_{date} tarihinde yayınlandı · [Tüm değişiklik günlüğü]({source})_",
    },
}


def fail(message):
    sys.exit(f"changelog: {message}")


def parse(path):
    """Releases in file order: [{version, date, groups: [{name, items}]}]."""
    releases = []
    release = group = None

    for number, raw in enumerate(path.read_text(encoding="utf-8").splitlines(), 1):
        line = raw.rstrip()

        match = RELEASE.match(line)
        if match:
            release = {"version": match["version"], "date": match["date"], "groups": []}
            releases.append(release)
            group = None
            continue
        if release is None or LINK_DEFINITION.match(line):
            continue

        match = GROUP.match(line)
        if match:
            group = {"name": match["name"], "items": []}
            release["groups"].append(group)
            continue

        match = BULLET.match(line)
        if match:
            if group is None:
                fail(f"{path.name}:{number}: a bullet needs a ### group above it")
            group["items"].append(match["text"].strip())
            continue

        # A bullet wrapped onto the next line, indented.
        if line.startswith("  ") and group is not None and group["items"]:
            group["items"][-1] += " " + line.strip()

    return [r for r in releases if any(g["items"] for g in r["groups"])]


def released(releases, path):
    dated = [r for r in releases if r["date"]]
    if not dated:
        fail(f"{path.name} has no dated release")
    return dated


def inline(text):
    """The Markdown the changelog uses: `code`, **bold** and [links](url)."""
    out = []
    for part in re.split(r"(`[^`]+`)", text):
        if len(part) > 1 and part.startswith("`") and part.endswith("`"):
            out.append("<code>" + html.escape(part[1:-1]) + "</code>")
            continue
        escaped = html.escape(part, quote=False)
        escaped = re.sub(r"\*\*(.+?)\*\*", r"<strong>\1</strong>", escaped)
        escaped = re.sub(r"\[([^\]]+)\]\(([^)\s]+)\)",
                         lambda m: f'<a href="{html.escape(m[2])}">{m[1]}</a>', escaped)
        out.append(escaped)
    return "".join(out)


def notes(release):
    lines = []
    for group in release["groups"]:
        if not group["items"]:
            continue
        lines += [f"**{group['name']}**", ""]
        lines += [f"- {item}" for item in group["items"]]
        lines.append("")
    return "\n".join(lines).rstrip() + "\n"


def readme_block(release, lang):
    config = LANGS[lang]
    head = [
        "## " + config["title"].format(version=release["version"]),
        "",
        config["meta"].format(date=release["date"], source=config["source"]),
        "",
    ]
    return "\n".join(head) + "\n" + notes(release) + "\n"


def site_block(releases, latest):
    lines = [
        '<section class="block" id="changelog" aria-labelledby="changelog-title">',
        '  <h2 id="changelog-title">Changelog</h2>',
        f'  <p class="section-lede">Every release, newest first. The same notes live in '
        f'<a href="{REPO_URL}/blob/main/CHANGELOG.md">CHANGELOG.md</a>.</p>',
        '  <div class="releases">',
    ]
    for release in releases:
        is_latest = release is latest
        slug = "v" + re.sub(r"[^0-9a-z]+", "-", release["version"].lower()).strip("-")
        lines.append(f'    <article class="release{" is-latest" if is_latest else ""}" id="{slug}">')
        lines.append('      <header class="release-head">')
        lines.append(f'        <h3>{html.escape(release["version"])}</h3>')
        if release["date"]:
            lines.append(f'        <time datetime="{release["date"]}">{release["date"]}</time>')
        if is_latest:
            lines.append('        <span class="release-tag">Latest</span>')
        lines.append('      </header>')
        lines.append('      <div class="release-body">')
        for group in release["groups"]:
            if not group["items"]:
                continue
            lines.append('        <div class="release-group">')
            lines.append(f'          <p class="release-kind">{html.escape(group["name"])}</p>')
            lines.append('          <ul class="changes">')
            lines += [f'            <li>{inline(item)}</li>' for item in group["items"]]
            lines.append('          </ul>')
            lines.append('        </div>')
        lines.append('      </div>')
        lines.append('    </article>')
    lines += ['  </div>', '</section>']
    return "\n".join(lines) + "\n"


def replace_block(text, name, body, path):
    pattern = re.compile(
        rf"^(?P<indent>[ \t]*)<!-- changelog:{name}:start -->\n.*?^[ \t]*<!-- changelog:{name}:end -->$",
        re.M | re.S)
    matches = list(pattern.finditer(text))
    if len(matches) != 1:
        fail(f"{path.relative_to(ROOT)} needs exactly one changelog:{name} block, found {len(matches)}")
    match = matches[0]
    indent = match["indent"]
    body_lines = [indent + line if line else "" for line in body.rstrip("\n").split("\n")]
    if body.endswith("\n\n"):
        body_lines.append("")
    block = (f"{indent}<!-- changelog:{name}:start -->\n"
             + "\n".join(body_lines)
             + f"\n{indent}<!-- changelog:{name}:end -->")
    return text[:match.start()] + block + text[match.end():]


def build():
    """{path: (current text, generated text)} for every file with a block."""
    parsed = {lang: parse(ROOT / config["source"]) for lang, config in LANGS.items()}

    versions = {lang: [r["version"] for r in releases] for lang, releases in parsed.items()}
    if len(set(map(tuple, versions.values()))) != 1:
        fail("CHANGELOG.md and CHANGELOG.tr.md list different versions: "
             + "; ".join(f"{lang}: {', '.join(v)}" for lang, v in versions.items()))

    outputs = {}
    for lang, config in LANGS.items():
        source = ROOT / config["source"]
        latest = released(parsed[lang], source)[0]
        path = ROOT / config["readme"]
        text = path.read_text(encoding="utf-8")
        outputs[path] = (text, replace_block(text, "readme", readme_block(latest, lang), path))

    english = parsed["en"]
    latest = released(english, ROOT / "CHANGELOG.md")[0]
    site = ROOT / "docs" / "index.html"
    text = site.read_text(encoding="utf-8")
    generated = replace_block(text, "site", site_block(english, latest), site)
    generated = replace_block(
        generated, "site-link",
        f'<a class="top-link" href="#changelog">What\'s new in {html.escape(latest["version"])}</a>\n', site)
    outputs[site] = (text, generated)
    return outputs


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--check", action="store_true", help="fail if a generated block is out of date")
    parser.add_argument("--notes", metavar="VERSION", help="print one release's notes as Markdown")
    parser.add_argument("--lang", choices=sorted(LANGS), default="en", help="language for --notes")
    args = parser.parse_args()

    if args.notes:
        source = ROOT / LANGS[args.lang]["source"]
        for release in parse(source):
            if release["version"] == args.notes:
                sys.stdout.write(notes(release))
                return 0
        fail(f"{source.name} has no release {args.notes}")

    outputs = build()
    stale = [path for path, (current, generated) in outputs.items() if current != generated]

    if args.check:
        for path in stale:
            print(f"out of date: {path.relative_to(ROOT)}")
        if stale:
            print("run: python3 scripts/changelog.py")
            return 1
        print("changelog blocks are up to date")
        return 0

    for path in stale:
        path.write_text(outputs[path][1], encoding="utf-8")
        print(f"updated {path.relative_to(ROOT)}")
    if not stale:
        print("nothing to update")
    return 0


if __name__ == "__main__":
    sys.exit(main())
