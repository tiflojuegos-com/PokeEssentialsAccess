# Extender

Recetas para añadir cosas al mod. Todas terminan en `ruby test/run_all.rb`; la última sección dice qué
check falla y por qué.

## ¿Esto va a `core/`, a `plugins/` o a `games/`?

La pregunta es de quién es la clase que vas a enganchar.

| La clase… | Es | Capa |
|---|---|---|
| está en algún tag de Essentials upstream | vanilla | `core/` |
| la trae un plugin que instalan varios fangames | de terceros | `plugins/` |
| solo existe en un juego | del juego | `games/<perfil>/` |

```bash
# dentro de un checkout de pokemon-essentials (upstream), con los tags v19...v21.1
git grep -l "class PokemonBag_Scene" v19 v19.1 v20 v20.1 v21 v21.1   # con salida = vanilla
git grep -l "class Window_Berrydex" v19 v19.1 v20 v20.1 v21 v21.1    # sin salida = no lo es
```

Si no es vanilla, hay que mirar de dónde sale en los scripts del propio juego. Para eso está
`tools/dump_scripts.rb`, que los extrae a ficheros `.rb` legibles:

```bash
ruby tools/dump_scripts.rb "C:\ruta\al\juego"
```

Escribe `Scripts_dump/` dentro de la carpeta del juego (o donde le digas con un segundo argumento). Lee
`Data/Scripts.rxdata`, el árbol suelto de scripts cuando el juego solo guarda ahí un cargador, y
`Data/PluginScripts.rxdata`; si el juego va empaquetado en `Game.rgssad`, lo abre igual. No necesita gemas.

Con el volcado delante:

| Carpeta de origen | Qué es |
|---|---|
| `_PluginScripts/` o una carpeta de addons numerada | plugin de terceros |
| Cualquier otra | código del juego, o un plugin pegado a mano |

Solo unos pocos juegos separan los plugins en su propia carpeta; el resto pega el código del plugin en la
lista de scripts, así que ahí la ruta no informa. Esos tampoco tienen `PluginManager`: por eso
`Plugins.game_plugins` devuelve `nil` y no una lista vacía.

Dos trampas:

1. **Un plugin que REABRE una clase vanilla aparece definiéndola.** Deluxe Battle Kit reabre `Battle` y
   Modular UI Scenes reabre `PokemonPokedexInfo_Scene`: la clase existe en todos los juegos, así que una
   sonda por clase responde "sí" siempre. Se detectan por método: `"Battle#pbToggleSpecialActions"`.
2. **El fork de La Base de Sky mete en su motor cosas que siguen siendo plugins.** Los juegos hechos sobre
   él traen MUI y DBK dentro del árbol de scripts del motor, no en una carpeta de plugins, pero son recursos
   de terceros que varios juegos instalan: van a `plugins/` como cualquier otro, con sonda por MÉTODO cuando
   solo reabren clases vanilla (`dbk_battle` sondea `"Battle#pbToggleSpecialActions"`).

## 1. Añadir un perfil de juego

1. Crear `games/<clave>/` con `manifest.rb` y `constants.rb` como mínimo.
2. Escribir el manifiesto: lista ordenada, sin `.rb`, orden = orden de carga.

```ruby
# games/africanus/manifest.rb
{
  :modules => %w[
    constants
    pausemenu
    minigames
  ],
  :plugins => %w[easy_questing logros]
}
```

Lo que depende del motor va a `core/`, así lo aprovechan también los juegos desconocidos. Lo que comparte una saga o un autor va a un perfil común, `games/<nombre>_common/`, con su propio `manifest.rb`, que cada juego carga con `:imports => %w[<nombre>_common]`. Lo propio del juego va a su perfil. Ningún fichero se copia entre dos perfiles: lo que se repetiría va al común. Los `Game.define` de un común llevan el nombre del común, que nunca da nombre al juego.

3. Declarar el perfil en `constants.rb`.

```ruby
# games/armonia/constants.rb
PokeAccess::Game.define("armonia") do
  button_labels :x => "DexNav"
end
```

4. Registrarlo en `games/catalog.json`, la lista con la que el launcher reconoce los juegos.

| Campo | Qué es |
|---|---|
| `key` | la carpeta en `games/` |
| `display` | el nombre hablado |
| `titles` | títulos exactos del `mkxp.json` o del `Game.ini`; cada `"pokemon x"` necesita su gemelo `"pokémon x"` |
| `detect` | regex ci sobre "carpeta + exe", o `null` |
| `exes` | exe distintivo; un `Game.exe` genérico no identifica |
| `engine` | `"gen6"`, `"gamedata"` o `"any"` |

La detección es por capas: `titles`, luego `detect`, luego `exes`, y si nada encaja se pregunta al jugador.
Gana el match MÁS LARGO, no el primero. **`generic` tiene que quedar el ÚLTIMO**: es el comodín (`titles`
vacío, `detect` en `null`) y el orden se conserva para los launchers antiguos, que van por first-match.

5. Prefijar los nombres de módulo con el del juego (`ZBattleBag`, `AnilMenus`) si pueden colisionar con el
   core: sin prefijo, `coupling_spec` lo lee como una reapertura.
6. Añadir las claves i18n del perfil, prefijadas, a los dos ficheros de `lang/` (§5). Un perfil de fangame
   monolingüe puede hardcodear literales; ver invariante 4 en [01-vision-general](01-vision-general.md).
7. Si el motor es gen-6, todo el perfil pasa `check187.py`. Los modernos ya están en su lista `MODERN`.

Lo que NO pasa solo: la suite de comportamiento carga UN perfil por motor (`pokemon_z` en gen-6, `anil` en
gamedata). A uno nuevo lo escanean `manifest_check.rb`, `coupling_spec` y `check187.py`, pero nadie lo CARGA.

## 2. Añadir un lector a un perfil

1. Un fichero por pantalla en `games/<perfil>/<pantalla>.rb`, con su `Game.define`.
2. Enganchar la clase por su nombre en string: si no existe, el hook no se registra. Por eso un perfil puede
   declarar lectores de clases que solo tiene una versión del juego.
3. Añadir el nombre, sin `.rb`, al `:modules` del `manifest.rb`.

```ruby
# games/relict/difficulty.rb
PokeAccess::Game.define("relict") do
  after("PickDifficulty", :update) do |scr, _ret, _args|
    diffs = PokeAccess.ivar(scr, :@difficulties)
    idx   = PokeAccess.ivar(scr, :@index)
    # ...
  end
end
```

Si el core ya trae el patrón, el fichero es una línea:

```ruby
# games/africanus/pausemenu.rb
PokeAccess::SpriteButtonMenu.define("africanus")
```

Volver de un submenú lo señala `PokeAccess::MenuReturn`, una sola vez para todos los menús: un lector se
apunta con `MenuReturn.on_return { ... }` y declara con `MenuReturn.bare("Clase", :metodo)` las pantallas que
su juego abre sin fade ni diálogo. Solo la salida más externa dispara a los oyentes.

Si la pantalla dice filas al moverse, van por la verbosidad ([04-lectores](04-lectores.md)): sus partes con su
nivel, la T con lo que el nivel quita, las pistas y las posiciones por sus puertas. Una fila de un tipo que el
núcleo ya tiene usa su lectura (un objeto a la venta es `:shop_item`, lo venda la pantalla que lo venda); una de un tipo que no tiene declara
la suya al final del fichero, con sus claves `vb_*` y `vbh_*` en los seis idiomas, que `i18n_refs_spec` exige:

```ruby
PokeAccess::Verbosity.define_reading(:rem_blessing, :vb_rem_blessing, :vbh_rem_blessing)
```

La DSL completa está en [03-hooks](03-hooks.md); cómo se arma el texto y se deduplica, en
[04-lectores](04-lectores.md). **Un perfil no reabre un módulo del core**: la vía declarada es `override`,
que además queda listada en el diagnóstico, y `coupling_spec` rechaza la reapertura.

## 3. Añadir un lector de plugin de terceros

Antes de escribir una línea, compara las DOS copias del plugin en los dumps: el mismo nombre de clase no
garantiza el mismo código. En orden: aridad de los métodos que enganchas, nombre y FORMA del dato de los
ivars que lees, existencia de los métodos de apoyo (con `respond_to?`, nunca `rescue true`), y si el método
enganchado es un `loop do` modal (ahí hace falta `SceneWatcher`). La cabecera del fichero deja escrito dónde
divergen.

**El reparto: el constructor de texto va al core, los hooks al plugin.** QUÉ decir suele servir para más de
un juego; CUÁNDO decirlo es del plugin.

```ruby
# plugins/encounter_list_ui.rb -- solo disparadores; el texto lo arma PokeAccess::EncounterList, en el core.
PokeAccess::Hooks.before_hook("EncounterList_Scene", :pbStartScene, :optional => true) { |s, _a| PokeAccess::Cursor.reset(s, :encounter_list) }
PokeAccess::Hooks.after_hook("EncounterList_Scene", :drawPresent, :optional => true) { |s, _r, _a| PokeAccess::EncounterList.read_present(s) }
```

1. `plugins/<nombre>.rb`. **El nombre es el del PLUGIN, no el de la pantalla** (`encounter_list_ui`, no
   `encounter_screen`). Todos los hooks, `:optional`.
2. Una línea en `plugins/manifest.rb`: `:<nombre> => "ClaseDelatora"`. Si el plugin no trae clase propia y
   reabre una del motor, la forma es `"Clase#metodo"`; la sonda pasa por `Engine.has?`, que acepta las dos.
3. `:plugins => %w[... <nombre>]` en cada perfil cuyo juego lo trae. Ni uno de más ni uno de menos: el
   censo comprueba las dos direcciones.
4. Regenerar el censo: `ruby test/static/build_fangame_census.rb`. Lee los dumps (que viven fuera del repo)
   y reescribe `test/static/fangame_classes.txt` y `test/static/plugin_census.txt`.
5. Un spec que fije **la divergencia**, no lo obvio: si las dos formas no están en el test, el lector pasará
   verde el día que alguien simplifique la que no está cubierta.

`generic` no declara nada: usa `:plugins => :auto` y pregunta al juego en marcha por esa misma tabla.

## 4. Añadir una opción al menú de configuración

1. Una fila en `Config::SCHEMA`: `[clave, defecto, tipo, categoría, lbl_etiqueta, help_ayuda]`.
2. Sus claves `lbl_` y `help_` en los seis ficheros de `lang/`.

```ruby
# core/foundation/config.rb
[:proximity_radar,    false, :flag,  :audio,         :lbl_proximity_radar, :help_proximity_radar],
[:audio3d_wall_range, 3,     :tiles, :audio3d_walls, :lbl_wall_range,      :help_wall_range],
```

Con eso aparece en su categoría, se persiste en `settings.ini` y vuelve con "restaurar valores por defecto":
`Settings` y `ConfigMenu` derivan los dos del SCHEMA. Tres casos piden más:

| Caso | Qué más hace falta |
|---|---|
| Tipo numérico nuevo | fila en `KIND_BOUNDS` con `[min, max, paso, unidad]`; `Settings::NUMERIC` sale de ahí |
| Tipo de símbolo nuevo | añadirlo a `Settings::SYMS` y darle lectura y ciclado en `core/menus/config_rows.rb` (`value_text` y `adjust_setting`) |
| Categoría nueva | fila en `Config::CATEGORIES` si es de raíz, o un `:enter` empujado a mano en la pantalla que la cuelga (`config_rows.rb`, `config_dicts.rb`) |

No reutilices un tipo por parecido de unidad: `:sonar` (1-30) existe aparte de `:tiles` (1-20) para que
subir el alcance del sonar no ensanche de rebote la sonda de paredes.

## 5. Añadir texto hablado

1. La clave en los seis `lang/*.txt`, con los MISMOS huecos `%{var}`.
2. Usarla con `PokeAccess::I18n.t(:clave)` o con el alias corto `t(:clave)`.
3. Voz y términos. El mod es un programa y nunca habla en primera persona ("no se ha podido calcular la ruta", no
   "no he podido"); al jugador se le habla con el registro de cada fichero (tú, you, du, tu, ty, você). Los
   términos de Pokémon son los oficiales de cada idioma (WikiDex, Bulbapedia, Pokéwiki, Poképédia), cotejados
   con lo que pintan los juegos.
4. Plurales. Si las palabras cambian con el número, la clave se escribe por formas y el código pasa la cuenta en
   `:n` (si el texto usa otro hueco para el número, se pasa además como `:n`). Cada idioma escribe las formas de
   su regla CLDR: `one` y `other` en es, en, de, fr y pt (en fr y pt el 0 también va en singular), `one`, `few`
   y `many` en pl. Un idioma al que el número no le cambia nada ("Medallas: %{n}") deja la clave sin formas; la
   paridad solo exige que, si un idioma usa formas, estén todas y ninguna más.

```
# lang/es.txt
load_play=Horas de juego: %{h}, minutos: %{m}

# lang/en.txt
load_play=Hours played: %{h}, minutes: %{m}

# lang/es.txt: t(:loc_steps, :n => 1) dice "a 1 paso"
loc_steps.one=a %{n} paso
loc_steps.other=a %{n} pasos

# lang/pl.txt: t(:tiles_unit, :n => 3) dice "pola"
tiles_unit.one=pole
tiles_unit.few=pola
tiles_unit.many=pól
```

Formato `clave=texto`, UTF-8, `#` comenta. Las familias de claves construidas en tiempo de ejecución
(`:"chr_#{kind}"`) no se pueden grepear, y nada las exime (`dynamic_prefixes`, en `test/static/i18n_refs_spec.rb`,
sigue vacío a propósito): sus claves tienen que existir como cualquier otra, y solo su propio spec puede comprobarlo. Las transcripciones de texto que el juego dibuja van siempre literales:
replican al juego, no son frases del mod.

## Reglas automatizadas

`ruby test/run_all.rb`, y al terminar `local install --yes` con el launcher ([cómo](01-vision-general.md#instalar)). Qué falla y por qué:

| Check | Falla si |
|---|---|
| `manifest_check.rb` | un `.rb` de `core/` o de un perfil no está en su manifiesto, una entrada no tiene fichero, o está listada dos veces |
| `manifest_check.rb` (catálogo) | una carpeta de `games/` no tiene entrada en `catalog.json` o al revés; un `detect` es regex inválida o no encaja ni con su propio `display`; dos perfiles se disputan un título o un exe; un `exes` dice `Game.exe` |
| `catalog_detect_spec.rb` | el `detect` de `pokemon_z` vuelve a comerse una unidad `Z:` o un `mkxp-z.exe`; un título `"pokemon x"` no lleva su gemelo acentuado |
| `coupling_spec.rb` | referencia cruzada entre versiones del core, entre perfiles, de `shared` a una versión, de o hacia `plugins/`; o un perfil reabre un módulo del core |
| `coupling_spec.rb` (censo) | un fichero de `core/` nombra en string una clase que solo tiene UN fangame |
| `plugins_spec.rb` | un fichero de `plugins/` no está en la tabla o al revés; un hook no es `:optional`; dos lectores se disputan el mismo `Clase#metodo`; dos entradas comparten sonda; un perfil declara un plugin que su juego no trae o deja de declarar uno que sí; la sonda no está en el censo |
| `plugins_smoke_spec.rb` | un lector de `plugins/` engancha una clase o un método que ya no se llama así |
| `i18n_parity_spec.rb` | una clave está en un idioma y no en otro, está duplicada, sus huecos `%{}` difieren, o sus formas de plural no son las de la regla del idioma |
| `i18n_refs_spec.rb` | el código referencia una clave que no está en `lang/en.txt`, incluidas las `lbl_`/`help_` del SCHEMA |
| `check187.py` | sintaxis moderna en `core/`, `plugins/`, `loader/` o un perfil gen-6 |
| `mts_mutator_guard_spec.rb` | hay `CONST + array` o `x - array` en código que carga bajo Pokémon Z, cuyo motor redefine `Array#+` y `Array#-` como mutadores in-place |
| `ivars_spec.rb` | un lector toma de un objeto del juego un ivar que ese juego no tiene en ninguna parte, o que el censo aún no conoce |
| `arity_spec.rb` | el cuerpo de un hook lee `args[N]` más allá de lo que algún juego pasa a ese método, o un mismo cuerpo atado a varias clases lee una posición que los juegos nombran distinto (mensaje en una clase, lista de comandos en otra); los registros en bucle cuentan, vía `ReaderSites.registrations` |
| `era_calls_spec.rb` | el core compartido llama a un nombre `pb*` de Essentials que no definen todas las fuentes, y la llamada no es escalera hacia el nombre de la otra era, ni guarda, ni fila explicada; o una explicación sobrevive a su llamada |
| `blocking_hooks_spec.rb` | un hook `after` cuelga de un método que ES el bucle bloqueante de la pantalla, así que hablaría al salir |
| `imports_spec.rb` | un `:imports` nombra un común que no existe, un común tiene entrada en el catálogo, importa a otro o no lo importa nadie, o un fichero está copiado entre dos perfiles jugables |
