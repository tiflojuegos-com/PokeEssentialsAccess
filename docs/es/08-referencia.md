# Referencia

Firmas verificadas contra el código. El prefijo `PokeAccess::` se omite en las tablas y se indica en la línea
de cada grupo. Donde un método toma bloque, la columna de uso dice qué cede.

## Voz y braille

`core/speech/speech.rb`, `core/speech/text.rb`, `core/dialogue/dialogue.rb` — módulo `PokeAccess`. Ver
[04-lectores](04-lectores.md).

| Firma | Devuelve | Cuándo usarlo |
|---|---|---|
| `speak(text, interrupt = true)` | Nada aprovechable | Hablar una línea ya limpia (una clave i18n resuelta). `interrupt` false encola |
| `speak_clean(text, interrupt = true)` | Nada aprovechable | Hablar texto que viene del JUEGO: aplica `clean` antes |
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
| `on_speak = cb` / `on_speak` | El observador, o `nil` | Observar TODO lo hablado; recibe `(text, interrupt)` |
| `last_spoken` | Última línea no vacía hablada, o `nil` | Diagnóstico hablado |
| `say_dialogue(message)` | Nada | Limpiar, recordar y hablar ENCOLADA una línea de diálogo |
| `note_dialogue(text)` | Nada | Recordar una línea sin hablarla |
| `last_dialogue` | Última línea de diálogo, o `nil` | La repite la tecla de info con shift |

`speaking?` devuelve `nil` cuando el backend no sabe responder. Trata `nil` como desconocido, NUNCA como
silencio. `on_speak` es un observador ÚNICO: asignar uno nuevo pisa al anterior. Un observador que lanza se
ignora. `say_dialogue` no repite una línea idéntica dentro de 0,5 s.

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
| `Hooks.wrap_global(name, tag, timing = :after, &body)` | Nada | Método top-level de `Object` (`pbDisplayMail`...). Cede `(args, x)` |
| `Hooks.wrap_kernel(name, tag, timing = :before, &body)` | Nada | Igual, probando primero el singleton de `Kernel`. Cede `(args, x)` |
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
| `I18n.t(key, vars = nil)` | El string traducido | Todo texto hablado; `vars` es un hash `%{nombre} => valor` |
| `I18n.lang` | Símbolo del idioma activo, o el de referencia (`:en`) | Leer el idioma sin tocar `Config` |
| `I18n.available_languages` | Array de símbolos con fichero en `lang/` | Menú de idioma |
| `I18n.language_name(code)` | La entrada `__language__`, o el código | Nombre humano en el menú |
| `I18n.next_language(code)` | El siguiente del ciclo | Toggle de idioma |
| `I18n.interpolate(s, vars)` | El string con `%{nombre}` sustituido | Interpolar aparte de `t`; una var ausente da `""` |
| `I18n.parity_issues` | Array de `"code:clave: razón"`; `[]` si todo cuadra | El check de boot y la suite |
| `I18n.table(code)` | Hash clave => valor, cacheado | Inspeccionar una tabla entera |
| `I18n.duplicate_keys(code)` | Array de claves repetidas en un fichero | Diagnóstico de un `lang/*.txt` |

`t` no lanza nunca: una clave que falta cae al idioma de referencia y luego al nombre de la clave, así que se
oye la clave en crudo. `parity_issues` cubre tres faltas: clave presente en un idioma y ausente en otro,
clave duplicada dentro de un fichero, y placeholders `%{}` que difieren entre idiomas.

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
| `Data.register(priority, provider)` | Nada | Registrar un proveedor: 20 GameData, 10 gen-6, 0 fallback |
| `Data.active` | El proveedor activo, o `nil` | Diagnóstico |
| `Data.active_priority` | La prioridad del activo, o `nil` | `0` significa que solo quedó el fallback |
| `Data.active_entry` | `[prioridad, proveedor]`, o `nil` | Diagnóstico |
| `Data.resolve(method, arg)` | Lo que devuelva el proveedor, o `nil` | El embudo: añadir un resolutor nuevo |
| `Data.errors` | Array de strings; `[]` en una run limpia | Excepciones del proveedor, una por `(método, clase)` |

`pokemon_types` es el único que nunca devuelve `nil`. El resto responde `nil` tanto si no hay proveedor como
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
| `PaintCapture.speak_around(tag, interrupt) { nxt.call }` | El valor del bloque | La forma común: arma, corre el pintado del juego y habla lo que cayó |
| `PaintCapture.flush_pending(tag, interrupt)` | — | Desde un poll por frame, para una etiqueta armada antes de un bucle bloqueante |
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

`core/nav/pathfinder.rb`, `core/nav/terrain.rb` — módulos `Pathfinder` y `Terrain`. Ver
[06-navegacion](06-navegacion.md).

| Firma | Devuelve | Cuándo usarlo |
|---|---|---|
| `Pathfinder.find_path(tx, ty)` | Array de códigos de dirección RPG, o `nil` si no hay ruta | Ruta a una casilla contigua al destino; el origen es `$game_player` |
| `Pathfinder.path_to_text(path)` | `"3 arriba, 2 izquierda"` | Hablar una ruta; `nil` da "sin ruta" y `[]` da "al lado" |
| `Pathfinder.reachable_set` | Hash `pkey => true`, cacheado por casilla del jugador | Filtro de inalcanzables y línea de visión del sonar |
| `Pathfinder.reachable_tiles` | El mismo hash, sin caché | Recalcular a la fuerza |
| `Pathfinder.pkey(x, y)` | `x * 100000 + y` | Empaquetar o desempaquetar las claves de `reachable_set` |
| `Pathfinder.reach` | Integer de tiles (`Config.route_reach`) | Distancia máxima que la búsqueda considera |
| `Pathfinder.invalidate_cache(force = false)` | Nada | Tras un evento que cambió la pasabilidad |
| `Pathfinder.passable_at?(cx, cy, d)` | `true`/`false` | ¿Se puede dar un paso en esa dirección? |
| `Pathfinder.ledge_jump(cx, cy, dx, dy, d)` | `[x, y]` de aterrizaje, o `nil` | ¿Hay salto de ledge por ahí? |
| `Pathfinder.surf_launch(tx, ty)` | Ruta a la orilla, o `nil` | El destino está al otro lado del agua |
| `Pathfinder.blocked_target?(tx, ty)` | `true` si el destino es claramente inalcanzable | Rechazo rápido antes de un A* completo |
| `Pathfinder.path_algorithm` | Símbolo de `ALGORITHMS`; `:astar` por defecto | Leer el algoritmo configurado |
| `Terrain.raw(x, y, count_bridge = false)` | Integer (gen-6) u objeto `GameData::TerrainTag`, o `nil` | El valor crudo del motor |
| `Terrain.number(t)` | El `id_number` de un valor crudo, o `nil` | Normalizar las dos formas |
| `Terrain.kind(x, y, count_bridge = false)` | Símbolo estable (`:ice`, `:bridge`...), o `nil` | Clasificar una casilla |
| `Terrain.label(x, y)` | Clave i18n de superficie (`:surf_water`...), o `nil` | Hablar la superficie pisada |
| `Terrain.surfable?(t)` | `true`/`false` | Predicado sobre un VALOR de terreno, no coordenadas |
| `Terrain.ledge?(t)` | `true`/`false` | Idem |
| `Terrain.ice?(t)` | `true`/`false` | Idem |
| `Terrain.bridge?(t)` | `true`/`false` | Idem |
| `Terrain.grass?(t)` | `true`/`false` | Idem (hierba normal, alta o de hollín) |
| `Terrain.surfable_at?(x, y)` | `true`/`false` | Variante por coordenada |
| `Terrain.ledge_at?(x, y)` | `true`/`false` | Variante por coordenada |
| `Terrain.ice_at?(x, y)` | `true`/`false` | Variante por coordenada |

`find_path` devuelve DIRECCIONES, no coordenadas: los códigos RPG 8 arriba, 2 abajo, 4 izquierda, 6 derecha,
uno por paso. `path_to_text` consume exactamente eso. Solo existen tres variantes `*_at?`: `surfable_at?`,
`ledge_at?` e `ice_at?`; para `grass?` y `bridge?` hay que pasar por `raw(x, y)`.

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
| `Audio3D.footstep(kind, vol)` | `true` si atendió | Paso, centrado en el jugador |
| `Audio3D.silence_all` | Nada | Callar todos los canales |
| `Audio3D.silence_emitters` | Nada | Callar emisores y bucles dejando pasos y choques (modo `:basic`) |
| `Audio3D.reset_map_state` | Nada | Soltar el escaneo del mapa anterior |
| `Audio3D.nav_full?` | `true`/`false` | ¿Modo completo (todos los emisores)? |
| `Audio3D.nav_off?` | `true`/`false` | ¿Apagado del todo? Entonces el motor ni arranca |
| `Audio3D.gate_report` | `"n/total playing by=..."` y limpia la ventana | Por qué un tick sonó o calló |
| `Spatial.cue(name, volume, pitch = 100)` | Nada | Reproducir un fichero de `sounds/`; volumen 0 o `nil` no suena |
| `Spatial.earcon(name, volume, pitch = nil)` | Nada | Earcon con nombre de `EARCONS`; el pitch de la tabla es el defecto |
| `Spatial.busy?` | `true`/`false` | El jugador NO tiene control libre: el paisaje sonoro calla |
| `Spatial.busy_reason` | Símbolo (`:message`, `:in_menu`, `:battle`...) o `nil` | Nombrar la causa en el diagnóstico |
| `Spatial.keys_locked?` | `true`/`false` | Otra pantalla posee de verdad las flechas |
| `Spatial.tick` | Nada | Un frame de pasos, choques, radar y superficies |

`available?` devuelve el último objeto `Win32API` de la cadena, no un booleano: úsalo solo como condición.
`busy?` es cierto con un mensaje o un intérprete corriendo; `keys_locked?` no, para que las teclas del
localizador sigan usables durante una escena caminable.

## Combate

`core/battle/battle.rb`, `core/battle/move_info.rb` — módulos `Battle` y `MoveInfo`.

| Firma | Devuelve | Cuándo usarlo |
|---|---|---|
| `Battle.set_battle(b)` | Nada | Capturar la batalla en curso para las teclas de PS y campo |
| `Battle.clear_battle` | Nada | Soltarla; lo hace `map_poll` cada frame |
| `Battle.in_battle?` | `true`/`false` | ¿Hay combate? Lo consulta `Spatial.busy?` |
| `Battle.battler_at(idx)` | El battler, o `nil` | Nombrar un hueco cuyo texto de menú llegó vacío |
| `Battle.hp_phrase(hp, tot, as_percent)` | Frase de PS: porcentaje o `"hp/total"` | Centraliza el branch y la guarda de división por cero |
| `Battle.battler_state(b, hide_exact = false)` | Nombre, nivel, PS, estado y cambios de característica | Describir un battler completo |
| `Battle.announce_hp(foe)` | Nada | Hablar los PS de TODO un bando; `foe` true lee al rival en porcentaje |
| `Battle.foe_info` | Línea con todos los rivales, o `nil` | Nombre, nivel y tipo de cada oponente |
| `Battle.announce_field` | Nada | Hablar clima, terreno y condiciones de campo |
| `Battle.types_of(pk)` | Array de nombres de tipo; `[]` si nada resuelve | Tipos vía el proveedor de datos |
| `MoveInfo.line(name, type_name, power, accuracy, opts = {})` | `"nombre. tipo. poder. precisión[. pp][. descripción]"` | El único ensamblador de la línea de un movimiento |
| `MoveInfo.by_id(id)` | La línea, o `nil` | Resolver por GameData (v21 y v22) |
| `MoveInfo.by_id_via_data(id)` | La línea, o `nil` | Resolver por el adaptador `Data`, así que también sirve en gen-6 |
| `MoveInfo.power_phrase(pw)` | `"sin daño"` si ≤ 0, `"variable"` si 1, si no el número | Poder hablado |
| `MoveInfo.accuracy_phrase(acc)` | `"no falla"` si ≤ 0, si no el número | Precisión hablada |

En `MoveInfo.line`, un `power` o `accuracy` a `nil` significa SIN RESOLVER y omite su frase; solo un 0 real
dice "sin daño" o "no falla". Las opciones son `:pp` y `:total_pp` (hacen falta las dos para hablar los PP)
y `:desc`, que se añade si no está en blanco.

## Info contextual

`core/field/contextual.rb` — módulo `Info`. Lo que lee la tecla de información.

| Firma | Devuelve | Cuándo usarlo |
|---|---|---|
| `Info.set_info(kind, data)` | Nada | Publicar el contexto que leerá la tecla de info |
| `Info.info_text` | El texto del contexto actual, o `nil` | Lo llama la tecla; un lector no suele necesitarlo |
| `Info.clear_combat` | Nada | Olvidar el contexto de combate al salir del mapa de batalla |
| `Info.move_info(m)` | La línea del movimiento, o `nil` | Describir un objeto movimiento |
| `Info.move_by_id_info(pk, moveid)` | La línea, o `nil` | Resolver el movimiento en un Pokémon y publicarlo |
| `Info.move_info_by_id(moveid)` | La línea, o `nil` | Describir por id suelto (pantalla de olvidar) |
| `Info.item_info(itemid)` | Nombre, descripción y, en una MT, el movimiento que enseña | |
| `Info.pokemon_info(pk)` | Nombre, nivel, PS, género, objeto y estado | Vistazo rápido |
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
| `poll_each_frame(&blk)` | Nada | `Keys.on_frame`, para menús con bucle propio |
| `diag_section(name, group = :scene, &body)` | Nada | `Keys.register_diag_section` |
| `config(key, value)` | El valor asignado | Sobrescribir un ajuste de `Config` |
| `button_labels(map)` | El hash resultante | Fusionar etiquetas de botón propias del juego |
| `remap_extra(sym, default_vk, label)` | Nada | Acción extra remapeable |
| `puzzle(map_id, opts)` | Nada | `Puzzles.register` |
| `hazard(pattern, label)` | Nada | `Locator.register_hazard` |
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

## Etiquetas y nombres

`core/foundation/tags.rb`, `core/foundation/map_names.rb` — módulos `Tags` y `MapNames`. Ficheros de texto
compartibles.

| Firma | Devuelve | Cuándo usarlo |
|---|---|---|
| `Tags.get(mid, eid)` | La etiqueta personalizada, o `nil` | Nombre que el jugador dio a un objeto |
| `Tags.set(mid, eid, label)` | Nada | Asignarla y persistir; `""` la borra sin tocar el resto |
| `Tags.category(mid, eid)` | Símbolo de categoría forzada, o `nil` para automático | |
| `Tags.set_category(mid, eid, cat)` | Nada | `nil` vuelve a automático |
| `Tags.hidden?(mid, eid)` | `true`/`false` | ¿El jugador lo ocultó? |
| `Tags.set_hidden(mid, eid, val)` | Nada | Ocultar o mostrar |
| `Tags.each_hidden(&blk)` | Nada | Recorrer lo oculto. Cede `(map_id, event_id, record)` |
| `Tags.store` | Hash `{map_id => {event_id => registro}}` | Inspección; carga y fusiona el import en el primer uso |
| `Tags.import_now` | Número de registros nuevos | Fusionar `tags_import.txt` |
| `Tags.export` | Número de registros volcados, o `nil` si no hay ninguno | Volcar a `tags_export.txt` para compartirlo |
| `MapNames.get(mid)` | El nombre personalizado, o `nil` | También cambia cómo se anuncian las salidas a ese mapa |
| `MapNames.set(mid, name)` | Nada | Asignarlo y persistir; vacío restaura el nombre del juego |

Un registro de `Tags` desaparece solo cuando se queda sin nombre, sin categoría y sin la marca de oculto:
`prune` lo hace por dentro tras cada escritura. No existe un borrado en bloque, a propósito: quitar la
etiqueta no es lo mismo que olvidar el objeto.

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
