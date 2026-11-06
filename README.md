# claude-code-bootstrap

Jedna komenda na czystym komputerze i masz działające Claude Code. Bez uprawnień administratora, bez Node.js, bez ręcznego klikania.

| System | Wklej w terminal |
|---|---|
| **Windows** (PowerShell) | `irm https://raw.githubusercontent.com/gacabartosz/claude-code-bootstrap/main/install.ps1 \| iex` |
| **macOS / Linux** | `curl -fsSL https://raw.githubusercontent.com/gacabartosz/claude-code-bootstrap/main/install.sh \| bash` |
| Windows, bez PowerShella | pobierz `install.cmd` i kliknij dwa razy |

Na końcu instalacji Claude Code **uruchamia się sam** i prowadzi przez logowanie w przeglądarce. Później otwierasz nowe okno terminala, wchodzisz do folderu projektu i wpisujesz `claude`.

## Co robi skrypt

1. Sprawdza system (Windows 10 1809+, macOS 13+, Ubuntu 20.04+, Debian 10+, Alpine 3.19+) i dostęp do claude.ai.
2. **Windows:** ustawia ExecutionPolicy tylko dla twojego użytkownika i włącza TLS 1.2 w starym PowerShellu. Jeśli brakuje Git Bash, instaluje Git przez [Scoop](https://scoop.sh) do katalogu użytkownika. Zapisuje też `CLAUDE_CODE_GIT_BASH_PATH`.
3. **macOS:** jeśli nie ma gita, wywołuje okno instalacji Command Line Tools.
4. **Linux:** gita instaluje tylko wtedy, gdy masz roota albo sudo bez hasła. Hasła nigdy nie pyta.
5. Instaluje Claude Code **oficjalnym instalatorem natywnym** (`claude.ai/install.ps1` / `install.sh`), kanał `stable`.
6. Dopisuje `~/.local/bin` do PATH.
7. Weryfikuje `claude --version`, wypisuje podsumowanie i ścieżkę do pełnego logu.
8. Uruchamia `claude` (pomijane w CI, bez terminala albo z `CCB_NO_LAUNCH=1`).

Pobieranie Claude Code ma 3 próby, bo na słabym łączu zdarza się zerwane połączenie.

Skrypt można uruchamiać wiele razy. Pomija to, co już jest, i ponawia to, co się nie udało.

## Opcje

Windows (ustaw przed komendą):

```powershell
$env:CCB_EXTRAS = "node,python"   # dodatkowo Node LTS i Python (przez Scoop)
$env:CCB_CHANNEL = "latest"       # stable (domyślnie) | latest | numer wersji
irm https://raw.githubusercontent.com/gacabartosz/claude-code-bootstrap/main/install.ps1 | iex
```

macOS / Linux:

```bash
curl -fsSL https://raw.githubusercontent.com/gacabartosz/claude-code-bootstrap/main/install.sh | CCB_EXTRAS=node,python bash
```

Dodatki: `node`, `python`, `uv`, `ripgrep`. Na Windows idą przez Scoop, na macOS i Linux przez [mise](https://mise.jdx.dev), w obu przypadkach do katalogu domowego.

`CCB_SKIP_GIT=1` pomija instalację gita. `CCB_NO_LAUNCH=1` nie uruchamia Claude na końcu.

## Gdy coś nie działa

Na końcu skrypt wypisuje listę problemów i ścieżkę do logu (`%TEMP%\claude-code-bootstrap-*.log` albo `/tmp/claude-code-bootstrap-*.log`). Wklej ją komuś, kto pomoże, albo do zgłoszenia w Issues.

| Objaw | Co zrobić |
|---|---|
| `claude` nie jest rozpoznawane | Zamknij i otwórz terminal na nowo (PATH ładuje się przy starcie) |
| `Cannot reach https://claude.ai` | Sieć firmowa: ustaw proxy, np. `$env:HTTPS_PROXY="http://proxy:8080"` lub `export HTTPS_PROXY=...` |
| Nie można zmienić ExecutionPolicy | Zablokowane przez organizację. Claude Code to `.exe` i działa mimo to |
| Brak Git Bash na Windows | Claude Code użyje PowerShella jako powłoki. Działa, ale część funkcji wymaga Bash |
| Diagnostyka | `claude doctor` |

## Odinstalowanie

```powershell
irm https://raw.githubusercontent.com/gacabartosz/claude-code-bootstrap/main/uninstall.ps1 | iex
```

```bash
curl -fsSL https://raw.githubusercontent.com/gacabartosz/claude-code-bootstrap/main/uninstall.sh | bash
```

Ustawienia w `~/.claude` zostają, chyba że ustawisz `CCB_PURGE=1`.

## Bezpieczeństwo

Komenda `irm | iex` / `curl | bash` uruchamia kod z internetu. Przed uruchomieniem przeczytaj `install.ps1` i `install.sh`: to zwykłe, skomentowane skrypty. Claude Code pobierany jest wyłącznie z oficjalnego `claude.ai`, Scoop z `get.scoop.sh`, mise z `mise.run`.

## Testy

Każdy push uruchamia instalację w GitHub Actions na Windows (PowerShell 5.1 i 7), macOS, Ubuntu oraz w czystych kontenerach Debian i Alpine (`.github/workflows/test.yml`).

## Licencja

MIT
