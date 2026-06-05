# tools/puzzle_generator/build_two_letter.py
"""Curate a clean 2-letter word pool from the raw TDK list (architecture.md §5.8).

Quality over quantity: the raw 1024 two-letter entries are mostly obscure /
dialectal / particle noise. We keep only a hand-curated WHITELIST of clear,
everyday Turkish words (each with a draft clue), intersected with the raw list
(so every kept word is TDK-attested) and passed through the profanity blacklist.

This is a one-off curation tool. It only REPORTS by default; it does not write
data/two_letter.json (that happens after human review).
"""

from __future__ import annotations

import sys
from pathlib import Path

from kelime_gen.schema import tr_upper
from kelime_gen.word_pool import load_blacklist

_ROOT = Path(__file__).resolve().parent
_RAW_PATH = _ROOT / "data" / "raw" / "tdk_words.txt"
_BLACKLIST_PATH = _ROOT / "data" / "raw" / "profanity_blacklist.txt"

_TR_ALPHABET = set("ABCÇDEFGĞHIİJKLMNOÖPRSŞTUÜVYZ")

# Hand-curated golden 2-letter words. Only clear, everyday, clue-able words.
# Obscure / archaic / slang / pure-particle syllables are intentionally absent.
WHITELIST: dict[str, str] = {
    "AD": "Kişiye verilen isim",
    "AĞ": "Balıkçının veya örümceğin örgüsü",
    "AH": "Sızlanma, yakınma ünlemi",
    "AK": "Beyaz, temiz",
    "AL": "Kırmızı renk",
    "AN": "Çok kısa zaman parçası",
    "AS": "İskambilde en değerli kâğıt",
    "AŞ": "Yemek, yiyecek",
    "AT": "Binek hayvanı",
    "AV": "Avlanan hayvan",
    "AY": "Gökyüzündeki uydumuz",
    "AZ": "Çok karşıtı",
    "EK": "Sona eklenen parça",
    "EL": "Kolun bilekten sonrası",
    "EN": "Bir yüzeyin genişliği",
    "ES": "Müzikte susma, durak",
    "EŞ": "Karı veya koca",
    "ET": "Kasaptan alınan gıda",
    "EV": "Yaşanılan mesken",
    "FA": "Dördüncü nota",
    "İÇ": "Dış karşıtı",
    "İL": "Vilayet",
    "İP": "Bağlamaya yarayan ince halat",
    "İŞ": "Çalışma, meşguliyet",
    "İZ": "Bırakılan eser, ayak izi",
    "LA": "Altıncı nota",
    "Mİ": "Üçüncü nota",
    "NE": "Soru sözcüğü",
    "OK": "Yaydan atılan",
    "ON": "Dokuzdan sonra gelen sayı",
    "OT": "Yeşil bitki örtüsü",
    "OY": "Seçimde kullanılan tercih",
    "ÖN": "Arka karşıtı",
    "ÖZ": "Bir şeyin esası, temeli",
    "RE": "İkinci nota",
    "SU": "İçtiğimiz berrak sıvı",
    "Sİ": "Yedinci nota",
    "UÇ": "Bir şeyin sivri kenarı",
    "UN": "Ekmek yapılan öğütülmüş tahıl",
    "ÜN": "Şöhret, nam",
    "ÜS": "Askerî merkez",
    "ÜÇ": "İkiden sonra gelen sayı",
    "VE": "En yaygın bağlaç",
    "YA": "Seslenme, çağırma sözü",
    "DO": "İlk nota",
    "BU": "En yakını gösteren işaret sözü",
    "ŞU": "Az ötedekini gösteren işaret sözü",
    "İN": "Vahşi hayvan yuvası",
    "ER": "Rütbesiz asker",
    "OD": "Eski dilde ateş",
    "AÇ": "Tok karşıtı",
}


def _alphabet_ok(word: str) -> bool:
    return all(ch in _TR_ALPHABET for ch in word)


def main() -> None:
    if hasattr(sys.stdout, "reconfigure"):
        sys.stdout.reconfigure(encoding="utf-8")  # Windows console is cp1252

    raw_words = _RAW_PATH.read_text(encoding="utf-8").split()
    raw2 = {tr_upper(w) for w in raw_words if len(w) == 2}
    blacklist = load_blacklist(_BLACKLIST_PATH) if _BLACKLIST_PATH.exists() else set()
    blacklist = {tr_upper(w) for w in blacklist}

    # Drop the placeholder guard entry.
    whitelist = {w: c for w, c in WHITELIST.items() if c}

    auto_pass = {w for w in raw2 if _alphabet_ok(w) and w not in blacklist}
    final = {w: c for w, c in whitelist.items() if w in auto_pass}
    not_in_raw = {w: c for w, c in whitelist.items() if w not in raw2}
    profane_in_wl = {w for w in whitelist if w in blacklist}

    print(f"Ham 2-harf (tekil)            : {len(raw2)}")
    print(f"  alfabe+profanity sonrası    : {len(auto_pass)}")
    print(f"  (profanity ile elenen)      : {len(raw2) - len({w for w in raw2 if w not in blacklist})}")
    print(f"Whitelist (küratör)           : {len(whitelist)}")
    print(f"  -> raw'da bulunan (NİHAİ)   : {len(final)}")
    print(f"  -> raw'da OLMAYAN (ek aday) : {len(not_in_raw)}")
    print(f"  -> whitelist'te profane     : {len(profane_in_wl)}")
    print(f"Elenen (tekil {len(raw2)} - nihai) : {len(raw2) - len(final)}  (obscure, whitelist dışı)")
    print()
    print("NİHAİ ALTIN LİSTE (whitelist ∩ raw, profanity-temiz):")
    print(f"{'KELİME':<7}| İPUCU")
    print("-------|" + "-" * 40)
    for w in sorted(final):
        print(f"{w:<7}| {final[w]}")
    if not_in_raw:
        print()
        print("EK ADAY (whitelist'te ama TDK ham listede YOK — eklensin mi?):")
        for w in sorted(not_in_raw):
            print(f"{w:<7}| {not_in_raw[w]}")

    if "--write" in sys.argv:
        out = _ROOT / "data" / "two_letter.json"
        payload = [{"answer": w, "clue": final[w]} for w in sorted(final)]
        import json

        out.write_text(
            json.dumps(payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8"
        )
        print(f"\nYAZILDI: {out}  ({len(payload)} kelime)")


if __name__ == "__main__":
    main()
