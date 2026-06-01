#!/usr/bin/env python3
import sys, json
from PIL import Image, ImageDraw, ImageFont

SF   = "/System/Library/Fonts/SFNS.ttf"
HIRA = "/System/Library/Fonts/ヒラギノ角ゴシック W7.ttc"
KO   = "/System/Library/Fonts/AppleSDGothicNeo.ttc"

MASK_TOP, MASK_BOT = 100, 712     # fully covers original text (149–666), stops before phone (~760)
BG = (18, 18, 18)                 # matches source background exactly

def make_font(size, kind, weight):
    if kind == "ja": return ImageFont.truetype(HIRA, size)
    if kind == "ko":
        try: return ImageFont.truetype(KO, size, index=6)   # heavier face
        except: return ImageFont.truetype(KO, size)
    f = ImageFont.truetype(SF, size)
    try: f.set_variation_by_name(weight)
    except: pass
    return f

def wrap(draw, text, max_w, f, cjk=False):
    if cjk and (" " not in text or draw.textlength(text, font=f) > max_w and len(text.split())==1):
        lines, cur = [], ""
        for ch in text:
            if draw.textlength(cur+ch, font=f) <= max_w: cur += ch
            else:
                if cur: lines.append(cur)
                cur = ch
        if cur: lines.append(cur)
        return lines
    words, lines, cur = text.split(), [], ""
    for w in words:
        t = (cur+" "+w).strip()
        if draw.textlength(t, font=f) <= max_w: cur = t
        else:
            if cur: lines.append(cur)
            cur = w
    if cur: lines.append(cur)
    return lines

def fit(draw, text, max_w, size, kind, weight, max_lines):
    cjk = kind in ("ja","ko")
    while size > 16:
        f = make_font(size, kind, weight)
        lines = wrap(draw, text, max_w, f, cjk)
        if len(lines) <= max_lines and all(draw.textlength(l, font=f) <= max_w for l in lines):
            return lines, f
        size -= 3
    return lines, f

def block_h(lines, f, gap):
    asc, desc = f.getmetrics()
    return int((asc+desc)*gap) * len(lines)

def draw_block(draw, lines, f, cx, top, color, gap):
    asc, desc = f.getmetrics(); lh = int((asc+desc)*gap); y = top
    for ln in lines:
        w = draw.textlength(ln, font=f)
        draw.text((cx - w/2, y), ln, font=f, fill=color); y += lh
    return y

def localize(src, out, headline, subtext, kind="lat", upper=True):
    im = Image.open(src).convert("RGB"); W,H = im.size
    d = ImageDraw.Draw(im)
    d.rectangle([0, MASK_TOP, W, MASK_BOT], fill=BG)
    cx = W//2
    htxt = headline.upper() if (upper and kind=="lat") else headline
    hl, hf = fit(d, htxt, int(W*0.86), 116, kind, "Black", 2)
    sl, sf = fit(d, subtext, int(W*0.82), 44, kind, "Semibold", 2)
    hgap, sgap = 1.10, 1.16
    hh = block_h(hl, hf, hgap); sh = block_h(sl, sf, sgap)
    total = hh + 26 + sh
    top = MASK_TOP + ((MASK_BOT - MASK_TOP) - total)//2
    bottom = draw_block(d, hl, hf, cx, top, (245,245,247), hgap)
    draw_block(d, sl, sf, cx, bottom + 26, (150,150,168), sgap)
    im.save(out); print("ok", out)

if __name__ == "__main__":
    for item in json.load(open(sys.argv[1])):
        localize(item["src"], item["out"], item["headline"], item["subtext"],
                 item.get("kind","lat"), item.get("upper",True))
