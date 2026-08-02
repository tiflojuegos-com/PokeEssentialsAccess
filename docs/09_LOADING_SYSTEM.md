# Sistema de Carga - Boot Process

## Flujo General de Carga

```
┌─────────────────────────────────────────────┐
│ mkxp-z arranca y lee mkxp.json              │
│  → clave "preloadScript" (un ARRAY)         │
└─────────────────────────────────────────────┘
                    ↓
┌─────────────────────────────────────────────┐
│ loader/preload_access.rb                    │
│  - Escribe preload_started.txt              │
│  - Envuelve Graphics.update                 │
│  - Espera: las clases del juego NO existen  │
└─────────────────────────────────────────────┘
                    ↓
┌─────────────────────────────────────────────┐
│ mkxp-z carga Scripts.rxdata (Essentials)    │
│ y arranca el bucle principal                │
└─────────────────────────────────────────────┘
                    ↓
┌─────────────────────────────────────────────┐
│ Graphics.update: ¿$scene definido, o ya van │
│ 120 frames? → eval boot.rb UNA vez          │
└─────────────────────────────────────────────┘
                    ↓
┌─────────────────────────────────────────────┐
│ PokeAccessBoot.run                          │
│  - core/ por manifest                       │
│  - plugins/ que el perfil DECLARA           │
│  - game/ por manifest                       │
│  - Settings.apply (encima de los defaults)  │
│  - Cuatro diagnósticos al log               │
└─────────────────────────────────────────────┘
```

## Etapa 1: Preload Script

**Ubicación**: `loader/preload_access.rb`

Los preload scripts corren ANTES de `Scripts.rxdata`, cuando las clases del juego todavía no existen: por
eso el preload no carga el mod, sino que DIFIERE su carga. Es reversible (no toca `Scripts.rxdata`).

```ruby
module AccessPreload
  PATH        = "accessibility/boot.rb"
  START_MARK  = "accessibility/data/preload_started.txt"
  READY_FRAME = 120
  @loaded = false
  @frames = 0

  # Deja constancia de que el preload EN SÍ se ejecutó, con independencia de que boot funcione: así se
  # distingue "boot falló" de "el preloadScript ni siquiera corrió".
  def self.mark_started
    File.open(START_MARK, "w") { |f| f.write("preload ok ruby=#{RUBY_VERSION rescue '?'}\n") }
  rescue StandardError
  end

  def self.try_load
    return if @loaded
    @frames += 1
    return unless (defined?($scene) && $scene) || @frames >= READY_FRAME
    @loaded = true
    begin
      eval(File.read(PATH), TOPLEVEL_BINDING, PATH)
    rescue Exception => e
      raise if e.is_a?(SystemExit)
      # ... vuelca clase, mensaje y backtrace a loader_error.txt
    end
  end

  class << Graphics
    unless method_defined?(:update__access_preload)
      alias_method :update__access_preload, :update
      def update(*a)
        r = update__access_preload(*a)
        AccessPreload.try_load
        r
      end
    end
  end
end

AccessPreload.mark_started
```

Dos señales de "ya se puede": `$scene` definido (el caso normal) y un contador de frames como red de
seguridad para builds que nunca lo ponen. El `unless method_defined?` evita envolver `Graphics.update` dos
veces si el script se recarga.

## Etapa 2: Boot (Carga Principal)

**Ubicación**: `loader/boot.rb`. Es el mecanismo COMPARTIDO por los dos cargadores (el preload de mkxp-z y
la inyección nativa de RMXP): ambos acaban en `PokeAccessBoot.run`.

```ruby
module PokeAccessBoot
  ROOT = "accessibility"

  def self.run
    load_manifest("#{ROOT}/core")
    load_plugins(declared_plugins("#{ROOT}/game"))
    load_manifest("#{ROOT}/game")
    (PokeAccess::Settings.apply rescue nil) if defined?(PokeAccess) && PokeAccess.const_defined?(:Settings)
    # ... y los diagnósticos de la tabla de abajo
  end

  # Lee <dir>/manifest.rb y evalúa cada <dir>/<entrada>.rb en ESE orden -- nunca el del sistema de
  # ficheros. El manifiesto admite DOS formas y las dos son actuales: un Array (la lista de módulos de
  # siempre) o un Hash {:modules => [...], :plugins => [...]} cuando el perfil declara lectores de
  # plugins de terceros. Tolerar ambas es lo que deja fuera del cambio a los perfiles que no lo necesitan.
  def self.load_manifest(dir)
    mf = "#{dir}/manifest.rb"
    return log("#{dir}: sin manifest.rb") unless File.exist?(mf)
    list = modules_of(read_manifest(mf), mf)
    return if list.nil?
    list.each { |entry| load_module("#{dir}/#{entry}.rb") }
  end

  # Los lectores de plugins que el perfil declara. Nunca se infieren: un lector de plugin solo debe correr
  # donde alguien comprobó que encaja, porque dos juegos pueden traer el mismo plugin con tripas distintas.
  # Un fichero declarado que NO está se apunta al log y se salta -- una instalación a medias cuesta una
  # pantalla muda, no el mod entero.
  def self.load_plugins(names)
    names.each { |name| load_module("#{ROOT}/plugins/#{name}.rb") }
  end

  # Evalúa un módulo; si revienta, lo apunta en el log en vez de abortar el resto.
  def self.load_module(path)
    eval(File.read(path), TOPLEVEL_BINDING, path)
  rescue Exception => e
    raise if e.is_a?(SystemExit)
    log("#{path}: #{e.class}: #{e.message}\n#{(e.backtrace || []).join("\n")}")
  end
end

PokeAccessBoot.run
```

El orden importa también entre las dos llamadas: los settings del usuario se aplican DESPUÉS del perfil del
juego, para que ganen sobre los defaults por juego.

**Diagnósticos que escribe `run` al terminar** (todos a `loader_error.txt`, todos silenciables por su
`rescue`):

| Comprobación | Qué delata |
|--------------|-----------|
| `Hooks.missing` | Enganches cuyo método no existe: casi siempre un typo en el nombre |
| `Data.active_priority <= 0` | Ningún provider de motor se registró: los datos saldrán como ID crudos |
| `I18n.parity_issues` | Una clave existe en un idioma y en el otro no |

## Manifests: Orden de Carga

### Core Manifest

**Ubicación**: `core/manifest.rb`. Es un array `%w[...]` de entradas `subsistema/nombre` (sin `.rb`), y es
la ÚNICA fuente del orden de carga: añadir o mover un módulo es editar una línea, sin prefijos numéricos ni
globs. Extracto de la cabecera real:

```ruby
%w[
  foundation/config
  foundation/const      # const_at: resolución "A::B::C" 1.8.7-safe (base de Hooks, Input, Menus, Engine)
  foundation/paths
  util/kv_file          # el único parser clave=valor (lang, settings, tags, map_names)
  foundation/i18n
  util/grouping         # helpers puros: union_groups
  util/text             # helpers puros: join_parts, types_phrase
  util/player
  foundation/game
  foundation/engine
  foundation/settings
  foundation/events
  foundation/caches
  foundation/clipboard
  foundation/perf
  foundation/tags
  foundation/map_names

  data/data
  data/data_fallback
  data/gen6/data_g6
  data/v21/data_v21

  speech/markers
  speech/text
  speech/speech

  input/hooks           # semi-API de patching
  input/keyboard        # teclado físico puro
  input/focus           # foco de ventana
  input/remap
  input/input           # Keys: el orquestador, delega en Keyboard y Focus
  input/diag            # reabre Keys con su mitad diagnóstica

  menus/config_menu
  nav/terrain
  audio/spatial
  audio/glossary
  audio/audio3d

  # ... field, puzzles, menus, battle, party, nav (ver core/manifest.rb para la lista completa)

  util/recorder         # el último: se cuelga de PokeAccess.on_speak y de Hooks.frame_hook
]
```

El layout es módulo-primero: cada subsistema guarda sus lectores agnósticos en la raíz y usa subcarpetas
solo para lo que difiere por motor, cada una gateada por existencia de clase para que sea no-op fuera de
ella:

| Subcarpeta | Motor |
|------------|-------|
| `<módulo>/gen6/` | Era gen-6 (Ruby 1.8.7: `PokeBattle_Scene`, `PScreen`, datos `PB*`) |
| `<módulo>/v21/` | Era GameData, Essentials v19-v21.1 (`Battle::Scene`, `GameData`, scenes/MUI) |
| `<módulo>/v22/` | El rework `UI::` de v22 (`UI::BaseScreen`, `UI::*Visuals`) |
| `<módulo>/skyflyer/` | Clases del fork de La Base de Sky y sus plugins (DBK, tutor de movimientos huevo) |

**Orden es CRÍTICO** (dependencias reales, no estéticas):

- `foundation/const` antes que todo lo que resuelve clases por nombre (Hooks, Engine, Menus)
- `foundation/paths` y `util/kv_file` antes que `i18n`, `settings`, `tags` y `map_names`
- `data/data` antes que los providers `data/gen6/` y `data/v21/`
- `speech/markers` antes que `speech/speech` (que usa `write_marker` y `DLL_DIR`)
- `input/keyboard` e `input/focus` antes que `input/input`, que reexporta sus constantes
- `input/hooks` antes que cualquier lector
- `menus/cursor` antes que `menus/menus`

### Game Manifest

```ruby
# games/relict/manifest.rb -- solo módulos del juego; el core ya está cargado
%w[
  pausemenu
  difficulty
  plates
]
```

Cuando el perfil además usa lectores de `plugins/`, el manifiesto pasa a la forma extendida. Los módulos
propios siguen en `:modules` y los plugins van en `:plugins`, con el nombre del fichero de `plugins/`:

```ruby
# games/royal/manifest.rb -- cinco de sus pantallas vienen de plugins de terceros
{
  :modules => %w[
    constants
    selectors
    currydex
  ],
  :plugins => %w[berrydex hall_of_fame_bw photo_album secret_bases]
}
```

Los plugins se cargan ENTRE el core y el perfil, a propósito: pueden usar el core, y el perfil carga
después para poder sobrescribir un lector de plugin que no encaje con su copia concreta.

### El test que lo vigila

`test/static/manifest_check.rb` compara CADA manifest con el disco: en `core/` y en cada `games/<perfil>/`,
todo `**/*.rb` debe estar listado exactamente una vez, y toda entrada listada debe tener fichero. Cierra los
dos fallos que se han colado en releases: un lector nuevo que no se registró (no carga en ninguna parte) y
una entrada cuyo fichero se renombró (NameError en el arranque). Los perfiles necesitan la misma red que el
core: una entrada rota deja MEDIO cableado ese único juego, y todo lo demás sigue verde.

## Archivos de Configuración

### mkxp.json

```json
{
  "preloadScript": ["accessibility/preload_access.rb"]
}
```

`preloadScript` es un **array**. El instalador (`installer/install.ps1`) inserta
`"accessibility/preload_access.rb"` en él: si la clave ya existe, añade la entrada dentro del array
existente; si no, crea la clave. Ese es el único cambio que hace en el `mkxp.json` del juego; el resto de
claves (RTP, soundfont...) son del juego y no se tocan.

> El preload es `preload_access.rb`, NO `boot.rb`: boot no puede ser el `preloadScript` porque corre antes
> de que existan las clases del juego.

### accessibility/data/loader_error.txt

Errores de carga y los diagnósticos del arranque:

```
foundation/config.rb: NoMethodError: ...
[diag] PokeAccess::Data en modo emergencia: ningun provider de motor registrado (datos = id crudo)
```

### accessibility/data/preload_started.txt

```
preload ok ruby=1.8.7
```

## eval() con TOPLEVEL_BINDING

Todo el mod se carga con `eval(File.read(path), TOPLEVEL_BINDING, path)`. `TOPLEVEL_BINDING` es el contexto
global: sin él, el código evaluado no vería `PokeAccess`. El tercer argumento es el nombre de fichero que
aparecerá en los backtraces, lo que hace que un error apunte al archivo real y no a `(eval)`. Ver
[08_RUBY_FUNDAMENTALS.md](08_RUBY_FUNDAMENTALS.md).

`eval` aquí es deliberado y seguro: son ficheros PROPIOS del mod, en una carpeta local fija, cargados
igual que RGSS ejecuta cualquier script del juego.

> **Resolución de clases 1.8.7-safe**: durante y tras la carga, el código nunca llama `Object.const_defined?`
> sobre un nombre con `"::"` (en Ruby 1.8.7, el de gen-6, eso lanza un error). Todo pasa por
> `PokeAccess.const_at("A::B::C")` (`core/foundation/const.rb`), que recorre los segmentos uno a uno. Lo
> usan `Hooks`, el escaneo de `Input`, `Menus` y `Engine.has?`, así que un nombre de clase anidado nunca
> rompe el loader de gen-6.

## Recuperación de Errores

Dos decisiones, las dos por lo mismo: el mod jamás debe impedir jugar.

- **Un módulo que revienta no para el resto.** `load_module` captura, apunta en `loader_error.txt` con
  backtrace, y sigue con el siguiente. Si el fallo era crítico, la cascada aparece enseguida en el mismo log.
- **Si ni siquiera se puede escribir el log, se ignora en silencio.** `log` usa la carpeta de datos resuelta
  por `Paths` en cuanto está cargada (que puede ser AppData si el juego es de solo lectura) y cae a
  `accessibility/data` antes de eso.

## Diagnóstico: Entender la Carga

```bash
# ¿Corrió el preload?
$ cat accessibility/data/preload_started.txt
preload ok ruby=1.8.7

# ¿Falló algo al cargar?
$ cat accessibility/data/loader_error.txt
```

Y en vivo, Ctrl+Alt+F9 vuelca `accessibility/data/diag.txt`, cuya primera línea ya dice qué motor, qué
capacidades y qué voz se detectaron. Ver [03_ENGINE_DETECTION.md](03_ENGINE_DETECTION.md).

## Referencias

- [Boot Script](../loader/boot.rb)
- [Preload Script](../loader/preload_access.rb)
- [Native Loader](../loader/Loader.rb) - Fallback para RMXP sin mkxp-z: se inyecta en `Scripts.rxdata` justo
  antes de "Main" y solo evalúa `boot.rb`. Requiere que el juego traiga un Ruby 1.8.7+
- [Core Manifest](../core/manifest.rb)

## Próximo

- [Dependencies Tree](11_DEPENDENCIES_TREE.md) - Qué depende de qué
- [Ruby Fundamentals](08_RUBY_FUNDAMENTALS.md) - Conceptos necesarios
