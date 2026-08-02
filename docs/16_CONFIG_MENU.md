# El menú de configuración (config_menu)

PokeEssentialsAccess trae un **menú de configuración hablado** que el usuario abre sobre el juego en marcha
con la tecla `:config` (por defecto **O**). Esta es la referencia para desarrolladores: cómo está
estructurado, cómo se definen las opciones y qué contiene cada apartado.

> Código: `core/menus/config_menu.rb` (el menú) y `core/foundation/config.rb` (el esquema de opciones).
> Relacionado: [15_SPEECH_AND_I18N.md](15_SPEECH_AND_I18N.md), [07_AUDIO3D.md](07_AUDIO3D.md).

---

## 1. Cómo funciona

`ConfigMenu` corre como un **bucle modal** sobre el mapa: cuando se abre, toma `Graphics.update`/
`Input.update` y pausa el juego (jugador, pasos, audio posicional) hasta cerrarse. Se navega con los
**botones del propio juego**, así que cualquier rebind funciona gratis.

| Acción | Efecto |
|--------|--------|
| Arriba / Abajo | Mover por la lista |
| Izquierda / Derecha | Bajar/subir un valor numérico, alternar un flag, ciclar una lista de valores |
| Confirmar | Entrar a una categoría, ejecutar una acción, alternar un flag, reproducir un sonido |
| Cancelar | Volver un nivel, o cerrar desde el nivel superior |
| Tecla `:info` del mod (por defecto **T**) | Leer la ayuda del ajuste enfocado |

Cada etiqueta y mensaje es una **clave i18n** (nada hardcodeado). Al cerrar, persiste con `Settings.write`.

---

## 2. El esquema de opciones (`Config::SCHEMA`)

Las opciones del usuario se declaran en una tabla `SCHEMA` en `core/foundation/config.rb`. Cada fila es:

```ruby
[clave, valor_por_defecto, tipo, categoría, lbl_etiqueta, help_ayuda]
```

- **clave** — el símbolo del ajuste (`Config.audio3d_volume`, etc.); **valor_por_defecto** — el inicial.
- **tipo** — cómo se edita y se lee. Numéricos (`:vol`, `:tiles`, `:sonar`, `:sec`, `:ms`, `:reach`,
  `:astar`, `:gdist`, `:desk`) usan `KIND_BOUNDS` `[min, max, paso, unidad]`; no numéricos (`:flag`,
  `:lang`, `:navmode`, `:occ`, `:algo`) tienen su propia edición. El tipo agrupa ajustes que comparten
  límites, así que **no lo reutilices por parecido de unidad**: `:sonar` (1-30) existe aparte de `:tiles`
  (1-20) precisamente porque subir el sonar no debe ensanchar de rebote la sonda de paredes ni la
  distancia de alternancia, que también se miden en casillas.
- **categoría** — en qué submenú aparece: `:general`, `:pathfinder`, `:pathfinder_adv`, `:audio`, las
  sub-categorías `:audio3d_vol`/`:audio3d_freq`/`:audio3d_walls`/`:audio3d_adv`, o `:debug`.
- **lbl_/help_** — claves i18n del nombre y de la ayuda (la que dice `:info`).

Para **añadir una opción** basta con una fila nueva en `SCHEMA` más sus claves `lbl_`/`help_` en
`lang/es.txt` y `lang/en.txt` (paridad obligatoria); aparece en su categoría automáticamente.

---

## 3. El menú raíz

Las tres primeras entradas salen de `Config::CATEGORIES`; el resto las empuja `config_menu.rb` a mano.

| Entrada | Qué es |
|---|---|
| Información general (`:general`) | idioma, ayuda en puzles, autodetección de menús, leer ayudas de menú |
| Opciones de navegación y busca rutas (`:pathfinder`) | ver §6; dentro, "Navegación avanzada" (`:pathfinder_adv`) |
| Opciones de audio (`:audio`) | ver §5; dentro, las cuatro sub-categorías de audio posicional |
| **Glosario de sonidos** (`:sounds`) | el catálogo de señales del mod; ver §4 |
| Gestión de etiquetas (`:tags`) | exportar/importar etiquetas de objetos y la lista de objetos ocultos |
| Remapear controles del juego (`:remap`) | asigna una tecla EXTRA sobre la entrada nativa, nunca la sustituye |
| Depuración (`:debug`) | ver §7 |
| Restaurar valores por defecto | devuelve todo el `SCHEMA` y los rebinds a su defecto y guarda |

---

## 4. Glosario de sonidos

Categoría propia del menú raíz, una fila por señal del catálogo (`SoundGlossary::ENTRIES`) más "Volver":

- **Mover** por la lista: oyes el **nombre** del sonido ("Persona", "Puerta o salida", "Viento de pared al
  norte"...).
- **Tecla de ayuda**: oyes **dónde suena** ese sonido y qué significa.
- **Confirmar**: **lo reproduce**, plano y centrado, para memorizar el timbre.

Existe porque la mitad de lo que el mod comunica no son palabras sino señales, y aprenderlas
encontrándoselas en el campo es lento y ambiguo. El detalle del catálogo está en
[07_AUDIO3D.md](07_AUDIO3D.md).

---

## 5. Ajustes de audio

Categoría `audio`: `sound_nav`, `proximity_radar` y `audio3d_volume` (maestro). Desde ahí se entra a las
cuatro sub-categorías.

| Ajuste | Defecto | Qué hace |
|--------|---------|----------|
| `sound_nav` | `:full` | `:off` (nada, ni se arranca el motor de audio), `:basic` (solo pasos y choques, paneados), `:full` (todo el paisaje sonoro). |
| `proximity_radar` | `false` | Pitido corto al pasar justo al lado de algo interactuable. |
| `audio3d_volume` | 80 | Volumen maestro del audio posicional. |

**Volúmenes** (`audio3d_vol`, 0-100 a paso 10): `audio3d_npc`/`audio3d_object`/`audio3d_door` (85),
`audio3d_teleporter` (90), `audio3d_water` (70), `audio3d_wind` (55), `footstep_volume` (80),
`wall_volume` (80), `event_volume` (70, el cue de la guía).

**Frecuencias** (`audio3d_freq`) — cada cuánto suena cada tipo: `audio3d_freq_npc` /
`audio3d_freq_object` / `audio3d_freq_door` (70) y `guide_freq` (55).

**Paredes y oclusión** (`audio3d_walls`):

| Ajuste | Defecto | Qué hace |
|--------|---------|----------|
| `audio3d_occlusion` | `:occlude` | Emisores tras pared: `:hear` (normal), `:occlude` (apagado), `:hide` (no suenan). |
| `audio3d_air` | `false` | Absorción de aire. |
| `audio3d_wall_range` | 3 | Alcance de detección de paredes (casillas). |
| `audio3d_wall_falloff` | 50 | Caída de volumen del viento con la distancia a la pared. |
| `audio3d_desk_range` | 2 | Distancia a la que un NPC de mostrador sigue oyéndose tras una pared (0 lo desactiva). |

**Avanzado** (`audio3d_adv`): `audio3d_range` (12, alcance del sonar) y `audio3d_alt_dist` (5, distancia a
la que dos emisores alternan sus pings en vez de sonar a la vez).

---

## 6. Ajustes de navegación

Categoría `pathfinder`: `auto_guide`, `hide_unreachable`, `hide_noninteractive`, `fixed_target_number`,
`name_items`, `surface_cues` y `guide_distance`. Sub-categoría `pathfinder_adv`: `straight_routes`,
`guide_refresh`, `route_reach`, `astar_max`, `path_algorithm` (los ocho de
`Pathfinder::ALGORITHMS`), `edge_relax`, `ledge_directions` y `route_cache`. El detalle algorítmico está en
[06_PATHFINDING.md](06_PATHFINDING.md).

---

## 7. Menú de Depuración

Entrada del menú raíz para desarrollo y soporte. No es para el usuario final típico, pero es accesible.

- **Diagnósticos por sección al portapapeles**: audio 3D / eventos y localizador / rendimiento / mapa y
  navegación / escena y runtime. Cada uno copia solo su sección (vía `Clipboard.set_text`) para pegarla
  donde haga falta sin volcar todo. Un **Diagnóstico completo** escribe a `accessibility/data/diag.txt`
  (igual que Ctrl+Alt+F9, que se mantiene como atajo).
- **Grabar sesión (para informar de un fallo)** — arranca o detiene el grabador (`core/util/recorder.rb`).
  Al arrancar dice el nombre del archivo; al detener, cuántos eventos guardó. Escribe una **transcripción**
  de la partida en `accessibility/data/recordings/rec-<fecha>.txt`: lo que el mod vio (mapa, posición,
  escena, objetivo enfocado, más un volcado de diagnóstico al empezar y en cada cambio de mapa o escena) y
  lo que dijo, en orden. Así un tester que oye al mod quedarse mudo entrega una grabación en vez de
  describir el momento. No hookea nada dentro de los lectores: todo le llega por el observador
  `PokeAccess.on_speak` y por una lectura por frame del estado que el mod ya mantiene; apagado no cuesta nada.
- **Ajustes avanzados** del grupo `:debug` del SCHEMA: `route_auto` + `route_budget_ms` (corte del
  busca-rutas por tiempo en vez de por nodos; ver [06_PATHFINDING.md](06_PATHFINDING.md)) y
  `transfer_active_page_only` (anunciar una baldosa como salida solo si su página activa transfiere).

## Próximo

- [07_AUDIO3D.md](07_AUDIO3D.md) — el motor de audio posicional por dentro
- [15_SPEECH_AND_I18N.md](15_SPEECH_AND_I18N.md) — voz e i18n
