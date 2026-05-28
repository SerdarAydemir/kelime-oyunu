import typer

app = typer.Typer()

@app.command()
def generate(
    count: int = typer.Option(200, help="Üretilecek bölüm sayısı"),
    difficulty: str = typer.Option("mixed", help="Zorluk derecesi"),
) -> None:
    """Bulmaca bölümlerini üretir ve JSON olarak yazar."""
    print(f"Merhaba! {count} adet {difficulty} seviye bölüm üretilecek. (İskelet çalışıyor)")

if __name__ == "__main__":
    app()