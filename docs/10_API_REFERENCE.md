# API Reference - Referencia Rápida de Métodos

Consulta rápida de los métodos principales de PokeEssentialsAccess.

## PokeEssentialsAccess Global

```ruby
PokeAccess.speak(text, interrupt = true)
# Habla el texto con síntesis de voz (vía SRAL)
# interrupt: true = corta voz anterior, false = encola

PokeAccess.speak_clean(text, interrupt = true)
# Limpia los códigos de control de RPG Maker (\\PN, \\V[n], \\C[n]...) y habla.
# Atajo para voz de texto que viene del juego; una línea ya limpia usa speak directo.

PokeAccess.clean(text)
# Limpia etiquetas gráficas de texto (\\c[1] → "")

PokeAccess.write_marker(msg)
# Escribe marcador de diagnóstico a archivo

PokeAccess.log_once(key, error)
# Registra error una sola vez (evita spam)

PokeAccess.clock
# Segundos de reloj de pared desde que cargó el mod. Única fuente del ritmo de las señales (pings del
# sonar, chime de guía, cooldown de choque, perfilador). NO usa System.uptime ni Graphics.frame_count:
# el mkxp-z de Infinite Fusion devuelve un System.uptime que no son segundos (todo el sonar disparado a
# ritmo de frame) y frame_count sólo mide tiempo mientras el juego mantenga su tasa nominal, además de
# saltar al cargar partida. Los pasos NO pasan por aquí: suenan al cambiar de casilla, así que siguen
# al jugador aunque acelere con el turbo.

PokeAccess.const_at("A::B::C")
# Resuelve una constante anidada por nombre, 1.8.7-safe (o nil). La usan Hooks/Input/Menus/Engine.has?
PokeAccess.const?("UI::BagVisuals")
# true/false si la constante existe (1.8.7-safe)

PokeAccess.ivar(obj, :@index, fallback = nil)
# Lee un ivar de cualquier objeto de forma defensiva; devuelve fallback si no existe o falla
# (los objetos del motor no exponen accessors y el ivar varía por versión). 1.8.7-safe.

PokeAccess.ivar_i(obj, :@index, fallback = 0)
# Igual que ivar pero forzando a Integer (para ivars numéricos)

PokeAccess.sprite(scene, "commandwindow")
# Un sprite del hash @sprites de una escena, o nil si el hash o la clave faltan. 1.8.7-safe.

PokeAccess.last_spoken
# Última línea hablada (para el diag hablado Ctrl+Alt+F10), o nil
```

## PokeAccess::Config

```ruby
PokeAccess::Config.language
PokeAccess::Config.auto_guide
PokeAccess::Config.hide_unreachable
PokeAccess::Config.audio3d_volume
PokeAccess::Config.route_reach
# Lectura de configuración

PokeAccess::Config.language = :es
# Establecer configuración

PokeAccess::Config.schema_group(:pathfinder)
# Obtener opciones de un grupo
```

## PokeAccess::Engine

```ruby
PokeAccess::Engine.gamedata?
# true = usa la API GameData (Essentials v19+), false = Gen-6

PokeAccess::Engine.gen6?
# Opuesto de gamedata?

PokeAccess::Engine.kind
# Retorna :gamedata o :gen6

PokeAccess::Engine.has?(cap)
# Gate por capacidad (el canal recomendado): símbolo registrado (:ui_rework, :gamedata,
# :sky_fork...), nombre de clase "A::B::C" (1.8.7-safe), o "Clase#metodo".
PokeAccess::Engine.has?(:ui_rework)
PokeAccess::Engine.has?("Battle::Scene::MenuBase#setIndexAndMode")
# true en v21 (el rework UI de v22 elimina ese método); lo usa core/battle/v21/battle_v21.rb

PokeAccess::Engine.version
# Retorna Float: 16.0, 19.0, 21.1, 22.0, etc.

PokeAccess::Engine.fork
# Retorna :sky o nil

PokeAccess::Engine.at_least?(v)
# ¿version >= v?

PokeAccess::Engine.between?(lo, hi)
# ¿version entre lo y hi?

PokeAccess::Engine.matches?(opts)
# Evaluar especificación: :min, :max, :only, :fork

PokeAccess::Engine.for_engine(opts = {})
# Ejecutar bloque solo si engine cumple spec
PokeAccess::Engine.for_engine(:only => :gamedata) { ... }

PokeAccess::Engine.player
# Retorna $player (era GameData) o $Trainer (gen-6). O usa World.player (la fachada).

PokeAccess::Engine.pick(map)
# Elegir valor: map = { :gamedata => v1, :gen6 => v2 }
```

## PokeAccess::World

```ruby
PokeAccess::World.map            # $game_map o nil
PokeAccess::World.player_char    # $game_player o nil
PokeAccess::World.player         # objeto entrenador (delega en Engine.player)
PokeAccess::World.bag            # $PokemonBag o player.bag, o nil
PokeAccess::World.pokemon_global # $PokemonGlobal o nil
PokeAccess::World.on_map?        # true en el campo (mapa + jugador presentes)
PokeAccess::World.want(key, val) # devuelve val; si es nil loguea una vez (lector mudo trazable)
```

## PokeAccess::Cursor

```ruby
# Primitiva única de dedup para lecturas de cursor/selección (la UI re-selecciona cada frame).
PokeAccess::Cursor.changed?(holder, slot, key)   # true (y guarda) si la key cambió en ese holder/slot
PokeAccess::Cursor.on_change(holder, slot, key) { ... }  # corre el bloque solo si cambió
PokeAccess::Cursor.announce(holder, slot, key, interrupt = true, first_interrupt = nil) { texto }
# Habla el texto (clean) solo si cambió. interrupt: la primera lectura de un cursor recién
# abierto/reseteado usa first_interrupt (si no es nil) para el patrón "encola la lectura de
# apertura, interrumpe en los movimientos siguientes"; el resto usa interrupt.
PokeAccess::Cursor.pending?(holder, slot)        # true en la PRIMERA lectura de un cursor fresco/reseteado
PokeAccess::Cursor.reset(holder, slot)           # fuerza re-lectura aunque la key no cambie (al reabrir)
# holder = la escena/instancia (estado por instancia), o nil para una tabla global por slot.
```

## PokeAccess::Caches

```ruby
PokeAccess::Caches.register(:name) { ... }  # registra un reset de estado por-run
PokeAccess::Caches.reset_all                # corre todos (se dispara en :map_changed; cargar partida lo cubre vía forget_map)
PokeAccess::Caches.names                    # nombres registrados (diagnóstico)
```

## PokeAccess::Data

```ruby
PokeAccess::Data.species_name(id)           # "Pikachu"
PokeAccess::Data.species_entry(id)          # Dex entry
PokeAccess::Data.move_name(id)              # "Tackle"
PokeAccess::Data.move_type_name(id)         # "Normal"
PokeAccess::Data.move_power(id)             # 40
PokeAccess::Data.move_accuracy(id)          # 100
PokeAccess::Data.move_description(id)       # "Atacar..."
PokeAccess::Data.type_name(id)              # "Fire"
PokeAccess::Data.item_name(id)              # "Potion"
PokeAccess::Data.item_name_plural(id)       # "Potions"
PokeAccess::Data.item_description(id)       # "Recupera 20 HP..."
PokeAccess::Data.item_id(symbol)            # :POTION → 1
PokeAccess::Data.ability_name(id)           # "Static"
PokeAccess::Data.nature_name(id)            # "Timid"
PokeAccess::Data.stat_name(stat)            # "Atk"
PokeAccess::Data.status_name(status)        # "Poison"
PokeAccess::Data.pokemon_types(pokemon)     # [:fire, :flying]

PokeAccess::Data.register(priority, provider)
# Registrar proveedor de datos

PokeAccess::Data.active
# Retorna provider activo

PokeAccess::Data.active_priority
# Retorna prioridad (20 GameData, 10 gen-6, 0 fallback)

PokeAccess::Data.errors
# Array de errores del provider
```

## PokeAccess::Battle

```ruby
PokeAccess::Battle.hp_phrase(hp, tot, as_percent)
# Frase de HP: porcentaje (as_percent true, para un rival o barra de HP oculto) o "hp/total" exacto.
# Centraliza el branch y la guarda de división por cero sobre total que cada lector abría a mano.
```

## PokeAccess::MoveInfo

```ruby
PokeAccess::MoveInfo.by_id_via_data(id)
# Detalle hablado de un movimiento por id, resuelto vía el adaptador Data por-motor (PBMoveData en
# gen-6, GameData en moderno), no GameData directo, para que un lector gen-6 obtenga la línea completa.
# nil si el id no resuelve. Lo usa el relearner gen-6 (ids PBMove enteros).

PokeAccess::MoveInfo.line(name, type_name, power, accuracy, opts = {})
# Ensambla "nombre. tipo. poder. precisión[. pp][. descripción]" desde partes ya resueltas.
# Opciones: :pp y :total_pp (ambas para hablar pp), :desc (se añade si no está en blanco).
```

## PokeAccess::Pathfinder

```ruby
PokeAccess::Pathfinder.find_path(tx, ty)
# Ruta al destino (tx, ty); el origen es $game_player. Array de [x, y], o nil si no hay ruta

PokeAccess::Pathfinder.reachable_set
# Retorna hash de tiles alcanzables desde jugador

PokeAccess::Pathfinder.reach
# Distancia máxima de alcance (configurable)

PokeAccess::Pathfinder.invalidate_cache(force = false)
# Limpiar caché de rutas (cuando mapa cambia)

PokeAccess::Pathfinder.passable_at?(x, y, direction)
# ¿Se puede mover a esa dirección?

PokeAccess::Pathfinder.ledge_jump(cx, cy, dx, dy, d)
# ¿Hay un salto de ledge? Retorna landing tile o nil
```

## PokeAccess::Audio3D

```ruby
PokeAccess::Audio3D.boot
# Inicializar audio 3D (idempotente; carga la dll y los canales una vez)

PokeAccess::Audio3D.device_rate
# Frecuencia del device (44100 o 48000 Hz)

PokeAccess::Audio3D.device_latency
# Latencia del device en ms

PokeAccess::Audio3D.range
# Rango de detección de emitores (tiles)

PokeAccess::Audio3D.occlusion_mode
# :hear, :occlude, o :hide

PokeAccess::Audio3D.wav(name)
# Retorna ruta correcta del archivo .wav
```

## PokeAccess::Hooks

```ruby
PokeAccess::Hooks.before_hook(class_name, method_name) { |obj, args| ... }
# Registrar hook ANTES del método

PokeAccess::Hooks.after_hook(class_name, method_name, opts = {}) { |obj, result, args| ... }
# Registrar hook DESPUÉS del método (recibe su resultado). Por defecto el original corre BAJO la
# guarda de reentrancia. Opción :hook_container => true -> el original corre SIN guarda: úsalo cuando
# el método es un CONTENEDOR (loop modal o abre-escena) que DELEGA el anuncio a métodos hookeados que
# él conduce internamente (p.ej. la fase de comandos de combate que conduce índice=/setIndex).

PokeAccess::Hooks.around_hook(class_name, method_name) { |obj, call_next, args| ... }
# Envuelve el método con control total: llama call_next para ejecutar el resto de la cadena.
# call_next usa los argumentos ORIGINALES; para cambiarlos, MUTA el array args in situ antes de llamar.

PokeAccess::Hooks.frame_hook(class_name, method_name) { |obj, args| ... }
# After-hook para un DRIVER por-frame: un método que el motor llama cada frame y que puede alojar
# sincrónicamente un loop modal anidado entero (caso clave Game_Player#update: pisar hierba lanza el
# combate salvaje DESDE DENTRO). Corre el original SIN guarda (alias de :hook_container) y el body
# después. El body no usa el valor de retorno.

PokeAccess::Hooks.wrap_global(name, tag, timing = :after) { |args, x| ... }
# Envuelve un método top-level (de Object) que los hooks de clase no alcanzan, p.ej. pbDisplayMail.
# timing :before -> corre antes, x=nil ; :after -> corre después, x=resultado. No-op si indefinido
# o ya envuelto. 1.8.7-safe.

PokeAccess::Hooks.wrap_kernel(fn_name, tag, timing = :before) { |args, x| ... }
# Engancha una función a nivel Kernel (singleton de gen-6) Y la versión top-level de Essentials
# de la era GameData con una sola llamada (p.ej. pbMessage, pbShowCommandsWithHelp). El bloque recibe (args, x):
# :before -> x=nil ; :after -> x=resultado ; :around -> x=call_next (lo llamas tú para correr el original).

PokeAccess::Hooks.missing
# Array de "Clase#metodo" cuya CLASE existe pero el MÉTODO no (típicamente un typo).
# Una clase ausente NO se registra aquí (es variación normal entre juegos).
```

## PokeAccess::Events

```ruby
PokeAccess::Events.on(event_name) { |*args| ... }
# Suscribirse a un evento

PokeAccess::Events.emit(event_name, *args)
# Emitir evento a todos los suscriptores

# Eventos comunes:
PokeAccess::Events.on(:map_changed) { |map_id| ... }
PokeAccess::Events.on(:location_changed) { |x, y| ... }
```

## PokeAccess::Tags

```ruby
PokeAccess::Tags.get(map_id, event_id)
# Retorna nombre personalizado, o nil

PokeAccess::Tags.set(map_id, event_id, label)
# Establecer nombre personalizado

PokeAccess::Tags.category(map_id, event_id)
# Retorna categoría override (:people, :objects, etc) o nil

PokeAccess::Tags.set_category(map_id, event_id, symbol)
# Establecer categoría

PokeAccess::Tags.hidden?(map_id, event_id)
# ¿Está oculto?

PokeAccess::Tags.set_hidden(map_id, event_id, true/false)
# Ocultar/mostrar

PokeAccess::Tags.remove(map_id, event_id)
# Remover toda información del evento
```

## PokeAccess::Locator

```ruby
PokeAccess::Locator.rebuild_targets
# Reconstruye la lista de objetivos de la categoría actual

PokeAccess::Locator.cycle_category(dir)
# Cambia de categoría (dir +1/-1: personas/objetos/salidas/...)

PokeAccess::Locator.step(delta)
# Avanza/retrocede en la lista de objetivos (delta +1/-1)

PokeAccess::Locator.select_current
# Selecciona el objetivo enfocado y traza la ruta

PokeAccess::Locator.announce_selected(withname)
# Dice el objetivo seleccionado (withname=true incluye el nombre)

PokeAccess::Locator.announce_route
# Dice la ruta hacia el objetivo seleccionado

PokeAccess::Locator.announce_coords
# Dice las coordenadas/posición del jugador

PokeAccess::Locator.toggle_hide_unreachable
# Alterna el filtro de objetivos inalcanzables (Ctrl + tecla de coords)

PokeAccess::Locator.rename_map
# Pide un nombre personalizado para el mapa actual y lo persiste (Mayús + tecla de coords).
# Lo guarda PokeAccess::MapNames; Locator.map_name lo consulta (también cambia cómo se anuncian
# las salidas a ese mapa)

PokeAccess::Locator.map_poll
# Trabajo por frame del localizador (lo llama el poll global)

PokeAccess::Locator.show_menu(msg, choices, cancel)
# Helper genérico de menú de elección (msg + lista de opciones + índice de cancelar)

PokeAccess::Locator.tag_menu
# Abre el menú de etiquetado/categorías del objetivo
```

## PokeAccess::Terrain

```ruby
PokeAccess::Terrain.label(x, y)
# Retorna símbolo de terreno (:surf_water, :tree, etc)

PokeAccess::Terrain.ledge_at?(x, y)
# ¿Hay un ledge (saliente)?

PokeAccess::Terrain.surfable_at?(x, y)
# ¿Se puede surfear ahí (agua surfeable)?

PokeAccess::Terrain.grass?(t) / .ice?(t) / .bridge?(t)
# Predicados sobre un VALOR de terreno (el que devuelve label/raw), no coordenadas.
# Para consultar por tile existe la variante *_at?, p.ej. ice_at?(x, y).
```

## PokeAccess::Settings

```ruby
PokeAccess::Settings.read
# Lee settings.ini del usuario

PokeAccess::Settings.write
# Escribe settings.ini del usuario

PokeAccess::Settings.apply
# Lee y aplica los settings guardados al arrancar
```

## PokeAccess::I18n

```ruby
PokeAccess::I18n.t(key, vars = {})
# Traducir clave de i18n
PokeAccess::I18n.t(:lbl_language)          # "Idioma"
PokeAccess::I18n.t(:mv_pp, :pp => 5, :tot => 15)  # "PP: 5/15"

PokeAccess::I18n.lang
# Idioma actual (:es, :en, etc)

PokeAccess::I18n.available_languages
# Idiomas disponibles
```

## PokeAccess::Paths

```ruby
PokeAccess::Paths::DATA
# Ruta a carpeta de datos (accessibility/data)

PokeAccess::Paths::SOUNDS
# Ruta a sonidos (accessibility/sounds)

PokeAccess::Paths::LANG
# Ruta a las traducciones (accessibility/lang)

PokeAccess::Paths::LIB
# Ruta a las librerías nativas (dll por arquitectura)

PokeAccess::Paths::GAME
# Ruta a la carpeta del perfil de juego (accessibility/game)
```

## PokeAccess::Info

```ruby
PokeAccess::Info.set_info(key, value)
# Establecer el contexto que leerá la tecla de información

PokeAccess::Info.info_text
# Texto del contexto actual (lo que dice la tecla de info)

# Claves comunes (el kind que se pasa a set_info):
:battle_foe         # Enemigo actual en batalla
:move              # Movimiento seleccionado
:pokemon           # Pokémon actual
:text              # Texto genérico
```

## PokeAccess::Perf

```ruby
PokeAccess::Perf.measure(label) { ... }
# Mide el tiempo del bloque y lo acumula bajo la etiqueta

PokeAccess::Perf.report
# Retorna reporte de tiempos (ms promedio/máximo)

PokeAccess::Perf.reset
# Limpiar timers
```

## PokeAccess::Keys

```ruby
PokeAccess::Keys.enabled
# ¿Mod habilitado? (Ctrl+Alt+F8 para toggle)

PokeAccess::Keys.raw_down?(key_code)
# ¿Tecla abajo? (0x77 = F8, 0x11 = Ctrl, 0x12 = Alt)

PokeAccess::Keys.global_poll
# Procesa las teclas contextuales (lo llama el hook de Input#update cada frame)

PokeAccess::Keys.on_frame { ... }
# Registra un bloque que corre una vez por frame en toda escena

PokeAccess::Keys.typing!
# Llamar mientras un campo de texto está activo: suprime TODAS las teclas del mod por unos frames
# (una "t" escrita debe entrar la letra, no leer info)

PokeAccess::Keys.menu_lock!
# Llamar mientras un menú custom con su propio input crudo está activo: suprime las teclas de
# movimiento/comando del mod pero DEJA las teclas de info de solo-lectura (consultar la opción enfocada).
# Decae en unos frames, como typing!. Distinto de typing! (typing! bloquea también las de info).
```

## Ejemplos de Uso

### Obtener nombre de Pokémon (versión agnóstica)
```ruby
name = PokeAccess::Data.species_name(123)
puts name  # "Scyther" en cualquier versión
```

### Crear ruta a objetivo
```ruby
# El origen es siempre $game_player; solo se pasa el destino.
path = PokeAccess::Pathfinder.find_path(target_x, target_y)
if path
  puts "Camino: #{path.length} tiles"
else
  puts "No hay ruta"
end
```

### Leer según versión
```ruby
if PokeAccess::Engine.gamedata?
  puts "Essentials (era GameData) (v19+)"
else
  puts "Gen-6 antiguo"
end

PokeAccess::Engine.for_engine(:only => :gamedata, :min => 21.0) do
  puts "v21 o posterior"
end
```

### Registrar callback
```ruby
PokeAccess::Events.on(:map_changed) do |map_id|
  puts "Mapa cambió a #{map_id}"
end
```

### Crear hook
```ruby
PokeAccess::Hooks.before_hook("MyClass", :my_method) do |obj, args|
  puts "Método llamado con #{args.inspect}"
end
```

## Quick Lookup

| Acción | Método | Doc |
|--------|--------|-----|
| Hablar | `PokeAccess.speak()` | [Audio3D](07_AUDIO3D.md) |
| Datos | `PokeAccess::Data.*()` | [Data API](05_DATA_API.md) |
| Versión | `PokeAccess::Engine.*()` | [Engine Detection](03_ENGINE_DETECTION.md) |
| Ruta | `PokeAccess::Pathfinder.*()` | [Pathfinding](06_PATHFINDING.md) |
| Hook | `PokeAccess::Hooks.*()` | [Patching & Hooks](04_PATCHING_AND_HOOKS.md) |
| Evento | `PokeAccess::Events.*()` | [Events](#) |
| Config | `PokeAccess::Config.*` | [Config](#) |
| Objetos | `PokeAccess::Locator.*()` | [Locator](#) |

---

Volver a [Índice](12_INDEX.md)
