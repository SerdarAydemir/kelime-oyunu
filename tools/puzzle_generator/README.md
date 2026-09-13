# kelime-gen — Puzzle Generator

Türkçe Kelime Bulmaca oyunu için 9×7 tam-çerçeve JSON bulmaca dosyaları üretir.
Çıktılar `assets/puzzles/` klasörüne yazılır (`manifest.json` + `puzzle_NNNN.json`).

## Kurulum

```bash
cd tools/puzzle_generator
python -m venv .venv && source .venv/bin/activate
pip install -e ".[dev]"

# Kelime havuzunu master clue'lardan türet (tek seferlik; data/processed/ git'te yok)
python scripts/rebuild_pool_from_master.py

# Küfür kara listesi (data/raw/profanity_blacklist.txt) — yoksa `generate` başarısız olur
python scripts/build_blacklist.py
```

## Küfür kara listesi

`data/raw/profanity_blacklist.txt`, [ooguz/turkce-kufur-karaliste](https://github.com/ooguz/turkce-kufur-karaliste)
deposundaki `karaliste.txt` dosyasından `scripts/build_blacklist.py` ile türetilir
(tr_upper, tek kelimelik girişler, en az 4 harf, tekilleştirme, sıralama).
Kaynak liste **CC BY-SA 4.0** lisanslıdır; bu türev dosya aynı lisans ve atıf
koşullarıyla dağıtılır. 3 harfli girişlerin neden atıldığı script docstring'inde
ölçümleriyle açıklanmıştır (yaygın Türkçe heceler: MAL, ANA, EMİ…; kısa cevaplar
`sensitive_answers.txt` ile cevap düzeyinde kontrol edilir).

Efektif havuz, `data/processed/master_clues.json` anahtarlarının kalite-kapılı
alt kümesidir: master clue'su olmayan kelime zaten üretime giremez (P0 placeholder
gate), flash-lite (`gemini-2.5-flash-lite`) ipuçlu kelimeler ise Claude re-clue'dan
geçene kadar havuz dışında tutulur (`--include-model` ile yalnız deney için açılır).
Ham TDK listesine gerek yoktur. Cevap-düzeyi dışlamalar (`sensitive_answers.txt`,
`rejected_words.json`) üretim anında uygulanır; havuz dosyasına yansımaz.

## Kullanım

```bash
# Komutları listele
python -m kelime_gen --help

# 200 bölüm üret (assets/puzzles/ altına; repo kökünden çalıştır)
python -m kelime_gen generate --count 200 --output-dir assets/puzzles

# Yalnızca medium (9×7) desteklenir
python -m kelime_gen generate --count 50 --size medium
```

Üretim sonunda `pack_report` pack'i diskten bağımsız doğrular ve
`reports/generation_report_*.json` yazar; herhangi bir bulmaca başarısızsa
komut 1 ile çıkar.

## Geliştirme

```bash
ruff check .
black --check .
mypy src/
pytest            # hızlı suite (yavaş v1 arşiv testleri hariç)
pytest -m slow    # yalnızca yavaş testler (tests/test_mask_synth.py, 20+ dk)
```
