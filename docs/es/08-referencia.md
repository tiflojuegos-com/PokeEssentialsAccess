# Referencia

Firmas verificadas contra el código. El prefijo `PokeAccess::` se omite en las tablas y se indica en la línea
de cada grupo. Donde un método toma bloque, la columna de uso dice qué cede.

## Voz y braille

`core/speech/speech.rb` (el despachador), `backend.rb` (el puente con el lector), `categories.rb`, `text.rb` y
`core/dialogue/dialogue.rb` — módulos `PokeAccess` y `Speech`. Ver [04-lectores](04-lectores.md).

| Firma | Devuelve | Cuándo usarlo |
|---|---|---|
| `speak(text, interrupt = true, category = nil)` | Nada aprovechable | Hablar una línea ya limpia (una clave i18n resuelta). `interrupt` false encola; `category` la archiva en el historial (si falta, la del ámbito o la del momento) |
| `speak_clean(text, interrupt = true, category = nil)` | Nada aprovechable | Hablar texto que viene del JUEGO: aplica `clean` antes |
| `clean(text)` | String hablable | Quitar códigos `\PN`, `\V[n]`, `\C[n]`, etiquetas `<b>` y bytes de control |
| `stop_speech` | `true` si el backend obedeció; `false` sin puente | Callar al lector ya, sin decir nada nuevo |
| `pause_speech` | `true`/`false` | Pausar la voz en curso; depende del backend |
| `resume_speech` | `true`/`false` | Reanudarla |
| `speaking?` | `true`, `false` o `nil` | Saber si el lector sigue hablando |
| `braille(text)` | `true` si la pantalla braille lo aceptó | Enviar texto a la línea braille (UTF-8, como `speak`) |
| `braille_codepoints(cps)` | Igual que `braille` | Enviar un array de codepoints Unicode (celdas U+28xx) |
| `codepoints_to_utf8(cps)` | String de bytes UTF-8 | Convertir codepoints a UTF-8; salta lo que no sea BMP |
| `speech_backend` | `"NVDA"`, `"JAWS"`, `"SAPI 5"`... o `""` | Línea del diagnóstico |
| `speech_ready?` | `true` si el puente se levantó | Diagnóstico; un lector normal no lo necesita |
| `init_speech!` | Estado del puente | Lo llama `speak`; solo intenta una vez por sesión |
| `retry_init!` | Estado del puente tras reintentar | Olvidar un init fallido; lo llama el toggle Ctrl+Alt+F8 |
| `Speech.observe(key, &blk)` | El array de observadores | Observar TODO lo hablado: el bloque recibe un `Speech::Message` (`text`, `category`, `interrupt`, `seq`). Registrar la misma clave lo sustituye |
| `Speech.unobserve(key)` | Nada aprovechable | Quitar un observador |
| `Speech.as(category) { }` | Lo que devuelva el bloque | Archivar bajo una categoría todo lo dicho dentro del bloque, por hondo que sea |
| `Speech.category_of(given)` | Símbolo | La categoría de una línea: la dada, si no la del ámbito, si no `Speech.deduce` |
| `voice_out(text, interrupt)` | Nada | La única salida al lector. Los tests sustituyen solo esta, así que todo pasa por el `speak` real |
| `last_spoken` | Última línea no vacía hablada, o `nil` | Diagnóstico hablado |
| `say_dialogue(message)` | Nada | Limpiar, recordar y hablar ENCOLADA una línea de diálogo |
| `note_dialogue(text)` | Nada | Recordar una línea sin hablarla |
| `last_dialogue` | Última línea de diálogo, o `nil` | La repite la tecla de info con shift |

`speaking?` devuelve `nil` cuando el backend no sabe responder. Trata `nil` como desconocido, NUNCA como
silencio. Un observador que lanza se ignora: un instrumento no puede callar al mod. `say_dialogue` no repite una
línea idéntica dentro de 0,5 s.

**Categorías** (`Speech::CATEGORIES`): `:dialogue`, `:battle`, `:menu`, `:nav`, `:info` y `:system`, cada una con
su nombre hablado (`msg_cat_*`). Una línea toma la que nombra su llamada (el lector de diálogo, el cursor de los
menús, los minijuegos); si no, la del ámbito `Speech.as` más
interno (el lector de diálogos, el cursor de los menús, el localizador, las teclas de información y el menú del mod
envuelven su trabajo en uno); si no, la que deduce el momento: con un mensaje en pantalla, diálogo; en combate,
combate; fuera del mapa o con el menú de pausa, menú; en el mapa, navegación. La deducción es la red de las
llamadas que nadie marca, y se afina marcándolas, no ensanchando la red. `Speech::REVIEW` es la de las lecturas
del propio historial, que no se archivan.

## Historial de mensajes

`core/speech/history.rb` — módulo `History`. Observa el despachador y guarda en memoria las últimas líneas de la
sesión con su categoría, tantas como diga el ajuste `history_size` de Opciones generales (`History.capacity`: de 100
a 2000, 300 de serie; bajarlo se nota con la siguiente línea). No guarda sus propias lecturas ni la misma línea repetida en menos de un segundo (`REPEAT_WINDOW`) en la misma
categoría. Cada vista (todo, o una categoría) conserva su sitio, que no se mueve cuando llegan líneas nuevas; si la
línea de ese sitio ya salió por capacidad, la siguiente pulsación sigue por la primera que queda.

| Firma | Devuelve | Cuándo usarlo |
|---|---|---|
| `History.step(dir)` | Nada | Una línea atrás (`-1`) o adelante (`1`) en la vista; la primera pulsación lee la última |
| `History.to_end(dir)` | Nada | La primera (`-1`) o la última (`1`) |
| `History.switch_category(dir)` | Nada | La vista anterior o siguiente que tiene líneas, dicha con cuántas; «todo» siempre se ofrece |
| `History.lines_of(view)` | Array de `Speech::Message` | Las líneas de una vista, de la más vieja a la más nueva |
| `History.views` / `view` / `view_name(view)` | | Las vistas en orden, la actual y su nombre hablado |
| `History.clear` | Nada | Olvidarlo todo (los tests) |

Teclas: `hist_prev` (`Inicio`) y `hist_next` (`Fin`); con Ctrl van a los extremos y con Mayúsculas cambian de
categoría (`Keys.history_key`). Se reasignan como cualquier tecla del mod. Mayús+T, el último diálogo, no cambia;
Ctrl+T dice la fila enfocada entera (ver [Info contextual](#info-contextual)).

## Verbosidad

`core/speech/verbosity.rb`, `verbosity_schemes.rb` — módulos `Verbosity` y `VerbositySchemes`. Cuánto se dice al
moverse por los menús. Cada tipo de fila es una **lectura** (el registro `readings`) que se dice a un **nivel**: `:brief`,
`:medium` o `:full` (`LEVELS`). Un esquema fija el nivel de cada lectura: los tres de serie las ponen todas igual y
los del jugador una a una, como deslizadores, sin decir nunca más que `:full`, que es lo que el mod decía siempre y
el valor de serie. La tecla de información queda fuera: siempre lo dice todo.

| Firma | Devuelve | Cuándo usarlo |
|---|---|---|
| `Verbosity.line(reading, parts, sep = ", ")` | La fila | El constructor pasa sus partes como `[texto, nivel desde el que se dice]`; las vacías se caen. Un String suelto cuenta como `:full`, que es lo que añade un plugin |
| `Verbosity.info_line(reading, parts, sep = ", ")` | La fila al nivel | Publica la fila entera en la T y en Ctrl+T y devuelve la recortada: una pantalla sin ficha propia (una lista de la Pokédex, una misión, una casilla) |
| `Verbosity.full_line(parts, sep = ", ")` | La fila entera | La que repite Ctrl+T, el tercer argumento de `Info.set_info` |
| `Verbosity.whole { ... }` | Lo que devuelva el bloque | Construir una fila como la dice Completa, sea cual sea el esquema: la de Ctrl+T de un constructor que cambia de plantilla con el nivel |
| `Verbosity.keep?(reading, from)` | `true`/`false` | Cuando el nivel cambia algo más que qué partes entran (otra plantilla). Un nivel que no existe, una errata, cuenta como `:full` y deja una línea en el registro |
| `Verbosity.level(reading)` | `:brief`, `:medium` o `:full` | El nivel con el esquema activo (`level_in`: el de la lectura, si no el nivel `OTHERS` del esquema); un esquema que ya no existe la dice en `:full` |
| `Verbosity.list_entry(name, n, tot)` | «Pidgey, 3 de 8» o «Pidgey» | Una fila de lista con su posición |
| `Verbosity.position(i, n)` | «3 de 8» o `nil` | La posición suelta |
| `Verbosity.hints?` | `true`/`false` | Si se dicen las pistas de teclas que pinta una pantalla |
| `Verbosity.with_hint(text, hint, sep = ". ")` | La línea con su pista, o sola | Una línea del mod seguida de la tecla que la continúa |
| `Verbosity.descriptions?` | `true`/`false` | Si se dice lo que una pantalla explica de la opción enfocada (una ayuda, una regla, un logro, un efecto) o el detalle de un lugar del mapa de región; solo en Completa, y la T lo dice siempre |
| `Verbosity.active` | Símbolo | El esquema en uso: un nivel, o el nombre de uno del jugador |
| `Verbosity.rotation` / `next_scheme(dir)` | | Los de serie y luego los del jugador por nombre; el siguiente o el anterior |
| `Verbosity.use(scheme)` | Nada | Ponerlo en uso y guardar el ajuste |
| `Verbosity.rotate_scheme(dir = 1)` | Nada | La tecla de rotación: el siguiente, dicho como `:system` |
| `Verbosity.name_of(scheme)` / `reading_name(reading)` | String | Sus nombres hablados |
| `Verbosity.define_reading(reading, name_key, help_key)` | El símbolo | Declarar una lectura: las catorce del núcleo al final de `verbosity.rb`; un plugin o un perfil, las de sus pantallas |
| `Verbosity.readings` / `reading_row(reading)` | Filas `[lectura, clave del nombre, clave de la ayuda]` | Lo que lista el editor de esquemas, en orden de declaración |
| `Verbosity.level_in(levels, reading)` | Nivel | El que da un esquema a una lectura: el suyo, si no el de `OTHERS`, si no `:full` |

| Lectura | Breve | Media | Completa |
|---|---|---|---|
| `:party` | nombre, PS, estado o debilitado, apto o no apto | + nivel | + sexo, variocolor, Pokérus, objeto y marcas |
| `:battle_move`, `:summary_move` | nombre y PP | + tipo | + categoría, potencia, precisión y descripción |
| `:battle_marks` | no | los iconos de la caja de combate (capturado, variocolor, Mega, primigenio y los de cada juego), al entrar cada rival y con los PS | como Media |
| `:learn_move` | nombre | + tipo y coste | todo |
| `:bag_item` | objeto, cantidad y «moviendo» | + marcas y lo que la pantalla pinta de él (sabor, nivel, masa, qué miembros del equipo pueden usarlo) | como Media |
| `:shop_item` | objeto y precio | + cuántos hay en la mochila, marcas y lo que da una mejora | como Media |
| `:pc_slot` | nombre, nivel y debilitado | + posición y objeto | + sexo, variocolor, tipos, habilidad y marcas |
| `:dex_entry` | número y nombre, o «desconocido» | + capturado o visto y lo que añade la lista (rareza, estrellas, cifras de una región) | todo |
| `:dex_page` | número, nombre y capturado | + categoría, tipos y habilidades | + altura, peso, descripción, estadísticas base y, en una sublista de especies, la caja de la especie enfocada |
| `:ribbon` | la cinta o el recuerdo, o el hueco vacío | + dónde está | + su descripción |
| `:positions` | no | «3 de 10» y «página 2 de 3» | como Media |
| `:hints` | no | las pistas de teclas | como Media |
| `:descriptions` | no | no | lo que la pantalla explica de la opción: una ayuda, una regla, un logro, un efecto, una dificultad; y el detalle de un lugar del mapa de región, tras su nombre |

Las que declaran plugins y perfiles, solo en los juegos que los cargan:

| Lectura | Quién la declara | Breve | Media | Completa |
|---|---|---|---|---|
| `:quest` | `easy_questing`, `quest_ui`, Infinite Fusion Hoenn | la misión o el reto | + su estado y sus marcas (principal, nueva, recompensa lista) | + la recompensa de los retos |
| `:map_square` | `better_region_map`, `secret_bases`, Soulstones 2 | el lugar o la casilla, si se vuela o se coloca ahí, si está sin visitar, o lo que hay en ella al guardar decoraciones | + punto de interés, decoración o coordenadas | + la descripción de la casilla |
| `:hall_of_fame` | `hall_of_fame_bw`, Realidea | el Pokémon, su mote y, al entrar en él, el registro | + el nivel | todo lo de la ficha |
| `:pokemon_choice` | Armonía, Reminiscencia, Soulstones 2 | el nombre | + tipos o categoría | la ficha entera |
| `:rem_blessing` | Reminiscencia | lo que hace la carta | + su rareza | + su categoría |
| `:incubator` | `hatcher`, `incubator` | el hueco y, con huevo, los pasos que le faltan | como Breve | + la frase de la pantalla sobre cuánto le falta |

**Lecturas de plugins y juegos.** Un lector de plugin o de perfil que dice un tipo de fila que el núcleo no tiene
declara su lectura con `define_reading` (con sus claves `vb_*` y `vbh_*` en los seis idiomas). Como los lectores de
plugins solo se cargan en los juegos que los declaran, y el perfil solo en su juego, el editor enseña en cada juego
sus lecturas y ninguna más. Cada esquema guarda además `OTHERS`, el nivel de las lecturas que no nombra (las de otro
juego, las que añada una versión nueva): es la última fila del editor, «Otras lecturas», y sin ella esas lecturas se
dicen en Completa. Un esquema conserva los niveles de lecturas que el juego actual no tiene, así que llevarlo de un
juego a otro no pierde nada.

Cómo se convierte un lector: pasa sus partes con su nivel a `Verbosity.line` (o pregunta `keep?`); las filas de
movimientos pasan su lectura a `MoveInfo.leveled` (la T sigue llamando a `MoveInfo.line`, entero); una ventana de
información que va con la fila enfocada y solo se dice desde un nivel se declara con `InfoWindow.watch(...,
:reading => [lectura, nivel])`; su texto va siempre con la fila de Ctrl+T (`Info.add_to_row`). Un lector aún sin
convertir dice su fila entera en cualquier nivel: nunca se pierde nada por no estar hecho.

Lo que el nivel quita no se pierde. La T dice la ficha de lo enfocado, igual en cualquier nivel, y Ctrl+T la fila
entera, como la dice Completa. Una pantalla con ficha propia publica `Info.set_info(kind, dato, fila)`, con la fila
de `Verbosity.full_line(partes)` o, si su constructor cambia de plantilla con el nivel, de `Verbosity.whole {
constructor }`; una sin ficha, `Verbosity.info_line`, y suelta su `:text` al cerrarse (`Info.clear_text`) cuando lo
que queda debajo no publica nada al volver (en el mapa la T vuelve sola al entrenador). Las páginas
(«página 2 de 3») son posiciones: se dicen desde Media con `keep?(:positions, :medium)`. Las pistas pintadas se
filtran solas donde pasan por `KeyHints.gate` (líneas: `PaintCapture.speak_around` y `flush_pending`,
`PausePanel.say`, la tarjeta de entrenador) o por `KeyHints.gate_sentences` (frases: las ventanas de `InfoWindow`,
la pantalla de nombre de Añil); una pista que monta el propio mod se une con `Verbosity.with_hint`.

**Esquemas del jugador** (`VerbositySchemes`, un `Dictionary`): `verbosity.txt`, una línea por esquema,
`nombre=lectura:nivel,lectura:nivel`. Sin sello de juego (`game_bound?` falso): un esquema vale igual en cualquier
juego y se importa de cualquiera. El activo va en `settings.ini`, como símbolo con su nombre.

| Firma | Devuelve | Cuándo usarlo |
|---|---|---|
| `VerbositySchemes.levels(name)` | `{lectura => nivel}`, o `nil` | |
| `VerbositySchemes.names` | Los nombres, en orden | La rotación y la pantalla del menú |
| `VerbositySchemes.set(name, levels)` / `delete(name)` / `rename(old, new)` | Nada | Escriben el fichero al momento |
| `VerbositySchemes.valid_name?(name, except = nil)` | `true`/`false` | Ni en blanco, ni el de uno de serie (interno o hablado), ni el de otro, sin distinguir mayúsculas |
| `VerbositySchemes.clean_name(name)` | String | Una sola línea, sin `=` ni `#` inicial |

## Introspección defensiva

`core/foundation/const.rb`, `core/speech/markers.rb` — módulo `PokeAccess`.

| Firma | Devuelve | Cuándo usarlo |
|---|---|---|
| `const_at(name)` | La constante, o `nil` si falta cualquier segmento | Resolver `"A::B::C"` por nombre, 1.8.7-safe |
| `ivar(obj, sym, fallback = nil)` | El ivar, o `fallback` | Leer objetos del motor, que no exponen accessors |
| `ivar_i(obj, sym, fallback = 0)` | El ivar como Integer, o `fallback` | Igual, para ivars numéricos |
| `sprite(scene, key)` | El sprite de `@sprites[key]`, o `nil` | Alcanzar una ventana de una escena de Essentials |
| `attr_of(obj, *names)` | El primer accesor que responda no-`nil`, o `nil` | Accesores que Essentials renombró entre eras |
| `dedicate(win)` | `win` | Reclamar una ventana para un lector dedicado |
| `dedicated?(win)` | `true`/`false` | ¿Ya la reclamó alguien? Lo consulta el lector genérico |
| `expect!(key, value)` | `value` sin tocar | Registrar una vez que algo esperado salió `nil` |
| `DIR_DELTA` | `{ dirección => [dx, dy] }` | Dar un paso en una dirección RPG; la única tabla de direcciones |

`const_at` es para cuando quieres la CONSTANTE; para el booleano "¿existe?" la puerta única es `Engine.has?`.
En `attr_of` el orden importa: pon primero la ortografía que use la mayoría de juegos. `dedicate` marca
`@access_dedicated`, nunca el `@ignore_input` del motor, que congelaría el cursor de las ventanas Selectable.

## Hooks

`core/input/hooks.rb` — módulo `Hooks`. Ver [03-hooks](03-hooks.md).

| Firma | Devuelve | Cuándo usarlo |
|---|---|---|
| `Hooks.wrap(cname, meth, opts = {}, &mw)` | Nada | El motor: middleware crudo en la cadena. Cede `(obj, call_next, args)` |
| `Hooks.before_hook(cname, meth, opts = {}, &body)` | Nada | Hablar ANTES de que el original bloquee. Cede `(obj, args)` |
| `Hooks.after_hook(cname, meth, opts = {}, &body)` | Nada | El caso normal, con el resultado del original. Cede `(obj, result, args)` |
| `Hooks.around_hook(cname, meth, opts = {}, &body)` | Nada | Control total; el valor del cuerpo es el del método. Cede `(obj, call_next, args)` |
| `Hooks.frame_hook(cname, meth, &body)` | Nada | Driver por frame que puede alojar un bucle modal entero. Cede `(obj, args)` |
| `Hooks.read_on_open(cname, meth = :pbStartScene, opts = {}, &blk)` | Nada | Resumen de apertura, encolado y limpiado. Cede `(scene)`, devuelve el texto |
| `Hooks.override(target, meth, opts = {}, &body)` | Nada | REEMPLAZO declarado. Cede `(receiver, original, args)` |
| `Hooks.variants(names, meth, label = nil) { |cname| ... }` | Las grafías que ataron | Enganchar una pantalla por TODAS sus grafías y delatar el grupo que no ata en ninguna |
| `Hooks.unbound` | Array de `"grupo#metodo"` | Los grupos que no ataron en ningún sitio; el diag los imprime |
| `Hooks.wrap_global(name, tag, timing = :after, &body)` | Nada | Método top-level de `Object` (`pbDisplayMail`...). Cede `(args, x)` |
| `Hooks.wrap_kernel(name, tag, timing = :before, &body)` | Nada | Igual, probando primero el singleton de `Kernel`. Cede `(args, x)` |
| `Hooks.wrap_singleton(owner, name, tag, timing = :before, &body)` | Nada | Método singleton propio de un módulo del juego (`Owner.name`). Cede `(args, x)`; si falta, va a `fn_absent` como `"Owner.name"` |
| `Hooks.missing` | Array de `"Clase#metodo"` | La clase existe y el método no: PROBABLE TYPO |
| `Hooks.fn_absent` | Array de nombres de función | No estaban ni en `Kernel` ni en `Object`. Informativo |
| `Hooks.overrides` | Array de `"Target.meth (tag)"` | Los reemplazos instalados; el diagnóstico los imprime |
| `Hooks.suppressed` | Array de `"exterior>interior"`, tope 40 | Pares que la guarda de reentrancia descartó esta sesión |

`frame_hook` NO admite `opts`: fija `:hook_container` por dentro. En `around_hook`, `call_next` no toma
argumentos (reproduce los del llamante); para cambiarlos, muta `args` en su sitio. El fallo de un cuerpo
`around`/`override` se loguea y se RELANZA; el de los demás se traga.

En `wrap_global` / `wrap_kernel`, `timing` decide qué llega como `x`: `:before` → `nil`, `:after` →
resultado, `:around` → `call_next` (lo llamas tú). `override` acepta como `target` un módulo del mod
(sustituye su método de singleton) o el nombre en string de una clase del juego (su método de instancia).

| Opción | Efecto |
|---|---|
| `:optional => true` | El método falta legítimamente en algunos juegos: se salta en silencio en vez de contar en `Hooks.missing` |
| `:hook_container => true` | El método es un contenedor que delega el anuncio en métodos hookeados que él conduce: su original corre SIN la guarda de reentrancia |
| `:timing => :before` | Solo en `read_on_open`: para abridores que BLOQUEAN en su propio bucle |
| `:tag => "..."` | Solo en `override`: nombra al dueño en el listado de `overrides` |

Una CLASE ausente siempre es no-op silencioso: es variación normal entre juegos.

## Dedup de cursor

`core/menus/cursor.rb` — módulo `Cursor`. La primitiva por defecto de todo lector de cursor o selección. Ver
[04-lectores](04-lectores.md).

| Firma | Devuelve | Cuándo usarlo |
|---|---|---|
| `Cursor.changed?(holder, slot, key)` | `true` (y guarda la key) si difiere; `false` si no | Gatear trabajo arbitrario |
| `Cursor.on_change(holder, slot, key, &blk)` | El valor del bloque si cambió; `nil` si no | Calcular la línea perezosamente |
| `Cursor.announce(holder, slot, key, interrupt = true, first_interrupt = nil, &blk)` | Nada | El caso común: al cambiar, habla lo que devuelve el bloque |
| `Cursor.pending?(holder, slot)` | `true` en la PRIMERA lectura de un cursor fresco o reseteado | Distinguir la apertura de un movimiento posterior |
| `Cursor.reset(holder, slot)` | Nada aprovechable | Al (re)abrir una pantalla cuyo cursor puede seguir en la misma entrada |
| `Cursor.reset_global` | Nada | Limpiar la tabla de los lectores sin instancia; ya va registrada en `Caches` |

| Argumento | Qué es |
|---|---|
| `holder` | La escena o instancia donde vive el estado (ivar `@access_cur_<slot>`), así que muere con ella. `nil` usa una tabla global por slot |
| `slot` | Un símbolo propio de ese lector, en crudo (`:mi_lista`). Un `@` inicial se tolera y se descarta |
| `key` | Un índice, un texto o una tupla (`[página, índice]`) |

Una key `nil` cuenta SIEMPRE como "sin cambio": un valor ausente nunca habla. `pending?` se consulta ANTES
del `changed?` que registra la key. `announce` no hace nada si la línea es `nil` o vacía, y usa
`first_interrupt` solo cuando el slot está `pending?`.

## Bucles bloqueantes

`core/menus/scene_watcher.rb` — módulo `SceneWatcher`. Para pantallas que corren su propio bucle de entrada,
donde los hooks de cursor no disparan.

| Firma | Devuelve | Cuándo usarlo |
|---|---|---|
| `SceneWatcher.wire(cls, meth, reader)` | Nada | La plomería: `reader` responde a `watch(scene)`, `unwatch` y `poll` |
| `SceneWatcher.reader(cls, meth, slot, &blk)` | El holder generado | La forma de UNA llamada: sujeta, sondea, deduplica y habla. Cede `(scene)` |

El bloque de `reader` devuelve `[key, texto]`; `nil` o algo que no sea par salta el frame. Si `texto`
responde a `call`, solo se invoca cuando la key cambió, que es lo que hace barato un lector que pregunta al
juego para redactarse. Los bloques usan `next`, no `return` (`define_method` bajo 1.8.7).

## Motor

`core/foundation/engine.rb` — módulo `Engine`. Ver [02-motores](02-motores.md).

| Firma | Devuelve | Cuándo usarlo |
|---|---|---|
| `Engine.has?(cap)` | `true`/`false` | La puerta única de capacidad; nunca gatees por versión |
| `Engine.gamedata?` | `true` en la era GameData (v17+) | Elegir un proveedor o un lector por era |
| `Engine.gen6?` | El opuesto | Igual |
| `Engine.kind` | `:gamedata` o `:gen6` | Etiquetar una línea o indexar una tabla por era |
| `Engine.player` | `$player`, `$Trainer` o `nil` | El objeto jugador sin saber la era |
| `Engine.bag_quantity(item)` | Integer, o `nil` si no responde ninguna bolsa | Cuántos hay de un objeto sin saber la era |
| `Engine.version` | Float comparable: 16.0, 19.0, 21.1... memoizado | SOLO la línea del diagnóstico |
| `Engine.fork` | `:sky` o `nil` | SOLO la línea del diagnóstico |
| `Engine.scene_classes(*names)` | Array de nombres a enganchar | Varias clases candidatas: descarta las que otra ya cubre |
| `Engine.scene_class(*names)` | El primer nombre, o `nil` | ALIAS de una misma pantalla: engancha uno solo |
| `Engine.era_scene(era, own, other)` | El nombre a enganchar, o `""` | Lector escrito contra UNA era cuando ambos alias existen |

`has?` admite tres formas: un símbolo registrado (`:ui_rework`), un nombre de clase (`"UI::BaseScreen"`), o
clase más método de instancia (`"Battle::Scene::MenuBase#setIndexAndMode"`). Un símbolo no registrado se
apunta una vez en el log y responde `false`. Un `""` de `era_scene` no engancha nada, igual que una clase
ausente.

| Símbolo de `CAPABILITIES` | Prueba |
|---|---|
| `:gamedata` / `:gen6` | La era del motor |
| `:sky_fork` | El fork Sky |
| `:ui_rework` | `UI::BaseScreen` (el rework de UI de v22) |
| `:battle_scene` | `Battle::Scene` (la escena de combate de v19+) |
| `:dbk` | `Battle#pbToggleSpecialActions` (Deluxe Battle Kit) |
| `:mui` | `UIHandlers` (Modular UI Scenes) |

Los dos últimos son plugins de terceros y están ahí para el DIAGNÓSTICO, no para gatear: sus lectores se
enganchan por método con `:optional`. Una pantalla concreta no necesita registro: pásale su nombre de clase
a `has?` directamente.

## i18n

`core/foundation/i18n.rb` — módulo `I18n`. Ver [05-extender](05-extender.md).

| Firma | Devuelve | Cuándo usarlo |
|---|---|---|
| `I18n.t(key, vars = nil)` | El string traducido | Todo texto hablado; `vars` es un hash `%{nombre} => valor`, y `:n` elige la forma de plural |
| `I18n.plural_form(code, n)` | `"one"`, `"few"`, `"many"` u `"other"`: la forma que va con `n` según la regla CLDR del idioma | Saber qué forma leerá `t` |
| `I18n.plural_forms(code)` | Las formas que escribe ese idioma (`%w[one other]`, o `%w[one few many]` en polaco) | La paridad |
| `I18n.lang` | Símbolo del idioma activo: la elección explícita, o lo que resuelve `:auto` (sistema, juego, inglés) | Leer el idioma sin tocar `Config` |
| `I18n.available_languages` | Array de símbolos con fichero en `lang/` | Menú de idioma |
| `I18n.language_name(code)` | La entrada `__language__`, o el código | Nombre humano en el menú |
| `I18n.next_language(code)` | El siguiente del ciclo, `:auto` primero | Toggle de idioma |
| `I18n.interpolate(s, vars)` | El string con `%{nombre}` sustituido | Interpolar aparte de `t`; una var ausente da `""` |
| `I18n.parity_issues` | Array de `"code:clave: razón"`; `[]` si todo cuadra | El check de boot y la suite |
| `I18n.table(code)` | Hash clave => valor, cacheado | Inspeccionar una tabla entera |
| `I18n.duplicate_keys(code)` | Array de claves repetidas en un fichero | Diagnóstico de un `lang/*.txt` |

`t` no lanza nunca: una clave que falta cae al idioma de referencia y luego al nombre de la clave, así que se
oye la clave en crudo. Una clave escrita por formas (`clave.one=`, `clave.other=`...) se busca con la forma que
va con `vars[:n]`. `parity_issues` cubre cuatro faltas: clave presente en un idioma y ausente en otro, clave
duplicada dentro de un fichero, placeholders `%{}` que difieren entre idiomas o entre formas, y formas que no son
las de la regla del idioma (falta una, sobra una, o la clave está a la vez sin formas y con ellas).

## Datos

`core/data/data.rb` — módulo `Data`. Ver [04-lectores](04-lectores.md).

| Firma | Devuelve | Cuándo usarlo |
|---|---|---|
| `Data.species_name(id)` | `"Pikachu"`, o `nil` | Nombre de especie sin saber la era |
| `Data.species_entry(id)` | La entrada de la pokédex, o `nil` | Texto de la ficha |
| `Data.move_name(id)` | `"Placaje"`, o `nil` | |
| `Data.move_type_name(id)` | `"Normal"`, o `nil` | |
| `Data.move_power(id)` | `40`, o `nil` | |
| `Data.move_accuracy(id)` | `100`, o `nil` | |
| `Data.move_description(id)` | Texto, o `nil` | |
| `Data.type_name(id)` | `"Fuego"`, o `nil` | |
| `Data.item_name(id)` | `"Poción"`, o `nil` | |
| `Data.item_name_plural(id)` | `"Pociones"`, o `nil` | Cantidades |
| `Data.item_description(id)` | Texto, o `nil` | |
| `Data.item_id(sym)` | El id interno de `:POTION`, o `nil` | Traducir un símbolo a id |
| `Data.ability_name(id)` | `"Estática"`, o `nil` | |
| `Data.nature_name(id)` | `"Miedosa"`, o `nil` | |
| `Data.stat_name(stat)` | `"Ataque"`, o `nil` | Acepta símbolo o índice, según el motor |
| `Data.status_name(status)` | `"Envenenado"`, o `nil` | |
| `Data.pokemon_types(pk)` | Array de nombres de tipo; `[]` si no resuelve | Tipos de un Pokémon concreto |
| `Data.species_types(id)` | Array de nombres de tipo; `[]` si no resuelve | Tipos de una especie, sin Pokémon al que preguntar |
| `Data.trainer_type_name(id)` | `"Montañero"`, o `nil` para una clase que el juego no tiene | Una clase de entrenador por número, constante o id |
| `Data.register(priority, provider)` | Nada | Registrar un proveedor: 20 GameData, 10 gen-6, 0 fallback |
| `Data.active` | El proveedor activo, o `nil` | Diagnóstico |
| `Data.active_priority` | La prioridad del activo, o `nil` | `0` significa que solo quedó el fallback |
| `Data.active_entry` | `[prioridad, proveedor]`, o `nil` | Diagnóstico |
| `Data.resolve(method, arg)` | Lo que devuelva el proveedor, o `nil` | El embudo: añadir un resolutor nuevo |
| `Data.errors` | Array de strings; `[]` en una run limpia | Excepciones del proveedor, una por `(método, clase)` |

`pokemon_types` y `species_types` son los únicos que nunca devuelven `nil`. El resto responde `nil` tanto si no hay proveedor como
si el dato falta de verdad; una excepción del proveedor se registra en el marker y también responde `nil`,
para que el lector degrade sin romperse.

## Plugins

`core/foundation/plugins.rb` — módulo `Plugins`. La tabla la llena el loader; aquí no se carga nada.

| Firma | Devuelve | Cuándo usarlo |
|---|---|---|
| `Plugins.loaded` | Array de nombres cargados esta sesión | Diagnóstico |
| `Plugins.note_loaded(name)` | Nada | Lo llama el loader al evaluar cada lector declarado |
| `Plugins.table` | Hash nombre => sonda, de `plugins/manifest.rb` | Consultar qué delata a cada plugin |
| `Plugins.table = t` | El hash asignado | Lo asigna el loader; algo que no sea Hash queda en `{}` |
| `Plugins.game_plugins` | Array `"nombre versión"` ordenado, o `nil` | Lo que el propio `PluginManager` del juego declara |
| `Plugins.undeclared` | Array ordenado | Plugins presentes cuyo lector nadie declaró: están mudos |

`game_plugins` devuelve `nil`, no `[]`, cuando el juego no tiene `PluginManager`: los juegos antiguos pegan
el código del plugin en la lista de scripts y "ninguno instalado" sería mentira. La sonda de `undeclared`
pasa por `Engine.has?`, así que puede nombrar un método y no solo una clase.

## Captura de pintado, retorno de menú, texto por build y autochequeo

`core/util/paint_capture.rb`, `core/menus/menu_return.rb`, `core/foundation/game_lang.rb`, `core/util/selfcheck.rb`.

| Firma | Devuelve | Cuándo usarlo |
|---|---|---|
| `PaintCapture.arm(tag)` / `PaintCapture.take(tag)` | `take`: las filas pintadas mientras `tag` estuvo armado, o `nil` | Leer una pantalla por lo que PINTA (`drawTextEx`, `pbDrawTextPositions`), que es correcto en builds por idioma |
| `PaintCapture.speak_around(tag, interrupt) { nxt.call }` | El valor del bloque | La forma común: arma, corre el pintado del juego y habla lo que cayó, sin sus pistas de teclas mientras la verbosidad las calla |
| `PaintCapture.flush_pending(tag, interrupt)` | — | Desde un poll por frame, para una etiqueta armada antes de un bucle bloqueante; filtra las pistas igual |
| `MenuReturn.on_return { ... }` | — | Un menú con bucle propio que re-lee la opción al volver de un submenú; se dispara solo en la salida más externa |
| `MenuReturn.bare("Clase", :metodo)` / `MenuReturn.bare_fn("funcion")` | — | Declarar una pantalla que se abre sin fade ni diálogo |
| `GameLang.code` / `GameLang.pick(value, fallback)` | `:es`, `:en`, `:fr`... o `nil`; `pick` elige la entrada de la build | Texto transcrito de una imagen en un juego con varias builds por idioma |
| `SelfCheck.run` | Las líneas del informe; escribe `data/selfcheck.txt` | La entrada "autochequeo del motor" del menú de configuración |

## Utilidades

`core/util/` — módulos `Util` y `KVFile`.

| Firma | Devuelve | Cuándo usarlo |
|---|---|---|
| `Util.join_parts(parts, sep = ". ")` | String, descartando nils y blancos | El idioma "nombre. detalle. extra" donde cualquier pieza puede faltar |
| `Util.types_phrase(t1, t2)` | `"tipo1/tipo2"`, colapsado y sin duplicados | Nombres de tipo sueltos; para un Pokémon usa `Data.pokemon_types` |
| `Util.playtime_parts(secs)` | `[horas, minutos]`, o `nil` si `secs` es `nil` | Tiempo de juego de la ficha o del hueco de guardado |
| `Util.dex_seen?(sp)` | `true`/`false`, o `nil` si nada resuelve | Vistos, tolerante a cómo cada motor expone la pokédex |
| `Util.dex_owned?(sp)` | Igual | Capturados |
| `Util.badge_count(who)` | Integer, o `nil` | Medallas, sea `numbadges`, `badge_count` o el array |
| `Util.union_groups(n, &blk)` | Array de grupos de índices | Agrupar por union-find; el bloque decide si `i` y `j` van juntos |
| `KVFile.each(path, opts = {}, &blk)` | Nada | El único parser de los `.txt` clave=valor del mod. Cede `(key, value)` |

`dex_seen?`/`dex_owned?` distinguen "no visto" (`false`) de "no se sabe" (`nil`). En `KVFile.each`,
`:strip_value => false` conserva los espacios iniciales del valor, que en las tablas de idioma son parte del
texto hablado. Un fichero que no existe no cede nada y no es error.

## Diagnóstico y reloj

`core/speech/markers.rb`, `core/foundation/perf.rb`, `core/util/recorder.rb`, `core/input/diag.rb`. Ver
[07-diagnostico](07-diagnostico.md).

| Firma | Devuelve | Cuándo usarlo |
|---|---|---|
| `write_marker(extra = "")` | Nada | Escribir una línea al marker de carga |
| `log_once(key, e)` | Nada | Registrar el PRIMER fallo por clave; acepta excepción o string |
| `format_error(e)` | `"Clase: mensaje @ frame <- frame <- frame"` | Formatear una excepción para el marker |
| `clock` | Float: segundos desde que cargó el mod | Única fuente del ritmo de las señales |
| `freq_to_seconds(f)` | Float: segundos entre señales para un ajuste 0-100 | ~0,15 s a 100, ~1,5 s a 0 |
| `tone_to_pitch(tone)` | Integer: tasa de reproducción en porcentaje para un tono 0-100 | 50 a 0, 100 a 50, 200 a 100: una octava por lado |
| `uptime_scale` | Float, o `nil` mientras no se pueda medir | Divisor para comparar dos `System.uptime` del motor |
| `Perf.measure(label, &blk)` | El valor del bloque | Medir un hook por frame; acumula suma, máximo y cuenta |
| `Perf.report` | String de una línea, o `"(sin datos)"` | Imprimir medias y máximos en ms |
| `Perf.reset` | Nada | Empezar una ventana de medición limpia |
| `Recorder.toggle` | Nombre de fichero al arrancar, número de eventos al parar | El gesto único del menú de depuración |
| `Recorder.start` | Nombre del fichero, o `nil` si no pudo | Arrancar una grabación de sesión |
| `Recorder.stop` | Número de eventos de TODA la sesión | Pararla y volcar lo pendiente |
| `Recorder.recording?` | `true`/`false` | |
| `Recorder.path` | Ruta del fichero actual o del último, o `nil` | |
| `Recorder.note(kind, *fields)` | Nada | Añadir un evento; tabuladores y saltos se sustituyen |
| `Recorder.on_change(kind, key, *fields)` | `true` si escribió | Registrar solo cuando el campo cambió |
| `Keys.register_diag_section(name, group = :scene, &body)` | Nada | Sección propia en el volcado. Cede el array de líneas |
| `Keys.diag_build(sections)` | El volcado como String | Construir un subconjunto de secciones |
| `Keys.diag_dump` | Nada | Volcar todo a `diag.txt` y hablar el resumen |
| `Keys.diag_section_to_clip(group)` | Nada | Copiar un subconjunto al portapapeles |

`clock` es tiempo de pared a propósito: `System.uptime` no devuelve segundos en el mkxp-z de algún fangame y
`Graphics.frame_count` salta al cargar partida. Los pasos NO pasan por aquí: suenan al cambiar de casilla,
así que siguen al jugador aunque acelere con el turbo.

## Rutas

`core/nav/pathfinder.rb` y sus partes (`route_search.rb`, `route_grid.rb`, `route_terrain.rb`, `route_events.rb`,
`route_water.rb`, `route_gates.rb`, `route_text.rb`), `core/nav/terrain.rb`,
`core/nav/event_pages.rb`, `core/nav/field_moves.rb` y `core/nav/map_meta.rb`. Ver
[06-navegacion](06-navegacion.md).

| Firma | Devuelve | Cuándo usarlo |
|---|---|---|
| `Pathfinder.find_path(tx, ty)` | Array de códigos de dirección RPG, o `nil` si no hay ruta | Ruta a una casilla contigua al destino; el origen es `$game_player` |
| `Pathfinder.find_path_onto(tx, ty)` | Igual, acabando encima | Orillas, puntos de buceo: casillas que se pisan |
| `Pathfinder.gated_path(tx, ty)` | `[pasos, paso]`, o `nil` | Sin ruta andando: hasta el primer paso asistido (un árbol o roca, un empuje, el botón de acción, bajarse de la bici); `nil` en el acto donde nada puede ayudar (`assist_possible?`) |
| `Pathfinder.trace(x, y, nivel, path)` | Array de `Step`, uno por pulsación (dentro de un tramo, `mid`) | Rehacer una ruta con los mismos movimientos que la búsqueda |
| `Pathfinder::Step.new(x, y, nivel, presses = 1, gate = nil, mid = false)` | Un paso: `x`, `y`, `level`, `presses`, `gate`, `mid`, y `tile` (`[x, y]`) | Lo que devuelven `move_target`, `trace` y un `assist_source` |
| `Pathfinder.vehicle_state` | Integer: `map_id * 8`, +4 surfeando, +2 buceando, +1 en bici | Para qué estado valen la memo de pasabilidad y los índices de eventos |
| `Pathfinder.event_epoch` | `[vehicle_state, vueltas]` | Una ruta guardada con otro valor se comprueba antes de fiarse de ella |
| `Pathfinder.path_to_text(path, cut = false)` | `"3 arriba, 2 izquierda"` | Hablar una ruta; `nil` da "sin ruta" (con `cut`, "no se ha podido calcular la ruta desde aquí") y `[]` da "al lado" |
| `Pathfinder.cuts` | Entero | Búsquedas cortadas hasta ahora (presupuesto, tope de nodos, fuera de alcance): compararlo antes y después distingue "sin ruta" de "no calculada" |
| `Pathfinder.no_route_text(cut)` | El texto de un destino sin ruta | Lo que dicen las guías y el localizador |
| `Pathfinder.legs(path)` | `[[8, 3], [4, 2]]` | Partir la ruta en tramos; `nil` y `[]` dan `[]` |
| `Pathfinder.leg_text(leg)` | `"3 arriba"` | Hablar un solo tramo (la guía paso a paso) |
| `Pathfinder.reachable_set` | Hash `pkey => true`, cacheado por casilla del jugador | Filtro de inalcanzables y línea de visión del sonar |
| `Pathfinder.flood(water = false)` | `[hash, completo]`, sin caché | Recalcular a la fuerza; con `true`, cruzando agua surfeando |
| `Pathfinder.pkey(x, y)` | `x * 100000 + y` | Empaquetar o desempaquetar las claves de `reachable_set` |
| `Pathfinder.reach` | Integer de tiles (`Config.route_reach`) | Distancia máxima que la búsqueda considera |
| `Pathfinder.invalidate_cache(force = false)` | Nada | Tras un evento que cambió la pasabilidad |
| `Pathfinder.passable_at?(cx, cy, d)` | `true`/`false` | ¿Se puede dar un paso en esa dirección? |
| `Pathfinder.ledge_jump(cx, cy, dx, dy, d)` | `[x, y]` de aterrizaje, o `nil` | ¿Hay salto de ledge por ahí? |
| `Pathfinder.surf_launch(tx, ty)` | Ruta a la orilla cuya agua lleva al destino, o `nil` | El destino está al otro lado del agua |
| `EventPages.outcome(ev, d, at = nil, act = false)` | `Outcome` (movimiento, transferencia, rampa, si habla, combate o cambia algo, si movió con Through), o `nil` | Qué haría la página activa de un evento al entrar mirando a `d`; `at` es la casilla del jugador, para las condiciones que la preguntan; `act` la lee como una página de acción respondiendo que sí |
| `EventPages::ScriptCondition.register_atom(pattern) { \|m, ctx\| ... }` | Nada | Una llamada propia de un juego en las condiciones; `ctx` trae `:face`, `:pos`, `:self`, `:act`, `:vars` |
| `Pathfinder.touch_source { \|ev\| ... }` | Nada | Un plugin da a sus eventos un efecto al pisarlos (el `:run` de las escaleras laterales) |
| `Pathfinder.arrival_rule { \|x, y, d\| ... }` | Nada | Terreno que mueve al llegar: `[x, y]`, `false` si el paso no vale, `nil` si no es suyo |
| `Pathfinder.leave_rule { \|x, y, dir\| ... }` | Nada | Terreno que se deja con un movimiento propio |
| `Pathfinder.held_key_rule { \|x, y\| ... }` | Nada | Casillas donde hay que mantener la tecla |
| `Pathfinder.assist_source { \|x, y, dir, nivel\| ... }` | Nada | Un paso asistido que añade un juego o plugin: un `Step` con su puerta, o `nil` |
| `FieldMoves.can?(move)` | `true`, `false`, o `nil` si no se pudo leer | ¿Puede el jugador usar esa MO fuera de combate? |
| `MapMeta.outdoor?(map_id)` / `MapMeta.dive_map(map_id)` | `true`/`false`/`nil` / id del mapa de buceo, o `nil` | Metadatos del mapa en las dos eras |
| `MapMeta.always_bicycle?(map_id)` | `true`/`false` | Mapa de bici obligatoria: ni bajarse ni surfear |
| `MapMeta.pokecenter?(map_id)` | `true`/`false` | Centro Pokémon: el mapa declara su punto de curación |
| `Pathfinder.blocked_target?(tx, ty)` | `true` si el destino es claramente inalcanzable | Rechazo rápido antes de un A* completo |
| `Pathfinder.path_algorithm` | Símbolo de `ALGORITHMS`; `:astar` por defecto | Leer el algoritmo configurado |
| `Terrain.raw(x, y, count_bridge = false)` | Integer (gen-6) u objeto `GameData::TerrainTag`, o `nil` | El valor crudo del motor |
| `Terrain.number(t)` | El `id_number` de un valor crudo, o `nil` | Normalizar las dos formas |
| `Terrain.kind(x, y, count_bridge = false)` | Símbolo estable (`:ice`, `:bridge`...), o `nil` | Clasificar una casilla; un número gen-6 va por el nombre que le da su `PBTerrain` |
| `Terrain.bridge_holder` / `Terrain.bridge_height` | El objeto que guarda la altura de puente (`$PokemonGlobal`, o `$PokemonMap` antes de la v16) / la altura, `0` fuera de todo puente | Leer el puente allí donde lo guarde el motor |
| `Terrain.label(x, y)` | Clave i18n de superficie (`:surf_water`...), o `nil` | Hablar la superficie pisada |
| `Terrain.surfable?(t)` | `true`/`false` | Predicado sobre un VALOR de terreno, no coordenadas |
| `Terrain.ledge?(t)` | `true`/`false` | Idem |
| `Terrain.ice?(t)` | `true`/`false` | Idem |
| `Terrain.bridge?(t)` | `true`/`false` | Idem |
| `Terrain.grass?(t)` | `true`/`false` | Idem (hierba normal, alta o de hollín) |
| `Terrain.flag?(t, flag)` | `true`/`false` | Una marca que un plugin o un juego añade a la etiqueta moderna (corriente, roca trepable, raíl, deslizamiento) |
| `Terrain.surfable_at?(x, y)` | `true`/`false` | Variante por coordenada |
| `Terrain.ledge_at?(x, y)` | `true`/`false` | Variante por coordenada |
| `Terrain.ice_at?(x, y)` | `true`/`false` | Variante por coordenada |
| `Terrain.number_at(x, y)` | El `id_number`, o `nil` | Variante por coordenada de `number` |
| `Terrain.flag_at?(x, y, flag)` | `true`/`false` | Variante por coordenada de `flag?` |

`find_path` devuelve DIRECCIONES, no coordenadas: los códigos RPG 8 arriba, 2 abajo, 4 izquierda, 6 derecha,
uno por paso. `path_to_text` consume exactamente eso. Las variantes por coordenada son `surfable_at?`,
`ledge_at?`, `ice_at?`, `number_at` y `flag_at?`; para `grass?` y `bridge?` hay que pasar por `raw(x, y)`.

`invalidate_cache` sin `force` se estrangula a una vez cada dos segundos, porque una escena con muchos
eventos dispararía un re-flood costoso por cada uno. Pásale `true` desde donde SEPAS que la pasabilidad
cambió.

## Localizador

`core/nav/locator.rb`, `core/nav/guide.rb`, `core/nav/locator_naming.rb` — módulo `Locator`. Ver
[06-navegacion](06-navegacion.md).

| Firma | Devuelve | Cuándo usarlo |
|---|---|---|
| `Locator.rebuild_targets` | Nada | Reconstruir la lista de la categoría actual, ordenada por distancia |
| `Locator.step(delta)` | Nada | Avanzar o retroceder en la lista (+1/-1) |
| `Locator.cycle_category(dir)` | Nada | Cambiar de categoría (+1/-1) |
| `Locator.select_current` | Nada | Seleccionar el objetivo enfocado y anunciarlo |
| `Locator.announce_selected(withname)` | Nada | Decir el objetivo; `withname` antepone el nombre y el ordinal |
| `Locator.announce_route` | Nada | Decir la ruta hacia el objetivo seleccionado |
| `Locator.announce_coords` | Nada | Decir el nombre del mapa y las coordenadas |
| `Locator.toggle_hide_unreachable` | Nada | Alternar el filtro de inalcanzables; persiste y reconstruye |
| `Locator.rename_target` | Nada | Pedir una etiqueta para el objeto enfocado y persistirla |
| `Locator.rename_map` | Nada | Pedir un nombre para el mapa y persistirlo |
| `Locator.tag_menu` | Nada | Abrir el menú de etiquetado, recategorización y ocultado |
| `Locator.show_menu(msg, choices, cancel)` | El índice elegido, o el de cancelar | Menú de elección que funciona en las dos eras |
| `Locator.map_poll` | Nada | El trabajo por frame del localizador; lo llama el driver por frame |
| `Locator.forget_map` | Nada | Olvidar el mapa actual para que se vuelva a anunciar |
| `Locator.toggle_guide` | Nada | Alternar el bastón guía |
| `Locator.toggle_steps` | Nada | Alternar la guía paso a paso |
| `Locator.register_hazard(re, label_key)` | Nada | Sprite de peligro: etiqueta más señal propia |
| `Locator.register_teleporter(re)` | Nada | Sprite que cuenta como teletransporte |

`show_menu` existe porque gen-6 solo expone `Kernel.pbMessage` y el moderno solo el `pbMessage` global;
llamar al ausente lanza `NoMethodError`.

## Mapa de la región

`core/nav/town_map.rb` — módulo `TownMap`. Mover el cursor del mapa es lo único que las tres
implementaciones no comparten (leer sí: `pbGetMapLocation` / `pbGetMapDetails` / `pbGetHealingSpot` se
llaman igual en los trece juegos), así que este registro existe solo para el salto de vuelo.

| Firma | Devuelve | Cuándo usarlo |
|---|---|---|
| `TownMap.register(name, handles, cursor, move, points, flyable = nil)` | Nada | Registrar un proveedor de cursor; gana el último registrado, así que un perfil pisa a los de core |
| `TownMap.jump_enabled = false` | Nada | Ceder el salto a la pantalla, cuando el juego ya trae uno propio |
| `TownMap.opened(scene)` / `.closed(scene)` | Nada | Marcar la pantalla abierta y soltarla al cerrar |
| `TownMap.jump(scene, dir)` | `true` si saltó | Saltar al punto de vuelo más cercano en esa dirección |

`handles` es una lambda que recibe la escena y responde si este proveedor la reconoce. La detección va por
FORMA (qué métodos e ivars tiene la escena) y nunca por nombre de clase ni versión de motor: Arcky's Region
Map y el rework de v21+ declaran ambos `PokemonRegionMap_Scene` con el cursor en ivars distintos.
`flyable` solo hace falta en una pantalla que conozca su propio conjunto de destinos; sin él, la regla
genérica lo deriva de `pbGetHealingSpot` más `visitedMaps`.

`plugins/better_region_map.rb` es un proveedor registrado desde la capa de plugins, para el addon BetterRegionMap
(Marin) que instalan los dos Infinite Fusion: es una clase propia, con su bucle, su cursor en `$PokemonGlobal.regionMapSel` y sin
`pbGetMapLocation`, así que ningún hook del mapa estándar la alcanza.

## Audio

`core/audio/audio3d.rb`, `core/audio/spatial.rb` — módulos `Audio3D` y `Spatial`. Ver
[06-navegacion](06-navegacion.md).

| Firma | Devuelve | Cuándo usarlo |
|---|---|---|
| `Audio3D.boot` | `true` si quedó listo | Inicializar la dll y los canales una sola vez |
| `Audio3D.available?` | Valor truthy si la dll y sus entry points resolvieron | Comprobar la dll antes de nada |
| `Audio3D.device_rate` | 44100 o 48000, `nil` antes del boot | Elegir el fichero de sonido correcto |
| `Audio3D.device_latency` | Latencia en ms, `nil` antes del boot | Diagnóstico |
| `Audio3D.range` | Integer de tiles | Radio de detección de emisores |
| `Audio3D.wall_range` | Integer de tiles | Alcance del sondeo de paredes y viento |
| `Audio3D.alt_dist` | Integer de tiles | Distancia bajo la cual dos emisores alternan en vez de sonar a la vez |
| `Audio3D.occlusion_mode` | `:hear`, `:occlude` o `:hide` | Qué hacer con un emisor tras una pared |
| `Audio3D.wav(name)` | Ruta del `.wav` según la frecuencia del device | Resolver un fichero de sonido |
| `Audio3D.tick` | Nada | Un frame de sonar; lo llama el hook de `Game_Player#update` |
| `Audio3D.bump(dir, interact = false)` | `true` si atendió la señal | Choque contra pared u objeto, paneado a esa casilla |
| `Audio3D.guide(dir, vol)` | `true` si atendió | Señal del bastón guía, paneada hacia el siguiente paso |
| `Audio3D.guide_hold(dir, vol = 0, pitch = 100)` | `true` si atendió | El sonido del bastón sostenido hacia `dir` (bucle), o parado con `dir` `nil` |
| `Audio3D.footstep(kind, vol)` | `true` si atendió | Paso, centrado en el jugador |
| `Audio3D.preview(sym, vol, pitch)` | `true` si atendió | Audición del menú: un canal centrado en el jugador al volumen y tono dados |
| `Audio3D.preview_stop(sym)` | Nada | Cortar la audición de un bucle (agua, viento) |
| `Audio3D.sync_tones` | Nada | Enviar a la dll los tonos que cambiaron, una vez por cambio; lo llama `tick` |
| `Audio3D.tone_pitch(sym)` | Porcentaje de la grabación | Tono configurado de la familia de un canal (`TONE_KEYS`) |
| `Audio3D.loop?(sym)` | `true`/`false` | ¿El canal es un bucle? |
| `Audio3D.silence_all` | Nada | Callar todos los canales |
| `Audio3D.silence_emitters` | Nada | Callar emisores y bucles dejando pasos y choques (modo `:basic`) |
| `Audio3D.reset_map_state` | Nada | Soltar el escaneo del mapa anterior |
| `Audio3D.nav_full?` | `true`/`false` | ¿Modo completo (todos los emisores)? |
| `Audio3D.nav_off?` | `true`/`false` | ¿Apagado del todo? Entonces el motor ni arranca |
| `Audio3D.gate_report` | `"n/total playing by=..."` y limpia la ventana | Por qué un tick sonó o calló |
| `Spatial.cue(name, volume, pitch = 100)` | Nada | Reproducir un fichero de `sounds/`; volumen 0 o `nil` no suena |
| `Spatial.earcon(name, volume, pitch = nil)` | Nada | Earcon con nombre de `EARCONS`; el pitch de la tabla es el defecto |
| `Spatial.tone_factor(key, low = 100, high = 100)` | Float | Factor del tono de una familia para una cue plana, reducido hasta que el par `low`/`high` cabe en el 50-150 de mkxp |
| `Spatial.guide_tone_factor` | Float | El factor de toda la familia guía (motor y canal plano): el que mantiene su par 140/70 dentro de 50-150 |
| `Spatial.busy?` | `true`/`false` | El jugador NO tiene control libre: el paisaje sonoro calla |
| `Spatial.busy_reason` | Símbolo (`:message`, `:in_menu`, `:battle`...) o `nil` | Nombrar la causa en el diagnóstico |
| `Spatial.keys_locked?` | `true`/`false` | Otra pantalla posee de verdad las flechas |
| `Spatial.mini_update?` | `true`/`false` | El mapa se actualiza desde dentro del bucle de un mensaje o un menú (`in_mini_update`, `$PokemonTemp.miniupdate`) |
| `Spatial.tick` | Nada | Un frame de pasos, choques, radar y superficies |

`available?` devuelve el último objeto `Win32API` de la cadena, no un booleano: úsalo solo como condición.
`busy?` es cierto con un mensaje o un intérprete corriendo; `keys_locked?` no, para que las teclas del
localizador sigan usables durante una escena caminable. Los dos lo son durante la actualización reducida de un menú
pintado sobre el mapa que no pone `in_menu` (el menú de pausa de Insurgence); `keys_locked?`, no mientras haya un
mensaje en él.

## Combate

`core/battle/battle.rb`, `core/battle/move_info.rb` — módulos `Battle` y `MoveInfo`.

| Firma | Devuelve | Cuándo usarlo |
|---|---|---|
| `Battle.set_battle(b)` | Nada | Capturar la batalla en curso para las teclas de PS y campo |
| `Battle.clear_battle` | Nada | Soltarla; lo hace `map_poll` cada frame |
| `Battle.in_battle?` | `true`/`false` | ¿Hay combate? Lo consulta `Spatial.busy?` |
| `Battle.hp_phrase(hp, tot, as_percent)` | Frase de PS: porcentaje o `"hp/total"` | Centraliza el branch y la guarda de división por cero |
| `Battle.battler_state(b, hide_exact = false)` | Nombre, nivel, PS, estado, marcas de su caja y cambios de característica | Describir un battler completo |
| `Battle.icon_mark(patrón, clave)` | Nada | Nombrar un icono propio de la caja de combate por su nombre de fichero (`/\Adelta\z/i`); lo llama el perfil o el plugin que lo pinta, nunca core |
| `Battle.shown_marks(b)` | Array de palabras | Las marcas que la caja de ese battler pintó en su último refresco |
| `Battle.announce_hp(foe)` | Nada | Hablar los PS de TODO un bando; `foe` true lee al rival en porcentaje |
| `Battle.foe_info` | Línea con todos los rivales, o `nil` | Nombre, nivel y tipo de cada oponente |
| `Battle.announce_field` | Nada | Hablar clima, terreno y condiciones de campo |
| `Battle.types_of(pk)` | Array de nombres de tipo; `[]` si nada resuelve | Tipos vía el proveedor de datos |
| `MoveInfo.line(name, type_name, power, accuracy, opts = {})` | `"nombre. tipo. poder. precisión[. pp][. descripción]"` | El único ensamblador de la línea de un movimiento |
| `MoveInfo.by_id(id)` | La línea, o `nil` | Resolver por GameData (v21 y v22) |
| `MoveInfo.by_id_via_data(id)` | La línea, o `nil` | Resolver por el adaptador `Data`, así que también sirve en gen-6 |
| `MoveInfo.power_phrase(pw)` | `"sin daño"` si ≤ 0, `"variable"` si 1, si no el número | Poder hablado |
| `MoveInfo.accuracy_phrase(acc)` | `"no falla"` si ≤ 0, si no el número | Precisión hablada |
| `MoveInfo.painted(m, name, type_name)` | `[nombre, tipo]` tal cual | El nombre y el tipo que pintan la página de movimientos del resumen y los botones de combate; lo sobrescribe el perfil de un juego que pinta otros (el movimiento personalizado de Insurgence) |

En `MoveInfo.line`, un `power` o `accuracy` a `nil` significa SIN RESOLVER y omite su frase; solo un 0 real
dice "sin daño" o "no falla". Las opciones son `:pp` y `:total_pp` (hacen falta las dos para hablar los PP)
y `:desc`, que se añade si no está en blanco.

## Resumen del Pokémon

`core/party/summary.rb` — módulo `Summary`: las piezas que comparten los resúmenes. Las páginas propias de un
juego y sus ganchos viven en su perfil y montan su texto con estas.

| Firma | Devuelve | Cuándo usarlo |
|---|---|---|
| `Summary::STAT_ROWS` | `[[índice, clave], ...]` | El orden de serie de las características: PS, Ataque, Defensa, Ataque Especial, Defensa Especial y Velocidad, la última aunque su índice sea el 3 |
| `Summary.eviv_rows(pk, rows = STAT_ROWS)` | Array de filas habladas | Los EV y los IV de una página, uno por característica, en el orden de serie o en el que numere el motor |

## Info contextual

`core/field/contextual.rb` — módulo `Info`. Lo que lee la tecla de información.

| Firma | Devuelve | Cuándo usarlo |
|---|---|---|
| `Info.set_info(kind, data, row = nil)` | Nada | Publicar lo que leerá la tecla de info y, en `row`, la fila enfocada entera, como la dice Completa, para Ctrl+T |
| `Info.add_to_row(text, slot)` | Nada | Añadir a la fila de Ctrl+T una ventana que va con ella (lo que hay en la mochila en la tienda), hasta el siguiente `set_info`; una por ranura |
| `Info.row_text` | La fila y sus ventanas, o `nil` | Lo que dice Ctrl+T; sin fila, Ctrl+T dice lo mismo que la T |
| `Info.info_text` | El texto del contexto actual, o `nil` | Lo llama la tecla; un lector no suele necesitarlo |
| `Info.clear_combat` | Nada | Olvidar el contexto de combate al acabar el combate (`Game_Temp#in_battle=` y `Battle.battle_ended`) |
| `Info.clear_text` | Nada | Soltar una línea `:text` aparcada al cerrar la pantalla que la publicó |
| `Info.move_info(m)` | La línea del movimiento, o `nil` | Describir un objeto movimiento |
| `Info.move_by_id_info(pk, moveid)` | La línea, o `nil` | Resolver el movimiento en un Pokémon y publicarlo |
| `Info.move_info_by_id(moveid)` | La línea, o `nil` | Describir por id suelto (pantalla de olvidar) |
| `Info.item_info(itemid)` | Nombre, descripción y, en una MT, el movimiento que enseña | |
| `Info.pokemon_info(pk)` | Nombre, nivel, PS, marcas (variocolor como lo dice `Party.shiny_word`, Pokérus, reparte experiencia), signo, objeto y estado | Vistazo rápido |
| `Info.summary_text(pk)` | Ficha completa: especie, tipos, naturaleza, habilidad, objeto y seis stats | |
| `Info.trainer_info` | Nombre, dinero, medallas, pokédex y tiempo de juego | Se despacha por qué global expone el motor |
| `Info.note_item_desc(id, desc)` | Nada aprovechable | Que la tecla de info diga la descripción EXACTA que muestra la pantalla |

| `kind` de `set_info` | Qué lee |
|---|---|
| `:move` | El objeto movimiento seleccionado |
| `:item` | El id del objeto seleccionado |
| `:pokemon` | El Pokémon actual |
| `:trainer` | El entrenador (ignora `data`) |
| `:battle_foe` | El enemigo actual (ignora `data`, llama a `Battle.foe_info`) |
| `:text` | Una línea ya montada, que un perfil publica por su cuenta |

`clear_combat` borra solo `:move`, `:battle_foe` y `:text`; el contexto de campo (`:pokemon`, `:item`,
`:trainer`) se conserva.

En el mapa, la T dice el entrenador: `Locator.refresh_info` lo publica en cada fotograma, salvo con un menú con
ayuda abierto (`CommandHelp.current`), cuya ayuda es lo que debe decir. Los menús de pausa cuyo bucle no actualiza
el mapa (el Neo, los de botones, la parrilla de Royal) lo publican ellos al mover el cursor y al volver de un
submenú, como el DP en cada `update`.

## Perfiles de juego

`core/foundation/game.rb` — módulo `Game` y su `Definition`. Cada método es una capa fina sobre una llamada
cruda. Ver [05-extender](05-extender.md).

| Firma | Devuelve | Cuándo usarlo |
|---|---|---|
| `Game.define(name = nil, &blk)` | La `Definition` | Abrir un bloque de perfil; aditivo y repetible |
| `Game.profiles` | Array de identificadores definidos | Diagnóstico |
| `after(cname, meth, opts = {}, &blk)` | Nada | `Hooks.after_hook` |
| `before(cname, meth, opts = {}, &blk)` | Nada | `Hooks.before_hook` |
| `around(cname, meth, opts = {}, &body)` | Nada | `Hooks.around_hook` |
| `read_on_open(cname, meth = :pbStartScene, opts = {}, &blk)` | Nada | `Hooks.read_on_open` |
| `override(target, meth, &body)` | Nada | `Hooks.override` con `:tag => "game_<perfil>"` |
| `kernel(fname, timing = :before, &body)` | Nada | `Hooks.wrap_kernel` para una función suelta |
| `screen_reader(cname, &blk)` | Nada | Lector de la opción enfocada de una ventana de comandos |
| `info_window(cname, key, slot, opts = {})` | Si la clase aceptó el enganche | La ventana fija de una pantalla de este juego (ver `InfoWindow`) |
| `hall_of_fame(*cnames)` | Nada | Los clones que este juego hace del Salón de la Fama: cada clase nombrada recibe los lectores de la familia (panel, pancarta y recuadro del entrenador) |
| `poll_each_frame(&blk)` | Nada | `Keys.on_frame`, para menús con bucle propio |
| `trainer_part(key, &reader)` | La clave | Define o sustituye una pieza de la línea del entrenador (cintas en vez de medallas, monedas en vez de dinero). Cede el objeto jugador; una clave nueva se añade al final |
| `trainer_order(keys)` | El orden asignado | Orden de las piezas de la línea del entrenador; una pieza omitida no se dice |
| `diag_section(name, group = :scene, &body)` | Nada | `Keys.register_diag_section` |
| `config(key, value)` | El valor asignado | Sobrescribir un ajuste de `Config` |
| `button_labels(map)` | El hash resultante | Fusionar etiquetas de botón propias del juego |
| `key_hints(map)` | El hash resultante | Qué letras pintadas en sus pistas son botones (`KeyHints`) |
| `remap_extra(sym, default_vk, label)` | Nada | Acción extra remapeable |
| `puzzle(map_id, opts)` | Nada | `Puzzles.register` |
| `hazard(pattern, label)` | Nada | `Locator.register_hazard` |
| `teleporter(pattern)` | Nada | `Locator.register_teleporter` |
| `transfer_script(pattern)` | Nada | Una llamada propia del juego que traslada al jugador; el patrón captura el mapa |
| `field_move_item(move, item)` | Nada | Un objeto que hace de MO (`FieldMoves.register_item`) |
| `script_condition(pattern, &reader)` | Nada | `EventPages::ScriptCondition.register_atom` |
| `terrain_rule(&rule)` | Nada | `Pathfinder.arrival_rule` |
| `held_key_ground(&rule)` | Nada | `Pathfinder.held_key_rule` |
| `terrain_exit(&rule)` | Nada | `Pathfinder.leave_rule` |
| `assisted_step(&blk)` | Nada | `Pathfinder.assist_source` |
| `picture_texts(map)` | El hash resultante | Nombre de imagen => texto hablado |
| `on_picture(&blk)` | Nada | Reaccionar al mostrarse una imagen. Cede `(picture_name, args)` |

`override` desde el perfil no acepta `opts`: fija el `:tag` con el nombre del perfil, que es lo que el
diagnóstico lista.

## Configuración

`core/foundation/config.rb`, `core/foundation/settings.rb` — módulos `Config` y `Settings`. Ver
[05-extender](05-extender.md).

| Firma | Devuelve | Cuándo usarlo |
|---|---|---|
| `Config.<clave>` | El valor actual | Toda fila de `SCHEMA` y toda entrada de `OTHER` tienen accesor |
| `Config.<clave> = v` | El valor asignado | Escribir desde un perfil o desde el menú |
| `Config.schema_group(group)` | Array de filas `[clave, defecto, tipo, grupo, etiqueta, ayuda]` | Construir una página del menú |
| `Config.schema_row(key)` | La fila, o `nil` | Consultar tipo o defecto de un ajuste |
| `Config.keys_of_kind(kind)` | Array de claves de ese tipo | Persistir un tipo entero |
| `Settings.read` | Hash de strings del `settings.ini` | Leer el fichero en crudo |
| `Settings.write` | Nada | Volcar los valores actuales de `Config` al ini |
| `Settings.apply` | Nada | Al arrancar: lee, clampa y aplica; crea el ini si falta |
| `Settings.schema_keys` | Array de claves persistidas, en orden de escritura | Saber qué guarda esta versión |

Los numéricos se clampan con `Config::KIND_BOUNDS` al aplicarse, así que un ini editado a mano nunca sale de
rango. De las teclas del mod solo se escriben las que el jugador movió de verdad, para que un cambio futuro
de defecto llegue a quien no las tocó.

## Etiquetas, marcadores y nombres

`core/foundation/dictionary.rb`, `tags.rb`, `marks.rb`, `map_names.rb` — el módulo `Dictionary` y los tres
diccionarios que lo extienden: `Tags`, `Marks` y `MapNames`. Ficheros de texto compartibles en `data/`.

Los tres tienen una clave distinta pero la misma fontanería, que vive una sola vez en `Dictionary`: cargar el
fichero, fusionar `*_import.txt` añadiendo **solo lo que el almacén no tiene**, copiar a `*_export.txt` y
guardar con su cabecera. Cada diccionario declara `FILE` / `IMPORT` / `EXPORT` y seis ganchos que conocen su
forma: `header`, `parse_line`, `each_stored`, `has_entry?`, `put_entry` y `line_for`.

| Diccionario | Clave | Fichero | Línea |
|---|---|---|---|
| `Tags` | mapa + evento | `tags.txt` | `87:43=Losa del medio<TAB>cat=extras<TAB>hide` |
| `Marks` | mapa + casilla | `marks.txt` | `87:15,17=Losa del medio` |
| `MapNames` | mapa | `map_names.txt` | `87=Bastión, planta baja` |

**Sello de juego.** Las claves son ids de mapa, y un id significa otra cosa en cada juego: un fichero de
etiquetas de Pokémon Z metido en Añil importa sin un solo error y bautiza eventos al azar. Por eso `save`
escribe `# game: <perfil>` en la cabecera (`Game.profile_name`: el primer `Game.define`, o el sello del
instalador en `installed.json`) e `import_status` rechaza un fichero de otro juego, tanto desde el menú como
en la fusión automática al cargar. Un fichero sin sello, anterior a esto, importa como siempre. Un almacén cuyas
entradas valen igual en todos los juegos lo declara con `game_bound?` falso y ni sella ni rechaza: así van los
esquemas de verbosidad (ver [Verbosidad](#verbosidad)).

| Firma (común a los tres) | Devuelve | Cuándo usarlo |
|---|---|---|
| `store` | El hash del almacén | Inspección; carga y fusiona el import en el primer uso |
| `reload!` | Nada | Olvidar lo cargado para releer el fichero (los tests, tras borrarlo) |
| `import_status` | `[:none]`, `[:foreign, juego]` o `[:ready, juego]` | Saber si se puede importar, y si no, por qué |
| `import_now` | Número de entradas nuevas | Fusionar el `*_import.txt`; `0` si falta o es de otro juego. Fusionado, pasa a llamarse `*_import.imported.txt`, para que no se vuelva a fusionar en cada carga y devuelva lo que el jugador borró después |
| `export` | Número de entradas volcadas, o `nil` si no hay ninguna | Volcar a `*_export.txt` para compartirlo |
| `count` | Número de entradas | |

| Firma propia | Devuelve | Cuándo usarlo |
|---|---|---|
| `Tags.get(mid, eid)` | La etiqueta personalizada, o `nil` | Nombre que el jugador dio a un objeto |
| `Tags.set(mid, eid, label)` | Nada | Asignarla y persistir; `""` la borra sin tocar el resto |
| `Tags.category(mid, eid)` | Símbolo de categoría forzada, o `nil` para automático | |
| `Tags.set_category(mid, eid, cat)` | Nada | `nil` vuelve a automático |
| `Tags.hidden?(mid, eid)` | `true`/`false` | ¿El jugador lo ocultó? |
| `Tags.set_hidden(mid, eid, val)` | Nada | Ocultar o mostrar |
| `Tags.delete(mid, eid)` | Nada | Olvidar el registro entero (el «Borrar» del menú) |
| `Tags.each_record(&blk)` / `each_hidden` | Nada | Recorrer todo, o solo lo oculto. Ceden `(map_id, event_id, registro)` |
| `Marks.get(mid, x, y)` | El nombre del marcador, o `nil` | |
| `Marks.set(mid, x, y, name)` | Nada | Nombrar y persistir; en blanco lo elimina |
| `Marks.delete(mid, x, y)` | Nada | |
| `Marks.on_map(mid)` | `[[x, y, nombre], ...]` en orden de lectura | Los objetivos de la categoría `:marks` |
| `Marks.any_on?(mid)` | `true`/`false` | Si el mapa ofrece la categoría |
| `Marks.each_mark(&blk)` | Nada | Recorrer todos. Cede `(map_id, x, y, nombre)` |
| `MapNames.get(mid)` | El nombre personalizado, o `nil` | También cambia cómo se anuncian las salidas a ese mapa |
| `MapNames.set(mid, name)` | Nada | Asignarlo y persistir; vacío restaura el nombre del juego |
| `MapNames.delete(mid)` / `each_name` | Nada | Olvidar uno; recorrer todos, cede `(map_id, nombre)` |

Un registro de `Tags` desaparece solo cuando se queda sin nombre, sin categoría y sin la marca de oculto:
`prune` lo hace por dentro tras cada escritura. `Tags.delete` es la otra puerta, deliberada: la pide el
jugador desde el menú, no una escritura vacía.

En el juego: `Ctrl`+`G` crea, edita o borra el marcador de la casilla del jugador (un solo cuadro de texto;
en blanco, lo borra); `Shift`+`K` y `Ctrl`+`K` actúan sobre un marcador seleccionado igual que sobre un objeto;
y el menú del mod, en «Personalización», importa y exporta cada diccionario y los esquemas de verbosidad (o todo
de golpe) y lista cada diccionario para renombrar, borrar o volver a mostrar.

## Menú del mod

`core/menus/config_menu.rb` (el marco: el bucle modal, la pila de pantallas, las filas y cómo se dicen),
`config_rows.rb` (los ajustes, el glosario de sonidos y depuración), `config_dicts.rb` (Personalización: las listas
editables, importar y exportar), `config_verbosity.rb` (la verbosidad y sus esquemas) y `config_remap.rb`
(reasignar teclas): un solo módulo `ConfigMenu` repartido por responsabilidad, como el buscador de rutas.

Cada pantalla es una lista de filas `{:kind => ..., ...}`: `:setting` (una fila del SCHEMA), `:enter` (abre otra
pantalla), `:action`, `:entry` y `:entry_action` (las listas de los diccionarios), `:scheme`, `:scheme_action` y
`:reading` (la verbosidad), `:sound`, `:note`, `:remap` y `:back`. Una fila puede llevar `:help`, la clave que dice
la tecla de información. La lista se memoriza por estado y por los contadores de escritura de los almacenes, así
que un cambio hecho con el menú abierto la rehace sin avisar a nadie.

En el editor de un esquema cada lectura es una fila: izquierda y derecha mueven su nivel y el esquema se guarda en el
acto. Borrar pide una segunda pulsación seguida en la misma fila; moverse olvida la pregunta.

## Eventos y cachés

`core/foundation/events.rb`, `core/foundation/caches.rb` — módulos `Events` y `Caches`.

| Firma | Devuelve | Cuándo usarlo |
|---|---|---|
| `Events.on(name, &block)` | El array de suscriptores | Suscribirse; corren en orden de suscripción, cada uno guardado |
| `Events.emit(name, *args)` | Nada | Emitir a todos los suscriptores |
| `Caches.register(name, &block)` | El bloque | Registrar un reset de estado por run, idempotente por nombre |
| `Caches.reset_all` | Nada | Correrlos todos; se dispara con `:map_changed` |
| `Caches.names` | Array de nombres registrados | Diagnóstico |

| Evento del core | Argumentos |
|---|---|
| `:map_changed` | `map_id`. También al cargar partida, aunque sea el mismo mapa |
| `:tags_changed` | Ninguno. El jugador editó etiquetas de objetos |

`:map_changed` lo emite el detector de cambio de mapa del localizador, que compara la IDENTIDAD de
`$game_map` además de su id: cargar una partida reconstruye el objeto, así que la carga también dispara el
reset de cachés.

## Teclas

`core/input/input.rb` — módulo `Keys` (se llama así para no chocar con el `::Input` de RGSS).

| Firma | Devuelve | Cuándo usarlo |
|---|---|---|
| `Keys.enabled` | `true`/`false` | ¿El mod está activo? Ctrl+Alt+F8 lo alterna |
| `Keys.key(name)` | `true` solo en el frame del flanco | Tecla configurada por nombre de `Config.keys` |
| `Keys.raw_down?(vk)` | `true`/`false` | Estado físico de una tecla virtual, independiente del foco |
| `Keys.shift_down?` | `true`/`false` | Modificador shift, configurable |
| `Keys.ctrl_down?` | `true`/`false` | Modificador control, configurable |
| `Keys.focused?` | `true`/`false`, con `true` como valor seguro | ¿La ventana del juego está en primer plano? |
| `Keys.global_poll` | Nada | Las teclas contextuales; lo llama el hook de `Input#update` |
| `Keys.on_frame(&blk)` | El array de pollers | Un bloque por frame en toda escena |
| `Keys.run_frame_pollers` | Nada | Correrlos todos, cada uno guardado |
| `Keys.typing!` | `4` | Mientras hay un campo de texto activo: suprime TODAS las teclas del mod |
| `Keys.menu_lock!` | `4` | Mientras hay un menú con input crudo: suprime las de movimiento, deja las de solo lectura |
| `Keys.hotkey?(slot, fkey)` | `true` solo en el frame del flanco | Gesto Ctrl+Alt+`<tecla de función>` |

`typing!` y `menu_lock!` decaen en cuatro frames, así que hay que llamarlos cada frame mientras dure la
situación. La diferencia es cuánto silencian: `typing!` todo, `menu_lock!` solo lo que compite con el juego.

`core/input/key_hints.rb` — módulo `KeyHints`: las pistas de tecla que pintan los juegos ("[A] Curar", "D: Buscar",
"Pulsa C para acceder") dichas con la tecla que el jugador usa hoy. Con un botón reasignado en el remapeo del mod
(que silencia la tecla del motor), su letra pasa a ser la tecla asignada; si no, donde mkxp-z atiende la entrada del
juego, la tecla en la que su menú F1 dejó el botón (`NativeKeys`); sin nada de eso el texto no cambia. Solo actúa
sobre las letras que el perfil declara botones (`key_hints` en el DSL), así que una casilla "[X]" o un punto
cardinal "[S]" nunca se toman por teclas.

| Firma | Devuelve | Cuándo usarlo |
|---|---|---|
| `KeyHints.localize(text, letters = nil, sentences = false)` | El texto con la letra de cada botón movido cambiada | En los lectores que leen pistas: corchetes, "X: acción" y, con `sentences`, "pulsa X" |
| `KeyHints.key(sym, painted)` | La tecla asignada con el mod, si no la de F1, si no `painted` | Texto propio del mod que nombra una tecla (`%{key}`) |
| `KeyHints.bound_name(sym)` | El nombre de la tecla asignada, o `nil` | Saber si un botón está reasignado |
| `KeyHints.table` | La tabla de letras del perfil | La que usa `localize` por defecto; un perfil la sobrescribe si sus pistas siguen su propio menú de teclas |
| `KeyHints::RGSS_LETTERS` | Las letras por defecto de RPG Maker XP | La tabla de un juego que las conserva |
| `KeyHints::HINT` | La forma de una pista pintada | «[C]: …» delante, o un verbo que pide una tecla («Pulsa…», «Press…»), en los idiomas de los juegos |
| `KeyHints.gate(lines)` | Las líneas sin sus pistas mientras la verbosidad las calla | Una pista con una cifra conserva la cifra («Vial (2/3)»); una que se va se lleva la etiqueta de la que cuelga («LISTA DE TARJETAS:») |
| `KeyHints.gate_sentences(text)` | El texto sin sus frases de pista | Una frase acaba en punto ante espacio o final, así que una cifra («6.9 kg») queda entera; un texto sin pista queda como está |

Lectores que ya la aplican: el panel de pausa, las pistas del resumen, la tarjeta de entrenador, la línea de cajas
del equipo v21, la ayuda de opciones (dos eras), logros, tarjetas de consejo, el reparto de EV y los paneles
modales.

Royal pinta la tecla que su menú F1 da a cada botón (`KeybindingReader`), así que su perfil
(`games/royal/key_hints.rb`) sobrescribe `KeyHints.table` con esos mismos nombres: una letra que F1 pasó a otro
botón se lee como la de ese botón.

`core/input/native_keys.rb` — módulo `NativeKeys`: lo que el menú F1 de mkxp-z guardó en `keybindings.mkxp1`, en
`System.data_directory`. Tres palabras de cabecera (formato, versión de RGSS, cuenta) y cuatro por atadura (tipo de
fuente, scancode de SDL, sin uso, botón); solo cuentan las de teclado de los ocho botones estándar. Se relee cuando
cambia el fichero. Solo en los juegos cuya entrada atiende mkxp-z: los que leen el teclado en Ruby (Africanus,
Armonía, Awakening, Ópalo, Realidea, Reminiscencia) definen `Input.getstate` y F1 no llega a su juego.

| Firma | Devuelve | Cuándo usarlo |
|---|---|---|
| `NativeKeys.name(sym, painted)` | El nombre de la tecla en la que F1 dejó el botón, o `nil` si la pintada sigue valiendo | Lo usa `KeyHints.key`: una letra primero, luego cualquier tecla que no sea modificadora |
| `NativeKeys.active?` | Si hay ataduras de F1 que seguir | El atajo de `localize` sin rebinds |
| `NativeKeys.parse(data)` | `{acción => [teclas virtuales]}` | Leer un fichero (specs) |

Las teclas del propio mod están en la misma pantalla del remapeo, tras los botones del juego. Una ayuda que las nombra lleva
`%{key_<acción>}` (`%{key_field}`, `%{key_prev}`…) y `ConfigMenu.key_vars` la rellena con la tecla configurada. Una
tecla del mod puede venir sin asignar (`nil` en `KEY_DEFAULTS`, como la de rotar la verbosidad): nunca se pulsa, y
flecha izquierda en el remapeo la devuelve a ese estado. Una tecla de serie que ya usa una asignación guardada (una tecla
nueva en esta versión que el jugador había dado a otra cosa) se carga sin asignar, para que la asignación guardada siga
valiendo (`Settings.drop_taken_defaults`).

## Rutas de disco

`core/foundation/paths.rb` — módulo `Paths`. Constantes, no métodos.

| Constante | Qué es |
|---|---|
| `Paths::ROOT` | `accessibility` |
| `Paths::CORE` | `accessibility/core` |
| `Paths::GAME` | `accessibility/game`, el perfil del juego |
| `Paths::SOUNDS` | `accessibility/sounds` |
| `Paths::LIB` | `accessibility/lib`, las dll por arquitectura |
| `Paths::LANG` | `accessibility/lang`, las traducciones |
| `Paths::DATA` | La primera ubicación ESCRIBIBLE: la carpeta del juego o el AppData de mkxp-z |

`DATA` se elige una sola vez al cargar, probando a escribir: mkxp-z lee por su sistema de ficheros virtual
pero escribe en el directorio de trabajo del sistema operativo, que en la máquina de un tester puede ser de
solo lectura.

### Ventanas de información

`core/menus/info_window.rb` — módulo `InfoWindow`. La ventana fija que una pantalla escribe con `text=` y
repinta según se mueve el cursor: dónde vive un contacto, cuántos hay registrados, cuántas especies lleva
vistas la Pokédex, qué hace la opción enfocada. Los oyentes globales sobre `Window_AdvancedTextPokemon`
están acotados a propósito, así que estas ventanas se declaran UNA A UNA en vez de ensanchar el oyente.

| Llamada | Devuelve | Para qué |
|---|---|---|
| `InfoWindow.watch(cname, key, slot, opts = {})` | Si la clase aceptó el enganche | Declara la ventana `key` de la escena `cname` con su ranura de dedup. `:interrupt` para una leyenda que responde a una tecla, en vez de encolarse |
| `InfoWindow.watches` | Array de `[clase, clave, ranura, interrumpe]` | Las ventanas declaradas |
| `InfoWindow.silent` | Array de `"Clase.clave"` | Las ventanas declaradas que la escena no tiene: un lector que no puede hablar nunca. El diag las imprime |
