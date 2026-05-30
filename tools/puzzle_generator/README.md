# kelime-gen — Level Generator

Türkçe Kelime Bulmaca oyunu için JSON level dosyaları üretir.
Çıktılar `assets/levels/` klasörüne yazılır.

## Kurulum

```bash
cd tools/level_generator
pip install -e ".[dev]"
```

## Kullanım

```bash
# Komutları listele
python -m kelime_gen --help

# 200 bölüm üret (pack başına profil: grid boyutu + kelime sayısı otomatik)
python -m kelime_gen generate --count 200

# Tüm pack'leri tek grid boyutuna zorla (opsiyonel override)
python -m kelime_gen generate --count 50 --grid-size 12
```

## Geliştirme

```bash
ruff check .
black --check .
mypy src/
pytest
```
