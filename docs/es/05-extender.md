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
# F:\claude\pokemon esentials\pokemon-essentials -- el checkout de upstream, con los tags v19...v21.1
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
2. **El fork de La Base de Sky mete en su motor cosas que parecen plugins.** Los juegos hechos sobre él
   traen MUI y DBK dentro del árbol de scripts del motor, no en una carpeta de plugins. Lo que es del FORK,
   y no de un juego, va a `core/<módulo>/skyflyer/`.

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

3. Declarar el perfil en `constants.rb`.

```ruby
# games/armonia/constants.rb
PokeAccess::Game.define("armonia") do
  button_labels :x => "DexNav"
end
```

4. Registrarlo en `games/catalog.json`, fuente única del instalador y del launcher.

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
2. Sus claves `lbl_` y `help_` en `lang/es.txt` y `lang/en.txt`.

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
| Tipo de símbolo nuevo | añadirlo a `Settings::SYMS` y darle lectura y ciclado en `core/menus/config_menu.rb` |
| Categoría nueva | fila en `Config::CATEGORIES` si es de raíz, o un `:enter` empujado a mano en `config_menu.rb` |

No reutilices un tipo por parecido de unidad: `:sonar` (1-30) existe aparte de `:tiles` (1-20) para que
subir el alcance del sonar no ensanche de rebote la sonda de paredes.

## 5. Añadir texto hablado

1. La clave en `lang/es.txt` Y en `lang/en.txt`, con los MISMOS huecos `%{var}`.
2. Usarla con `PokeAccess::I18n.t(:clave)` o con el alias corto `t(:clave)`.

```
# lang/es.txt
load_play=%{h} horas %{m} minutos de juego

# lang/en.txt
load_play=%{h} hours %{m} minutes played
```

Formato `clave=texto`, UTF-8, `#` comenta. Las familias de claves construidas en tiempo de ejecución
(`:"chr_#{kind}"`) no se pueden grepear: su prefijo se declara en `dynamic_prefixes`, dentro de
`test/static/i18n_refs_spec.rb`. Las transcripciones de texto que el juego dibuja van siempre literales:
replican al juego, no son frases del mod.

## Reglas automatizadas

`ruby test/run_all.rb`, y al terminar `powershell -File installer/install.ps1 -Force`. Qué falla y por qué:

| Check | Falla si |
|---|---|
| `manifest_check.rb` | un `.rb` de `core/` o de un perfil no está en su manifiesto, una entrada no tiene fichero, o está listada dos veces |
| `manifest_check.rb` (catálogo) | una carpeta de `games/` no tiene entrada en `catalog.json` o al revés; un `detect` es regex inválida o no encaja ni con su propio `display`; dos perfiles se disputan un título o un exe; un `exes` dice `Game.exe` |
| `catalog_detect_spec.rb` | el `detect` de `pokemon_z` vuelve a comerse una unidad `Z:` o un `mkxp-z.exe`; un título `"pokemon x"` no lleva su gemelo acentuado |
| `coupling_spec.rb` | referencia cruzada entre versiones del core, entre perfiles, de `shared` a una versión, de o hacia `plugins/`; o un perfil reabre un módulo del core |
| `coupling_spec.rb` (censo) | un fichero de `core/` nombra en string una clase que solo tiene UN fangame |
| `plugins_spec.rb` | un fichero de `plugins/` no está en la tabla o al revés; un hook no es `:optional`; dos lectores se disputan el mismo `Clase#metodo`; dos entradas comparten sonda; un perfil declara un plugin que su juego no trae o deja de declarar uno que sí; la sonda no está en el censo |
| `plugins_smoke_spec.rb` | un lector de `plugins/` engancha una clase o un método que ya no se llama así |
| `i18n_parity_spec.rb` | una clave está en un idioma y no en otro, está duplicada, o sus huecos `%{}` difieren |
| `i18n_refs_spec.rb` | el código referencia una clave que no está en `lang/en.txt`, incluidas las `lbl_`/`help_` del SCHEMA |
| `check187.py` | sintaxis moderna en `core/`, `plugins/`, `loader/` o un perfil gen-6 |
| `mts_mutator_guard_spec.rb` | hay `CONST + array` o `x - array` en código que carga bajo Pokémon Z, cuyo motor redefine `Array#+` y `Array#-` como mutadores in-place |
| `ivars_spec.rb` | un lector toma de un objeto del juego un ivar que ese juego no tiene en ninguna parte, o que el censo aún no conoce |
| `blocking_hooks_spec.rb` | un hook `after` cuelga de un método que ES el bucle bloqueante de la pantalla, así que hablaría al salir |
| `twins_spec.rb` | dos gemelos declarados en `test/static/twins.rb` han dejado de ser idénticos |
