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
python -m kelime_gen --help
```

## Geliştirme

```bash
ruff check .
black --check .
mypy src/
pytest
```
