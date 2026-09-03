# Diagnóstico

Cómo se averigua por qué algo no se lee. Primera parada ante un reporte: el volcado dice qué versión corre,
qué motor se detectó, qué hooks se ataron y qué plugins hay, antes de tocar código. Fuentes:
`core/input/diag.rb`, `core/util/recorder.rb`, `core/foundation/plugins.rb`.

## Teclas

| Tecla | Qué hace | Salida |
|---|---|---|
| Ctrl+Alt+F8 | Activa/desactiva el mod; al reactivar reintenta el arranque de la voz | Voz |
| Ctrl+Alt+F9 | Volcado completo, las 11 secciones | `<DATA>/diag.txt`, en modo append. `DATA` es `accessibility/data`, o la carpeta AppData del juego si aquella no admite escritura |
| Ctrl+Alt+F10 | Diagnóstico hablado corto | Solo voz |

Los tres acordes están fijos en `core/input/keyboard.rb` y no se reasignan; lo reconfigurable vive en
`Config.keys`. Se sondean **antes** de las puertas de `@enabled` y `focused?`, así que responden con el mod
apagado. F9 solo dice si guardó ("Diagnóstico guardado" / "Diagnóstico NO guardado"); el detalle va al
fichero. F10 no escribe nada y habla, unido por `". "`:

```
scene Scene_Map. map Ciudad Verde 24,17. last Casa. 3 hooks missing
```

Mapa y posición solo si hay mapa; `last` solo si se habló algo; los hooks solo si falta alguno.

## Anatomía del volcado

Cabecera `=== PokeAccess diag <hora> ===` y luego las secciones, en el orden de `DIAG_ALL`. La columna Menú
es el subconjunto del menú de depuración que copia esa sección **al portapapeles**; el completo va al fichero.

| # | Sección | Menú | Qué lleva |
|---|---|---|---|
| 1 | `diag_perf` | Rendimiento | ms medios/máximos por etiqueta desde el volcado anterior, y **resetea** la ventana |
| 2 | `diag_focus` | Eventos y localizador | Identificación, foco, escena, hooks, plugins y configuración |
| 3 | `diag_map` | Mapa y navegación | Mapa, tamaño, posición, dirección, nº de eventos, terrenos vecinos |
| 4 | `diag_locator` | Eventos y localizador | Categorías, categoría e índice activos, lista de objetivos |
| 5 | `diag_pathfinder` | Mapa y navegación | Flood de casillas alcanzables y ruta al objetivo |
| 6 | `diag_surface` | Mapa y navegación | Etiquetas de superficie y pistas de terreno |
| 7 | `diag_audio3d` | Audio 3D | Motor posicional, dispositivo, canales, gate y eventos cercanos |
| 8 | `diag_scene` | Escena y runtime | Batalla, sprite del jugador, imágenes, elecciones, ventanas de comandos vivas |
| 9 | `diag_runtime` | Escena y runtime | Introspección de la escena viva: métodos e ivars propios |
| 10 | `diag_polls` | Rendimiento | Capas de `Input.update` y nº de pollers por frame |
| 11 | `diag_silence` | Escena y runtime | Pantallas que aparecieron y no dijeron nada en dos segundos |

Aparte del volcado, el menú de configuración tiene la entrada **autochequeo del motor** (`core/util/selfcheck.rb`):
sondea el motor real en vez de los stubs, cuenta las sondas que fallan y los hooks que no ataron, habla el
resumen y lo escribe en `data/selfcheck.txt`.

Cada sección va bajo `rescue`: si una falla se escribe `<seccion>: ERR <clase>: <mensaje>` y el resto sigue;
un campo suelto sale como `ERR(<clase>)` y los largos se recortan con `...[cortado]`. Un perfil añade su
sección con `Keys.register_diag_section(nombre, grupo) { |o| ... }`, grupo `:scene` por defecto.

### Las líneas de identificación

Las emite `diag_engine` dentro de `diag_focus`. Son las que se leen primero.

| Línea | Campo | Qué dice |
|---|---|---|
| `mod:` | — | Versión instalada: `data/installed.json` (la sella el instalador) y, si falta, `version.json`. `?` si no se pudo leer |
| `engine:` | `kind` | `gamedata` o `gen6`: la era de la API de datos |
| | `version` | Float, **solo informativo**: los fangames mezclan eras. Los lectores gatean por capacidad, nunca por este número — ver [02-motores](02-motores.md) |
| | `fork` | `nil`, o `:sky` en el fork de La Base de Sky |
| | `caps` | Capacidades registradas que responden sí, más `PokeBattle_Scene`/`$player`/`$Trainer`. Omite `:gamedata`, `:gen6` y `:sky_fork`, que ya dicen `kind` y `fork` |
| `voice:` | `prism` | `false` = `prism_pea.dll` no cargó |
| | `ready` | `false` = no se consiguió ningún backend |
| | `backend` | `"NVDA"`, `"JAWS"`, `"SAPI 5"`… o `""` |
| `timing:` | `uptime_scale` `render_fps` | `1000000.0` en builds de mkxp-z con `System.uptime` en microsegundos; los fps se miden entre dos volcados y deben coincidir con `frame_rate` |

```
mod: 0.2.5
engine: kind=gamedata version=21.1 fork=:sky caps=[battle_scene, ui_rework, $player]
engine: kind=gen6 version=16.0 fork=nil caps=[PokeBattle_Scene, $Trainer]
voice: prism=true ready=true backend="NVDA" speaking=false
```

### Hooks y plugins

| Línea | Campo | Qué dice |
|---|---|---|
| `hooks:` | `missing` | Clase presente, método ausente. Por contrato, **la lista de typos**. Al arrancar se escribe también en `accessibility/data/loader_error.txt`, como `[diag] enganches sin metodo (posible typo): ...` |
| | `fn_absent` | Funciones globales no encontradas. Informativo: varía legítimamente por juego |
| | `overrides` | Reemplazos instalados con `override`, como `"Clase.metodo (tag)"` |
| `guard_suppressed=` | | Pares `externo>interno` que descartó el guard de reentrada |
| `caches=` `data_err=` | | Módulos con reset registrado, y lookups de datos caídos a fallback |
| `plugins:` | `cargados` | Lectores de `plugins/` cargados esta sesión |
| | `sin_declarar` | **La línea clave**: el juego trae un plugin conocido y el perfil no declaró su lector. Esa pantalla está muda y nada más lo diría |
| `plugins_juego:` | | El registro propio del juego, vía `PluginManager` |

`plugins_juego` lista también plugins que el mod no conoce, justo el conjunto al que suele pertenecer una
pantalla sin lector. Tres valores posibles, y **no significan lo mismo**:

| Valor | Significa |
|---|---|
| `Easy Questing 1.0.4, Tip Cards 2.1` | La lista: `"nombre versión"` por entrada, ordenada, recortada a 400 |
| `ninguno registrado` | Hay `PluginManager` y su lista está vacía |
| `sin PluginManager` | **No hay registro que consultar.** Los juegos antiguos pegan el código del plugin en la lista de scripts, así que nada se registra: aquí "ninguno instalado" sería mentira |

## El grabador de sesiones

Se enciende desde el menú de depuración, no con tecla; escribe
`accessibility/data/recordings/rec-AAAAMMDD-HHMMSS.txt` y al parar dice cuántos eventos guardó. Convierte
una partida en un **transcript**: qué vio el mod y qué dijo, en orden. No engancha nada dentro de los
lectores —todo le llega por `PokeAccess.on_speak` y una lectura por frame de estado que el mod ya lleva—,
así que el instrumento no puede romper un lector. Apagado no cuesta nada. Campos separados por tabulador,
texto siempre al final:

| Línea | Campos | Cuándo |
|---|---|---|
| `# pea-recording 1` | kind, version, fork | Primera línea |
| `map` | id, nombre | Al cambiar de mapa |
| `pos` | x, y | Al moverse |
| `scene` | clase | Al cambiar de escena o de `busy_reason` |
| `sel` | índice, nombre del objetivo | Al cambiar la selección del localizador |
| `say` | 0/1 interrupción, texto | Cada línea hablada |
| `in` | `confirm`, `cancel`, `dir` o `tecla:<nombre>` | Cada entrada del jugador |
| `diag` | motivo, una línea de sección | Al arrancar, al cambiar de mapa y al cambiar de escena |

Los `diag` embebidos son lo que hace útil el adjunto: el reporte responde qué **vio** el mod, no solo qué
dijo. Un volcado idéntico al anterior por el mismo motivo escribe una sola línea `(igual que el anterior)`;
`diag_perf` y `diag_polls` quedan fuera a propósito (el primero resetearía la ventana de medida del jugador,
el segundo es un micro-benchmark). Adjuntada a un reporte se audita sola con `test/support/replay.rb`, y
cualquier fichero puesto en `test/fixtures/recordings/` pasa a ser test de regresión.

| Modo | Qué detecta |
|---|---|
| SILENCE | La selección se movió y no se habló nada después |
| REPEAT | La misma línea dos veces sin **nada** del jugador en medio (por eso se graban las teclas) |
| RAW | Una línea hablada con códigos de control de RPG Maker (`\c[1]`, `\PN`) |

## Síntoma → qué mirar → causa probable

| Síntoma | Qué mirar | Causa probable |
|---|---|---|
| No se lee **nada** | `mod:` | **Install desfasado: la causa nº1.** La versión instalada no es la que se cree |
| | `voice: prism=false` | `prism_pea.dll` no cargó: falta `accessibility/lib/` o no coincide la arquitectura |
| | `voice: ready=false` | Ningún backend de lector. Ctrl+Alt+F8 dos veces reintenta el init |
| | `enabled=false` / `focused?=false` | El mod está apagado (Ctrl+Alt+F8), o no se detecta el foco de la ventana |
| No se lee **una pantalla** | `scene=` | El nombre de clase con el que buscar en el volcado de scripts del juego |
| | `plugins: sin_declarar` | El perfil no declaró el lector de un plugin que el juego sí trae |
| | `plugins_juego:` | La pantalla es de un plugin que el mod aún no conoce |
| | `hooks: missing` | Typo en el nombre de un método enganchado |
| | `diag_runtime` | Pantalla propia sin lector: da métodos e ivars para escribir uno |
| Se lee **dos veces** | `live_cmd_windows=` | El lector genérico de ventanas de comandos también la ve: recláma la ventana con `PokeAccess.dedicate`. O dos nombres de clase emparentados enganchados a la vez, y `Engine.scene_classes` deja solo el ancestro |
| **Dato equivocado** o vacío | El ivar real, contra el volcado de scripts | Nombre de accessor divergente entre juegos. Ver abajo |
| El **audio 3D** no suena | `audio3d: available=false` | La dll nativa no está, o no coincide la arquitectura |
| | `audio3d: ready=false boot_tried=true` | `INIT` no devolvió 1: Steam Audio no arrancó |
| | `audio3d: sound_nav=false` | Apagado en configuración |
| Suena al andar y calla parado | `audio3d gate:` | Cuenta por motivo. Los bucles solo se reposicionan al cambiar de casilla; un gate cerrado los deja mudos |
| Un mapa va **lento** | `perf:` | F9 al entrar, andar un poco, F9 otra vez, y comparar `map_poll` contra `audio3d` |

## Fallos silenciosos

El fallo más caro del proyecto y el único que no deja rastro: **la clase existe, el método existe, el hook
se ata perfecto, y el ivar que se lee se llama distinto en ese juego.** Se lee `nil` para siempre, sin
excepción, sin log y sin entrada en `Hooks.missing`, que solo registra clase presente con método ausente.
Casos reales: `totalpp` frente a `total_pp`, `power` frente a `base_damage`. Se pregunta por los dos:

```ruby
PokeAccess.attr_of(obj, :totalpp, :total_pp)
```

La segunda forma es de clases: un fork declara los nombres viejos como **subclases vacías** de los nuevos e
instancia solo el nuevo, así que el hook se ata a una clase que el juego nunca construye. Tampoco llega a
`missing`, porque la clase sí existe; `Engine.scene_classes` se queda solo con el ancestro.

**Cómo se confirma:** un hook instalado no prueba que el dato esté donde se cree. Se cruza contra el volcado
de scripts del juego; sin volcado, `diag_runtime` da lo mismo en vivo — métodos propios de la escena activa
e ivars con un preview del valor:

```
$scene=PokemonPartyScreen methods=["pbChooseAblePokemon", "pbDisplay", ...]
  ivars: ["@index=0", "@party=Array(6)[PokeBattle_Pokemon...]", "@scene=PokemonParty_Scene"]
```

Un ivar con el nombre esperado y valor `nil` confirma el diagnóstico; uno con otro nombre lo resuelve.
