# Voz e i18n: cómo hablar y cómo localizar

Todo lo que el mod le dice al jugador pasa por dos sistemas: **voz** (`core/speech/`) y **localización**
(`core/foundation/i18n.rb` + `lang/*.txt`). Esta es la referencia para escribir lectores que hablen bien
y se traduzcan sin romper nada.

> Relacionado: [14_EXTENDING.md](14_EXTENDING.md) (cómo escribir un lector) y
> [02_ARCHITECTURE.md](02_ARCHITECTURE.md) (capa Input & Speech).

---

## 1. El puente de voz: prism

La voz sale por **prism**, que habla con NVDA, JAWS, SAPI, UIA, ZDSR y más, en UTF-8 directo.
`core/speech/speech.rb` no enlaza `prism.dll` a pelo: enlaza **`prism_pea.dll`**, el puente propio del
proyecto (fuente en `bridge/prism_pea.c`). Motivo: la API de prism es de *handles*, y devolver punteros a
Ruby los truncaría en x64; el puente los guarda como estáticos dentro de la dll y expone funciones cdecl
planas que solo toman enteros y cadenas, la forma que `Win32API` de mkxp-z maneja bien en x86 y x64. Las
dos dll viven, por arquitectura, en `accessibility/lib`, que `SetDllDirectoryA` añade a la ruta de búsqueda
para que el puente encuentre su motor.

```ruby
PEA_INIT  = (Win32API.new("prism_pea.dll", "PeaInitialize", [],         "i") rescue nil)
PEA_SPEAK = (Win32API.new("prism_pea.dll", "PeaSpeak",      ["p", "i"], "i") rescue nil)
# ... stop, pause, resume, is_speaking, braille, backend_name
```

**Arranque**: `init_speech!` se ejecuta **una sola vez** y honra el valor de retorno. Un fallo total (ningún
backend pudo arrancar) se registra una vez y **se queda fallado**: no hay reintento en segundo plano (un
barrido de init por cada `speak` sería trabajo constante en balde). El gesto del jugador para "la voz no
está, reconecta" es apagar y encender el mod con **Ctrl+Alt+F8**, que llama a `retry_init!`. Un lector
arrancado DESPUÉS de un init correcto no necesita nada de esto: el puente vuelve a elegir el mejor backend
en cualquier `Speak` que falle.

### Primitivas

| Primitiva | Qué hace |
|---|---|
| `speak(text, interrupt = true)` | Habla por el lector activo. `true` **corta** lo que se esté diciendo; `false` lo **encola**. Normaliza espacios e ignora texto vacío. |
| `speak_clean(text, interrupt = true)` | `speak(clean(text), interrupt)`: la forma canónica para texto que viene del juego (§2). |
| `say_dialogue(message)` | Diálogo de `pbMessage`: limpia, lo guarda para la tecla de repetir, deduplica la misma línea durante 0,5 s y lo habla **encolado**. |
| `stop_speech` | Calla al lector ya, sin decir nada nuevo. `true` si el backend obedeció. |
| `pause_speech` / `resume_speech` | Pausa y reanuda. Depende del backend (SAPI y UIA lo respetan; NVDA no): `false` significa "no soportado o nada que hacer", nunca un error que merezca reportarse. |
| `speaking?` | `true`, `false`, o **`nil` cuando el lector no sabe decirlo**. Trata `nil` como "desconocido", **nunca** como silencio. |
| `braille(text)` | Manda texto a la pantalla braille activa; `false` si no hay. UTF-8, igual que `speak`. |
| `braille_codepoints(cps)` | Igual, desde codepoints unicode (p. ej. celdas U+28xx). BMP; fuera de rango se salta. |
| `speech_backend` | Nombre del backend activo ("NVDA", "JAWS", "SAPI 5"...), o `""` si está caído. |
| `speech_ready?` / `last_spoken` | Si el puente está en pie, y la última línea dicha. Los usa el diagnóstico. |

```ruby
PokeAccess.speak_clean(cmds[v], !opening)   # opción que da el motor: limpia y habla
PokeAccess.speak(linea_de_combate, false)   # línea del mod ya limpia, encolada
```

Regla práctica del `interrupt`: `true` para navegación de cursor (el usuario se movió y quiere oír la
opción nueva **ya**); `false` para líneas que no deben pisarse entre sí (varias líneas de combate seguidas,
una lectura "al abrir" que no debe cortar el título recién dicho).

`speak` nunca tumba el frame: si algo falla, escribe un marcador en `accessibility/data/hook_loaded.txt`.
`speaking?` se compara por valor exacto (`== 1` / `== 0`), no por signo: el `Win32API` de mkxp-z devuelve
el `-1` del puente como 4294967295 sin signo, y una prueba `< 0` no lo vería.

### El observador `on_speak`

Un único punto de extensión para observar TODO lo que se habla, sin un solo hook dentro de los lectores.
Es `nil` por defecto, así que no tener oyente cuesta una comprobación de nil por línea. Un observador que
lance se traga la excepción: un instrumento jamás puede enmudecer al mod.

```ruby
PokeAccess.on_speak = lambda { |text, interrupt| ... }
PokeAccess.on_speak = nil   # desengancharse
```

Lo usa el grabador de sesión (`core/util/recorder.rb`) para transcribir una partida entera; ver
[16_CONFIG_MENU.md §7](16_CONFIG_MENU.md).

---

## 2. Limpiar texto: `PokeAccess.clean`

Los strings de Essentials llevan códigos de control (`\PN` = nombre del jugador, `\v[3]` = variable,
`\c[2]` = color, `\1`/`\2` = esperar input) y a veces etiquetas tipo HTML. **Habla siempre texto limpio**:
pasa por `clean` cualquier cosa que venga del juego antes de `speak`. En la práctica casi nunca escribes
`speak(clean(...))` a mano: usa `speak_clean`, que hace exactamente eso.

`clean` sustituye `\PN`/`\v[n]`, elimina los `\X`/`\X[..]`, las etiquetas `<...>`, y los bytes de control
`\x00-\x1f` (si no se quitan, la línea "pausada" difiere de la normal y se escapa del dedup de
`say_dialogue` → diálogo doble). Texto que generas tú (ya limpio, vía i18n) no necesita `clean`.

---

## 3. Localización: la convención i18n

**Regla dura: ningún texto hablado nuevo se hardcodea.** Cada cadena es una clave resuelta con
`PokeAccess::I18n.t(:clave)`, y el texto de cada idioma vive en `lang/<código>.txt`.

### Formato de `lang/*.txt`

Una clave por línea, `clave=texto`. Líneas en blanco y las que empiezan por `#` se ignoran.
Interpolación con `%{nombre}`:

```
# combate
bt_hp_change=%{name} %{verb} %{n} PS, quedan %{rest}
dbk_ball=%{name}, %{n}
```

### Usar una clave

```ruby
PokeAccess::I18n.t(:bt_shift)                                   # sin variables
PokeAccess::I18n.t(:dbk_ball, :name => item.name, :n => count)  # con %{name} y %{n}
```

`t` busca la clave en el idioma activo, cae al idioma de referencia (`:en`) y, si tampoco está, devuelve
el **nombre de la clave** — así un hueco se ve pero **nunca peta**. El idioma activo sale de
`Config.language`; `available_languages` lista los `lang/*.txt` presentes.

### Paridad es/en OBLIGATORIA

Cada clave nueva debe existir **en `lang/es.txt` Y en `lang/en.txt`** con el mismo nombre.
`PokeAccess::I18n.parity_issues` devuelve `[]` cuando todo está en sync, o la lista de problemas:

- `code:key: missing` — la clave está en un idioma y no en otro (la causa habitual de una línea en inglés
  dentro de una partida en español).
- `code:key: duplicated` — la clave aparece dos veces en el mismo archivo (gana la última, en silencio).
- `key: placeholders differ` — los `%{var}` no coinciden entre idiomas (la interpolación se rompe en uno).

Las claves `__meta__` (las que empiezan por `__`) se ignoran.

El arranque corre la comprobación y la registra como aviso; quien la convierte en error son los **dos tests
estáticos**:

| Test | Qué garantiza |
|---|---|
| `test/static/i18n_parity_spec.rb` | Que `parity_issues` esté **vacío**. Una release con una cadena descuadrada falla CI. |
| `test/static/i18n_refs_spec.rb` | Que **toda clave que el código referencia exista en `lang/en.txt`**. Sin él, una clave usada en código pero ausente de ambos idiomas le habla al jugador el nombre crudo de la clave y nada falla. |

El segundo escanea las llamadas literales `I18n.t(:clave)` en `core/` y `games/`, más las tablas cuyos
símbolos llegan a `I18n.t` de forma indirecta (etiquetas y ayudas del `SCHEMA`, unidades de `KIND_BOUNDS`,
categorías, tablas de estado/clima/terreno, `CMD_SYMS` de combate, botones del remapeador y entradas del
glosario de sonidos). Las claves construidas dinámicamente (`:"chr_#{kind}"`) no se pueden escanear: sus
familias se declaran como prefijos permitidos en el propio test, así que **al introducir una familia
dinámica nueva hay que añadir su prefijo ahí**.

---

## 4. ¿Clave i18n o string del juego? (la decisión que más se repite)

Al escribir un lector, parte del texto lo pones tú y parte viene del juego. La regla:

| Qué dices | Cómo |
|-----------|------|
| Etiqueta FIJA del mod (categoría, "Volver", "nivel %{n}", "PS %{hp} de %{tot}") | **clave i18n** (`t(:dbk_back)`...) |
| Dato DINÁMICO del juego ya en su idioma (nombre de objeto, descripción de una carta, nombre de personaje) | **el string del juego tal cual**, pasado por `clean` |
| Nombre de especie / movimiento / objeto por id | `PokeAccess::Data.species_name(id)` etc. (el provider lo localiza) |

El proyecto habla **español** (es su idioma), así que un string dinámico que el juego ya da en español se
dice tal cual — eso respeta el idioma del proyecto y no tiene sentido re-traducirlo. Lo que **sí** va por
clave es todo lo que el mod añade de su cosecha, para que tenga paridad es/en.

> Excepción documentada: en algunos juegos gen-6 hay strings que solo existen en español; pueden quedarse
> literales, pero prefiérase la clave i18n siempre que sea una etiqueta fija del mod.

---

## 5. Diagnóstico

El bloque de voz del diagnóstico (Ctrl+Alt+F9) resume el estado del puente:

```
voice: prism=true ready=true backend="NVDA" speaking=false
```

Si un lector no se oye, los fallos de su cuerpo se registran (deduplicados) en
`accessibility/data/hook_loaded.txt` vía `PokeAccess.log_once(clave, e)` / el `run_body` del motor de
hooks — así una pantalla que se quedó muda por un método renombrado deja rastro en vez de silencio sin
pista. Ver el flujo completo en [14_EXTENDING.md §7](14_EXTENDING.md).

## Próximo

- [16_CONFIG_MENU.md](16_CONFIG_MENU.md) — el menú de configuración que ve el usuario
- [14_EXTENDING.md](14_EXTENDING.md) — escribir lectores
