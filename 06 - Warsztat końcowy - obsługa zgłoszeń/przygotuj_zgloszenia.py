"""
przygotuj_zgloszenia.py – tworzy fikcyjne zgłoszenia klientów w katalogu „skrzynki”.

Uruchomienie:
    python przygotuj_zgloszenia.py

Wszystkie dane są fikcyjne. Plik 007 jest celowo zapisany w kodowaniu Windows-1250,
a plik 006 jest pusty – oba testują obsługę nietypowych przypadków.
"""
import os
from pathlib import Path

INCOMING_DIR = Path(os.getenv("TICKETS_DIR", r"C:\Temp\incoming_tickets"))

ZGLOSZENIA = {
    "zgl_001_logowanie.txt": (
        "Dzień dobry,\n"
        "od dzisiejszego rana nie działa logowanie do panelu klienta. Po wpisaniu loginu "
        "i hasła strona przeładowuje się i wraca do ekranu logowania. Problem mają wszyscy "
        "pracownicy naszego biura (12 osób), więc nie możemy wystawiać zamówień.\n"
        "Proszę o pilny kontakt: jan.kowalski@example.com\n"
        "Jan Kowalski, Hurtownia Przykładowa"
    ),
    "zgl_002_faktura.txt": (
        "Witam,\n"
        "proszę o przesłanie duplikatu faktury za wrzesień, oryginał zaginął w księgowości. "
        "Najlepiej na adres ksiegowosc@example.com. W razie pytań proszę dzwonić: 600 123 456.\n"
        "Pozdrawiam, Anna Nowak"
    ),
    "zgl_003_drukarka.txt": (
        "KRYTYCZNY PROBLEM!!! Drukarka etykiet w magazynie przestała drukować kody kreskowe "
        "– wychodzą puste naklejki. Bez etykiet nie wyślemy dziś żadnej paczki do klientów. "
        "Wymieniliśmy już rolkę, bez zmian."
    ),
    "zgl_004_ups.txt": (
        "Dzień dobry, na zasilaczu UPS w serwerowni pali się pomarańczowa dioda. "
        "Wszystkie systemy działają normalnie, pytam tylko, czy to oznacza konieczność "
        "wymiany baterii w najbliższym czasie. Sprawa niepilna."
    ),
    "zgl_005_haslo.txt": (
        "Proszę o zresetowanie hasła dla użytkownika m.wisniewska – wraca z urlopu "
        "w przyszłym tygodniu i nie pamięta hasła. To nie jest pilne."
    ),
    "zgl_006_pusty.txt": "",
}

# zgłoszenie zapisane w kodowaniu Windows-1250 (częste przy starszych systemach)
ZGLOSZENIE_CP1250 = (
    "zgl_007_aplikacja.txt",
    "Aplikacja mobilna zawiesza się przy płatności BLIK. Klienci piszą, że nie działa "
    "koszyk i tracimy zamówienia. Zgłasza: Piotr Zieliński, tel. +48 501-222-333.",
)


def main() -> None:
    INCOMING_DIR.mkdir(parents=True, exist_ok=True)
    for name, text in ZGLOSZENIA.items():
        (INCOMING_DIR / name).write_text(text, encoding="utf-8")
    name, text = ZGLOSZENIE_CP1250
    (INCOMING_DIR / name).write_text(text, encoding="cp1250")

    print(f"Utworzono zgłoszenia w katalogu: {INCOMING_DIR}")
    for path in sorted(INCOMING_DIR.glob("*.txt")):
        print(f"  {path.name:28} {path.stat().st_size:5} B")


if __name__ == "__main__":
    main()
