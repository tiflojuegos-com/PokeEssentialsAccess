# Lectores

Un lector es el código enganchado a una pantalla del juego que decide **qué** decir y **cuándo** decirlo.
Vive en `core/<módulo>/`, `plugins/<plugin>.rb` o `games/<perfil>/`, según de quién sea la pantalla. Cómo
se engancha está en [03-hooks](03-hooks.md); esto es lo que va dentro del cuerpo.

## Hablar

| Llamada | Fichero | Qué hace |
|---|---|---|
| `PokeAccess.speak(text, interrupt = true)` | `core/speech/speech.rb` | Habla por el lector activo. Colapsa espacios e ignora texto vacío. |
| `PokeAccess.speak_clean(text, interrupt = true)` | `core/speech/speech.rb` | `speak(clean(text), interrupt)`. |
| `PokeAccess.say_dialogue(message)` | `core/dialogue/dialogue.rb` | Diálogo de `pbMessage`: limpia, guarda la línea para la tecla de repetir, descarta la idéntica dentro de 0,5 s y habla encolado. |

**Texto que viene del juego va por `speak_clean`**: los strings de Essentials llevan códigos de control que
el lector de pantalla deletrearía. El texto que construye el mod, vía i18n, ya está limpio y va por `speak`.

`PokeAccess.clean` (`core/speech/text.rb`) sustituye `\PN` por el nombre del jugador y `\V[n]` por la
variable de juego, convierte `\N` y `|` en espacio, y borra `\C[n]`, el resto de `\X` y `\X[..]`, las
etiquetas `<...>` y los bytes `\x00-\x1f`. Estos últimos importan: sin quitarlos, una línea pausada no
compara igual que su gemela normal, se escapa del dedup de `say_dialogue` y el diálogo se dice dos veces.

### El argumento `interrupt`

| Valor | Cuándo |
|---|---|
| `true` | Movimiento de cursor: el jugador se movió y quiere oír la opción nueva ya. |
| `false` | Líneas que no deben pisarse entre sí: diálogo, mensajes de combate consecutivos, o la lectura de apertura de una pantalla que se abre sobre un título que aún suena. |

## i18n

Ningún texto hablado nuevo se hardcodea en `core/`. Cada cadena es `I18n.t(:clave)`
(`core/foundation/i18n.rb`) y el texto vive en `lang/<código>.txt`: una clave por línea, `clave=texto`,
ignorando líneas en blanco y las que empiezan por `#`. Interpolación con `%{nombre}`.

```
# lang/es.txt
bt_state=%{name}, nivel %{level}, %{hp}
```

```ruby
# core/battle/battle.rb
t = PokeAccess::I18n.t(:bt_state, :name => b.name, :level => b.level, :hp => hp)
```

`t` busca la clave en el idioma activo (`Config.language`), cae al de referencia (`:en`) y, si tampoco
está, devuelve **el nombre de la clave**: el hueco se oye pero nunca peta. Una variable ausente interpola
cadena vacía.

**Una clave nueva va a `lang/es.txt` Y a `lang/en.txt`.** Dos checks estáticos lo obligan:

| Test | Qué exige |
|---|---|
| `test/static/i18n_parity_spec.rb` | `I18n.parity_issues` vacío: ninguna clave presente en un idioma y ausente en otro, ninguna duplicada dentro de un fichero, y los mismos `%{var}` en ambos. |
| `test/static/i18n_refs_spec.rb` | Que toda clave referenciada por el código exista en `lang/en.txt`. Escanea `I18n.t(:k)` y la forma corta `t(:k)` en `core/`, `games/` y `plugins/`. |

Las claves `__meta__` (prefijo `__`) quedan fuera de la paridad. Una familia construida dinámicamente
(`:"chr_#{kind}"`) no se puede escanear: su prefijo se declara en `dynamic_prefixes`, dentro de
`i18n_refs_spec.rb`. `loader/boot.rb` corre la paridad al arrancar y la registra como aviso. Los perfiles
monolingües de `games/` admiten literales; ver [05-extender](05-extender.md).

## Dedup con `Cursor`

Casi toda pantalla reafirma su selección en cada frame: sin dedup, el lector repite la misma entrada
continuamente. `PokeAccess::Cursor` (`core/menus/cursor.rb`) compara la clave actual con la anterior y
solo deja hablar cuando cambia.

| Método | Qué hace |
|---|---|
| `changed?(holder, slot, key)` | `true` (y registra `key`) si difiere de la anterior. Un `key` `nil` nunca cuenta como cambio. |
| `on_change(holder, slot, key) { }` | Ejecuta el bloque solo si cambió; devuelve su valor, o `nil`. El bloque calcula la línea de forma perezosa. |
| `announce(holder, slot, key, interrupt = true, first_interrupt = nil) { }` | `on_change` + `clean` + `speak`. No hace nada si la línea sale vacía. |
| `reset(holder, slot)` | Olvida la clave, para que al reabrir la pantalla se relea aunque la selección no haya cambiado. |
| `pending?(holder, slot)` | `true` si el slot aún no tiene clave: la PRIMERA lectura de un cursor fresco o reseteado. |

`first_interrupt`, quinto argumento de `announce`, es el `interrupt` que usa esa primera lectura mientras
el slot está `pending?`. Sirve para encolar la apertura sin dejar de interrumpir en cada movimiento
posterior; en `nil` (por defecto) todas las lecturas usan `interrupt`.

```ruby
# core/menus/menus.rb -- foco de ventana de comandos: la apertura encola, cada movimiento interrumpe
PokeAccess::Cursor.announce(win, :cmd_focus, [idx, pkt], true, false) { PokeAccess::Menus.focused_text(win) }
```

El estado de dedup vive **en la instancia**: un ivar compuesto (`@access_cur_<slot>`) sobre el `holder`,
la escena o los visuals. Muere con ella, así que la pantalla vuelve a leer al reabrirse en el mismo estado;
a nivel de módulo la dejaría muda. El `slot` separa a dos lectores que comparten escena. La clave puede ser
un índice, un texto o una tupla (`[página, índice]`); deduplicar por el TEXTO cubre la pantalla que cambia
lo que muestra sin mover el índice. Con `holder` `nil` se cae a una tabla de módulo, solo para lectores sin
instancia donde colgarse.

## La Data API

Los datos están fragmentados por eras. Gen-6 los guarda en tablas `PB*` indexadas por entero
(`PBMoveData`, `PBItems`, `PBSpecies`); la era GameData (v19+) en registros indexados por símbolo
(`GameData::Move`, `GameData::Item`). Un lector compartido no puede ramificar por motor, así que
`PokeAccess::Data` (`core/data/data.rb`) resuelve un id a nombre o campo sin que el llamante sepa quién responde.

### Providers

Un provider es un **módulo** con métodos de clase, uno por consulta, registrado con una prioridad; sirve
el de prioridad más alta presente, memoizado hasta el siguiente `register`. Los resolutores van crudos,
sin `rescue`: `Data.resolve` envuelve cada llamada.

| Prioridad | Provider | Fichero | Se registra si |
|---|---|---|---|
| 20 | `DataV21` | `core/data/v21/data_v21.rb` | `GameData` y `GameData::Move` están definidos |
| 10 | `DataG6` | `core/data/gen6/data_g6.rb` | `PBMoves` está definido y `GameData` NO |
| 0 | `DataFallback` | `core/data/data_fallback.rb` | siempre, incondicional |

El de prioridad 0 garantiza que nunca haya cero providers: devuelve el id crudo como string y deja los
campos ricos en `nil`. Decir "PIKACHU" es mejor que callar. `loader/boot.rb` avisa cuando el provider
activo es ese (`active_priority` ≤ 0), así un motor no reconocido no queda como estado mudo silencioso.

### Métodos

| Método | Devuelve | gen-6 | era GameData |
|---|---|---|---|
| `move_name(id)` | "Placaje" | `PBMoves.getName` | `Move#name` |
| `move_type_name(id)` | "Normal" | `PBTypes.getName(PBMoveData#type)` | `Type.get(Move#type).name` |
| `move_power(id)` | 40 | `PBMoveData#basedamage` | `attr_of(:power, :base_damage)` |
| `move_accuracy(id)` | 100 | `PBMoveData#accuracy` | `Move#accuracy` |
| `move_description(id)` | texto largo | `pbGetMessage(MoveDescriptions)` | `Move#description` |
| `type_name(id)` | "Fuego" | `PBTypes.getName` | `Type#name` |
| `item_name(id)` | "Poción" | `PBItems.getName` | `Item#name` |
| `item_name_plural(id)` | "Pociones" | `PBItems.getNamePlural` | `portion_name_plural`, si no `portion_name`, si no `name` |
| `item_description(id)` | texto | `pbGetMessage(ItemDescriptions)` | `Item#description` |
| `item_id(sym)` | `[id, nombre]` | `PBItems.const_get(sym)`, si no `getID` | el símbolo ES el id |
| `species_name(id)` | "Pikachu" | `PBSpecies.getName` | `Species#name` |
| `species_entry(id)` | `[nombre, categoría, ficha]` | `pbGetMessage(Kinds` / `Entries)` | `category` / `pokedex_entry` |
| `ability_name(id)` | "Estática" | `PBAbilities.getName` | `Ability#name` |
| `nature_name(id)` | "Miedosa" | `PBNatures.getName` | `Nature#name` |
| `stat_name(s)` | "Ataque" | `PBStats.getName` | `Stat#name` |
| `status_name(st)` | ver nota | `Config.status_names[st]` | `Status#name` |
| `pokemon_types(pk)` | `["Fuego", "Volador"]` | `type1` / `type2` | `pk.types` |

`status_name` es asimétrico: en la era GameData devuelve el texto del estado; en gen-6, la **clave i18n**
de `Config.status_names` (`:st_burn`), que el llamante pasa por `I18n.t`; en el fallback, `nil`.
`pokemon_types` nunca devuelve `nil`: `[]` cuando no resuelve.

`resolve` devuelve `nil` en dos casos: el dato no existe (silencio intencionado), o el provider ha lanzado
(probable bug). El segundo se anota una vez por `(método, clase de error)` en el marcador y en
`Data.errors`, y devuelve `nil` igual: el lector degrada en vez de crashear. Escribe contra un `nil` posible.

## Introspección defensiva

El motor no expone accesores para casi nada, y lo que expone cambia de nombre entre eras. Estos helpers
viven en `core/foundation/const.rb` y tragan cualquier excepción.

| Helper | Devuelve |
|---|---|
| `PokeAccess.ivar(obj, :@index, fallback = nil)` | El ivar, o `fallback` si no está o la lectura lanza. |
| `PokeAccess.ivar_i(obj, :@index, fallback = 0)` | Igual, coercionado a entero. |
| `PokeAccess.sprite(scene, "commands")` | La ventana de `@sprites["commands"]`, o `nil` si falta el hash o la clave. |
| `PokeAccess.attr_of(obj, :totalpp, :total_pp)` | El primero de esos accesores que responda algo no nulo, o `nil`. |

`attr_of` existe porque Essentials renombró accesores entre eras —`totalpp` → `total_pp`, `base_damage` →
`power`— y cada fangame conservó la grafía de la que se bifurcó. Pedir un solo nombre no peta, porque estas
lecturas ya van guardadas: devuelve `nil`, y un movimiento sin PP o con potencia cero se lee como dato
ausente, no como bug. Los nombres se prueban en orden, el más común primero.

```ruby
# core/data/v21/data_v21.rb -- los híbridos v18 sobre GameData conservaron base_damage
def self.move_power(id); PokeAccess.attr_of(GameData::Move.get(id), :power, :base_damage); end
```

El resto de helpers de ese fichero (`const_at`, `dedicate`, `dedicated?`) en [08-referencia](08-referencia.md).

## Reparto: el texto al core, el hook aparte

El constructor de la línea va al core como función pura del estado de la escena; el hook —qué clase, qué
método, cuándo— va aparte, en la capa a la que pertenece esa pantalla. Dos pantallas con la misma forma
comparten lo primero, no lo segundo. `PokeAccess::MoveList` (`core/menus/move_list.rb`) lee una lista de
movimientos dibujada a mano y `detail` habla la línea completa vía `MoveInfo.line`, desde dos capas:

```ruby
# core/menus/v21/move_relearner_v21.rb -- Move Relearner de v21 vanilla
PokeAccess::Hooks.after_hook(PokeAccess::MoveRelearnerV21::SCENE, :pbDrawMoveList) do |s, _r, _a|
  PokeAccess::MoveList.detail(s)
end
# plugins/sv_summary_screen.rb -- tutor de movimientos huevo, de un plugin de terceros
PokeAccess::Hooks.after_hook("EggMoveLearner_Scene", :pbDrawMoveList, :optional => true) do |s, _r, _a|
  PokeAccess::MoveList.detail(s)
end
```

El módulo lleva el nombre de **lo que lee**, no el de la pantalla que lo pidió primero. Mientras se llamó
`SkyEggMove` y vivía en la carpeta del fork, que un lector del core lo usara cruzaba versiones y el check
de acoplamiento tenía que llevar una entrada de whitelist, la única del mod. Renombrarlo eliminó la
excepción en vez de documentarla: hoy `test/static/coupling_spec.rb` tiene la whitelist vacía.
