# ClaudeNotch

Un piccolo widget per macOS che vive nel **notch** del MacBook e mostra in tempo reale quanto hai consumato dei limiti del tuo piano **Claude** (Pro / Max) usato con **Claude Code**.

Niente icona nel Dock, niente finestre: solo due "orecchie" ai lati del notch. Passaci sopra con il mouse e si espande in un pannello con tutti i dettagli.

## Cosa fa

**Da chiuso**, ai lati del notch vedi:

- a sinistra: la percentuale usata della **sessione corrente (finestra di 5 ore)**
- a destra: un anello con la percentuale usata del **limite settimanale**

**Da aperto** (mouse sopra il notch) il pannello mostra:

| Voce | Descrizione |
|---|---|
| **Sessione (5h)** | Utilizzo della finestra di 5 ore + countdown al reset |
| **Settimana** | Utilizzo del limite settimanale + countdown al reset |
| **Settimana · Opus / Sonnet** | Limiti settimanali per modello (se previsti dal tuo piano) |
| **Token · Oggi / Settimana** | Token totali (input + output + cache), token di output e risposte ricevute, oggi e nella settimana del piano |
| **Modelli · settimana** | Quota di token per modello (es. Opus 5, Sonnet 5) con il più usato in evidenza |
| 🔔 | Attiva/disattiva gli avvisi di fine sessione |
| ⚙️ | Apre le impostazioni |
| ⏻ | Chiude l'app |

### Impostazioni

Dall'ingranaggio nel pannello si apre la finestra delle impostazioni, dove scegli:

- **Notch chiuso** — cosa mostrare a sinistra e a destra del notch: sessione (5h), settimana, token di oggi, token della settimana, modello più usato oppure niente
- **Pannello aperto** — quali sezioni vedere: sessione, settimana, limiti per modello, token, modelli della settimana
- **Generale** — avvio al login, avvisi di fine sessione e relativo suono

Le scelte vengono salvate e applicate subito.

### Avvisi di fine sessione

Quando una sessione di Claude Code finisce di lavorare e aspetta te, il notch si **espande per qualche secondo** (con un suono) e ti dice:

- il **progetto** (nome della cartella in cui gira Claude Code)
- il **titolo della sessione** generato da Claude Code
- quanto è durato il turno

Se più sessioni finiscono insieme, gli avvisi vengono mostrati uno dopo l'altro. Passando il mouse sul notch si apre il pannello completo. I turni più brevi di 15 secondi vengono ignorati; gli avvisi si attivano e disattivano con la campanella nel pannello.

I colori cambiano in base all'utilizzo: 🟢 sotto il 50%, 🟡 tra 50% e 80%, 🔴 oltre l'80%.

Sui Mac **senza notch** (o su monitor esterni) il widget compare comunque al centro della menu bar come una "pillola".

## Come funziona

- **Limiti del piano** — ClaudeNotch interroga lo stesso endpoint usato dal comando `/usage` di Claude Code (`api.anthropic.com/api/oauth/usage`), autenticandosi con il token OAuth che Claude Code salva nel **Portachiavi** (voce `Claude Code-credentials`). Il token viene riletto a ogni richiesta, quindi resta sempre valido finché Claude Code lo rinnova.
  - L'aggiornamento avviene al massimo **ogni 3 minuti**, per non consumare il rate limit condiviso con `/usage`. In caso di errore 429 si applica un backoff esponenziale (5 → 10 → 20 → 30 min).
  - L'ultimo valore ricevuto viene salvato in cache, così al riavvio il widget mostra subito i dati.
- **Avvisi di fine sessione** — ClaudeNotch osserva con FSEvents i log di Claude Code e reagisce all'evento `turn_duration` che Claude Code scrive quando conclude un turno.
- **Token e modelli** — calcolati in locale leggendo i log di Claude Code in `~/.claude/projects/**/*.jsonl`. La settimana parte dal reset del limite settimanale del piano (o, se non disponibile, dagli ultimi 7 giorni); i file vengono letti in modo incrementale. Nessun dato viene inviato altrove.

## Requisiti

- macOS **14 Sonoma** o successivo
- **Xcode** o i Command Line Tools (Swift 5.9+) — `xcode-select --install`
- **Claude Code** installato e con login effettuato tramite account Claude (Pro/Max): `claude` → `/login`

> Se usi Claude Code con una API key invece che con l'account Claude, i limiti del piano non sono disponibili; funzioneranno solo le statistiche locali.

## Installazione

```bash
git clone <url-del-repo> claude_notch
cd claude_notch
chmod +x build.sh
./build.sh --install
```

Lo script:

1. compila il progetto in release con `swift build`
2. crea il bundle `build/ClaudeNotch.app` e lo firma ad-hoc
3. con `--install` lo copia in `/Applications` (sostituendo una versione precedente) e lo avvia

Se vuoi solo compilarla senza installarla:

```bash
./build.sh
open build/ClaudeNotch.app
```

### Primo avvio

- Al primo accesso al Portachiavi macOS chiederà il permesso per leggere la voce **Claude Code-credentials**: scegli **Consenti sempre**, altrimenti il widget mostrerà "Login Claude Code non trovato".
- Poiché l'app è firmata ad-hoc (non notarizzata), se macOS la blocca apri **Impostazioni di Sistema → Privacy e sicurezza** e clicca **Apri comunque**.
- Per farla partire all'avvio del Mac, apri le impostazioni (⚙️ nel pannello) e attiva **Avvia al login**.

## Aggiornamento

```bash
git pull
./build.sh --install
```

## Disinstallazione

1. Nelle impostazioni disattiva **Avvia al login** (se attivo), poi chiudi l'app con ⏻
2. Elimina l'app e le preferenze salvate:

```bash
rm -rf /Applications/ClaudeNotch.app
defaults delete com.italianscodeitbetter.claudenotch
```

## Risoluzione problemi

| Messaggio | Causa / soluzione |
|---|---|
| `Login Claude Code non trovato` | Claude Code non è loggato o l'accesso al Portachiavi è stato negato. Esegui `claude` → `/login` e riavvia l'app. |
| `Token scaduto: apri Claude Code` | Il token OAuth è scaduto: apri Claude Code, che lo rinnova automaticamente. |
| `Rate limit, riprovo alle …` | L'endpoint ha risposto 429; il widget ritenterà da solo all'orario indicato. |
| `Offline` | Nessuna connessione di rete. |

## Struttura del progetto

```
Sources/ClaudeNotch/
├── main.swift          # avvio dell'app (senza icona nel Dock)
├── AppDelegate.swift   # finestra sopra il notch, posizionamento e hover
├── NotchView.swift     # interfaccia SwiftUI (vista chiusa ed espansa)
├── UsageStore.swift    # chiamate API, lettura token dal Portachiavi, parsing dei log locali
├── SessionWatcher.swift # avvisi di fine sessione dai log di Claude Code
└── Settings.swift       # finestra delle impostazioni e preferenze di visualizzazione
Resources/AppIcon.icns  # icona dell'app (+ AppIcon.png in 1024px)
Scripts/make_icon.swift # rigenera l'icona: swift Scripts/make_icon.swift
build.sh                # build + creazione del bundle .app (+ installazione)
```

## Nota

Progetto non ufficiale, non affiliato ad Anthropic. Usa un endpoint interno di Claude Code che potrebbe cambiare senza preavviso.
