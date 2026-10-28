"""Baja la wiki de SuperCombo de SF3 3rd Strike (vía archive.org: el sitio vivo tiene Cloudflare) a texto.

  python -I tools\\wiki_scrape.py            -> data\\sfiii3\\wiki\\<pagina>.md + index.txt

Recorre la página principal y todas las subpáginas "Street_Fighter_3:_3rd_Strike/..." que encuentre (BFS, 2 niveles).
Conserva títulos, listas y tablas como texto plano para destilarlo después en conocimiento por personaje.
"""
import gzip
import html
import os
import re
import sys
import time
import urllib.parse
import urllib.request

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "data", "sfiii3", "wiki")
BASE = "https://wiki.supercombo.gg/w/"
START = "Street_Fighter_3:_3rd_Strike"
ARCH = "https://web.archive.org/web/2025id_/"
UA = {"User-Agent": "Mozilla/5.0 (CIPHER research; personal use)"}


def fetch(page):
    url = ARCH + BASE + urllib.parse.quote(page, safe=":/_()'")
    for attempt in range(4):
        try:
            with urllib.request.urlopen(urllib.request.Request(url, headers=UA), timeout=90) as r:
                data = r.read()
                if data[:2] == b"\x1f\x8b":                # "id_" devuelve los bytes originales: gzip
                    data = gzip.decompress(data)
                elif data[:4] == b"\x28\xb5\x2f\xfd":      # ... o zstd (Sean/Q Strategy)
                    import zstandard
                    data = zstandard.ZstdDecompressor().decompressobj().decompress(data)
                return data.decode("utf-8", "replace")
        except Exception as e:  # archive.org a veces corta: reintentar
            err = e
            time.sleep(3 + attempt * 4)
    print("  FALLO", page, err)
    return None


def links(raw):
    out = set()
    for m in re.finditer(r'href="(?:https?://web\.archive\.org/web/\d+(?:id_)?/)?(?:https?://wiki\.supercombo\.gg)?/w/(Street_Fighter_3:_3rd_Strike[^"#?]*)"', raw):
        p = html.unescape(urllib.parse.unquote(m.group(1)))
        if not any(x in p for x in ("action=", "Special:", "File:")):
            out.add(p)
    return out


def to_text(raw):
    m = re.search(r'<div[^>]+class="mw-parser-output"[^>]*>(.*)<div[^>]+class="printfooter"', raw, re.S)
    body = m.group(1) if m else raw
    body = re.sub(r"<(script|style|noscript)[^>]*>.*?</\1>", "", body, flags=re.S)
    body = re.sub(r"<h([1-6])[^>]*>(.*?)</h\1>", lambda x: "\n\n" + "#" * int(x.group(1)) + " " + x.group(2) + "\n", body, flags=re.S)
    body = re.sub(r"<li[^>]*>", "\n- ", body)
    body = re.sub(r"<tr[^>]*>", "\n| ", body)
    body = re.sub(r"</t[dh]>", " | ", body)
    body = re.sub(r"<br\s*/?>|</p>|</div>|</dd>|</dt>", "\n", body)
    body = re.sub(r"<img[^>]*alt=\"([^\"]*)\"[^>]*>", r" [\1] ", body)
    body = re.sub(r"<[^>]+>", "", body)
    body = html.unescape(body)
    body = re.sub(r"[ \t]+", " ", body)
    body = re.sub(r"\n\s*\n\s*\n+", "\n\n", body)
    return body.strip()


def fname(page):
    name = page.replace(START, "").strip("/") or "_main"
    return re.sub(r"[^\w\-]+", "_", name) + ".md"


def retry_missing(min_size=2000):
    """páginas que bajaron vacías (archive sin copia en esa fecha): probar otros años"""
    global ARCH
    for f in os.listdir(OUT):
        p = os.path.join(OUT, f)
        if not f.endswith(".md") or os.path.getsize(p) >= min_size:
            continue
        page = START + "/" + f[:-3].replace("_", " ").replace(" ", "_")
        page = START + "/" + f[:-3]
        for year in ("2024", "2023", "2022", "2021"):
            ARCH = "https://web.archive.org/web/%sid_/" % year
            raw = fetch(page)
            txt = to_text(raw) if raw else ""
            if len(txt) >= min_size:
                with open(p, "w", encoding="utf-8") as fh:
                    fh.write("# " + page + "\n\n" + txt + "\n")
                print("recuperada", page, year, len(txt), flush=True)
                break
            time.sleep(1)


def refetch(names):
    for f in names:
        global ARCH
        page = START + "/" + re.sub(r"_(Strategy|Combos|Matchups|Resources|Archive)$", r"/\1", f[:-3])
        raw = None
        for year in ("2025", "2024", "2023"):
            ARCH = "https://web.archive.org/web/%sid_/" % year
            raw = fetch(page)
            if raw and "Anubis" not in raw and "not a bot" not in raw:
                break
            raw = None
        if raw:
            with open(os.path.join(OUT, f), "w", encoding="utf-8") as fh:
                fh.write("# " + page + "\n\n" + to_text(raw) + "\n")
            print("rebajada", page, len(raw), flush=True)


def main():
    if "--refetch" in sys.argv:
        refetch(sys.argv[sys.argv.index("--refetch") + 1:])
        return
    if "--retry" in sys.argv:
        retry_missing()
        return
    os.makedirs(OUT, exist_ok=True)
    seen, queue, depth = set(), [START], {START: 0}
    index = []
    while queue:
        page = queue.pop(0)
        if page in seen:
            continue
        seen.add(page)
        raw = fetch(page)
        if not raw:
            continue
        txt = to_text(raw)
        path = os.path.join(OUT, fname(page))
        with open(path, "w", encoding="utf-8") as f:
            f.write("# " + page + "\n\n" + txt + "\n")
        index.append("%-70s %7d" % (page, len(txt)))
        print("ok %-60s %6d" % (page, len(txt)), flush=True)
        if depth[page] < 2:
            for p in sorted(links(raw)):
                if p not in depth:
                    depth[p] = depth[page] + 1
                    queue.append(p)
        time.sleep(1.0)
    with open(os.path.join(OUT, "index.txt"), "w", encoding="utf-8") as f:
        f.write("\n".join(index) + "\n")
    print("páginas:", len(index))


if __name__ == "__main__":
    sys.stdout.reconfigure(encoding="utf-8")
    main()
