# Detección de Engine

## El Problema

Pokemon Essentials existe en múltiples versiones con APIs completamente diferentes:

| Versión | Era (por su API de datos) | Clases Batalla | Datos | Problemas |
|---------|-----|---|---|---|
| v16-v17 | gen-6 (2015) | `PokeBattle_Scene` | Constantes `PB*` | No existe `GameData` |
| v18 | GameData (transicional) | `PokeBattle_Scene` | `GameData::*` | `GameData` ya, pero `$Trainer` todavía |
| v19-v21.1 | GameData (2019+) | `Battle::Scene` | `GameData::*` | Estructura completamente nueva |
| v22 | GameData + UI rework (2023+) | `Battle::Scene` | `GameData::*` | `UI::*` reemplaza windows |
| Sky Fork | v21 + v22 UI | Mixta | `GameData::*` | Backport de v22 UI a v21 |

> **Nomenclatura**: las dos grandes eras se nombran por **la API de datos** que usan (`gen6` = tablas
> `PB*`, `gamedata` = la capa `GameData`), no por "viejo/moderno": "moderno" envejece y un día mentiría,
> mientras que "usa GameData" es verdad permanente.

**Solución**: detección en tiempo de ejecución **por capacidad** (¿existe la clase/feature?), no por número
de versión, + selección de adaptadores.

## Módulo Engine

**Ubicación**: `core/foundation/engine.rb`

### Era: gamedata? / gen6? / kind

```ruby
module PokeAccess::Engine
  # ¿Existe GameData::Species? → usa la API GameData
  def self.gamedata?
    (defined?(GameData) && defined?(GameData::Species)) ? true : false
  end

  def self.gen6?; !gamedata?; end          # sin GameData → es gen-6

  def self.kind; gamedata? ? :gamedata : :gen6; end
end
```

`defined?()` devuelve nil si la constante no existe: gen-6 no tiene `GameData`, la era GameData siempre
tiene `GameData::Species`.

### version: SOLO para diagnóstico

```ruby
def self.version
  return @version if defined?(@version) && @version
  ev = (defined?(Essentials) && (Essentials::VERSION rescue nil)) ||
       (defined?(ESSENTIALS_VERSION) && (ESSENTIALS_VERSION rescue nil))
  @version = if ev then ev.to_s[/\d+(\.\d+)?/].to_f
             elsif gamedata? then (PokeAccess.const_at("Battle::Scene") ? 19.0 : 18.0)
             elsif defined?(ESSENTIALSVERSION) then (v = ESSENTIALSVERSION.to_s[/\d+(\.\d+)?/].to_f; v < 1 ? 17.0 : v)
             else 16.0
             end
end
```

Los fangames reales MEZCLAN eras (v18 con backports, Sky es v21.1 con la UI de v22), así que ningún lector
gatea por este número: es la línea del diag y nada más. Cuando falta la constante de versión, la era se
deduce por ESTRUCTURA y no por un global de runtime (en la pantalla de título el jugador aún no existe, y
el valor se memoiza): v19 renombró la escena de batalla a `Battle::Scene`, así que su ausencia con
`GameData` presente significa la era transicional v18.

### fork

```ruby
def self.fork
  return @fork if defined?(@fork)
  @fork = (gamedata? && version < 21.9 && defined?(UI) && defined?(UI::BaseScreen)) ? :sky : nil
end
```

### has?: el gate por capacidad (canal ÚNICO)

El gateo NO es por número de versión sino por **capacidad**: ¿existe la clase/método que el lector
necesita? Así un fork que backportea una feature (o una versión futura que la conserva) se activa sin
tocar el código. `Engine.has?` es el único punto para preguntarlo, y acepta tres formas:

| Forma | Ejemplo | Qué comprueba |
|-------|---------|---------------|
| Símbolo registrado | `Engine.has?(:ui_rework)` | Una capacidad de `Engine::CAPABILITIES` |
| `"A::B::C"` | `Engine.has?("UI::BagVisuals")` | Que la constante exista (vía `PokeAccess.const_at`) |
| `"Clase#metodo"` | `Engine.has?("Battle::Scene::MenuBase#setIndexAndMode")` | Constante **y** método de instancia |

```ruby
CAPABILITIES = {
  :gamedata     => lambda { gamedata? },
  :gen6         => lambda { gen6? },
  :sky_fork     => lambda { fork == :sky },
  :ui_rework    => "UI::BaseScreen",   # el rework UI:: de v22
  :battle_scene => "Battle::Scene"     # la escena de batalla v19+
}
```

Un probe es un lambda booleano o un nombre de constante; las transversales se registran aquí y una
pantalla puntual pasa su nombre de clase directamente. Si v23 renombra una clase, basta actualizar su
entrada en `CAPABILITIES` (un sitio) y todos los lectores que dependían de esa capacidad siguen
funcionando. La carpeta `vNN/` solo dice DÓNDE se introdujo una capacidad; la activación siempre es por
`has?`.

> **No hay un segundo predicado de existencia.** `PokeAccess.const_at("A::B::C")`
> (`core/foundation/const.rb`) resuelve la constante EN SÍ, recorriendo los segmentos uno a uno para no
> romper en Ruby 1.8.7 (donde `const_defined?` rechaza un nombre con `"::"`). Para el booleano "¿existe?"
> la puerta es `has?`, y solo esa: una forma obvia de preguntarlo.

### player

```ruby
def self.player
  (defined?($player) && $player) ? $player : (defined?($Trainer) ? $Trainer : nil)
end

name = PokeAccess::Engine.player.name  # funciona en ambas eras
```

`has?` y `player` son, de hecho, lo único que los lectores llaman de `Engine`: `kind`, `version` y `fork`
solo los consumen el diagnóstico y la cabecera del grabador de sesiones.

## Cómo se Usa en el Sistema

### Ejemplo 1: Battle System

```
core/battle/
├── battle.rb            ← Lógica compartida
├── scene_reader.rb      ← Lectura agnóstica de Battle::Scene::* (v19-v22)
├── gen6/battle_g6.rb    ← Hooks para PokeBattle_Scene
└── v21/battle_v21.rb    ← Disparadores para Battle::Scene
```

El manifest carga los dos; cada uno se ata solo donde su clase existe:

```ruby
# battle_g6.rb -- PokeBattle_Scene solo existe en gen-6; NO-OP en la era GameData
PokeAccess::Hooks.before_hook("PokeBattle_Scene", :pbDisplayMessage) do |scene, args|
  PokeAccess.speak_clean(args[0], false)
end

# battle_v21.rb -- Battle::Scene solo existe en la era GameData; NO-OP en gen-6.
# El disparador vive aquí; el CONTENIDO lo lee el módulo agnóstico.
PokeAccess::Hooks.after_hook("Battle::Scene::MenuBase", :index=) do |menu, _r, _a|
  PokeAccess::BattleScene.read_menu(menu)
end
```

### Ejemplo 2: Data System

```ruby
# core/data/gen6/data_g6.rb -- MÓDULO; prioridad 10
module PokeAccess::DataG6
  def self.species_name(id); PBSpecies.getName(id) rescue nil; end
end
PokeAccess::Data.register(10, PokeAccess::DataG6) if defined?(PBMoves) && !defined?(GameData)

# core/data/v21/data_v21.rb -- MÓDULO; prioridad 20
module PokeAccess::DataV21
  def self.species_name(id); (GameData::Species.get(id).name rescue nil); end
end
PokeAccess::Data.register(20, PokeAccess::DataV21) if defined?(GameData) && defined?(GameData::Move)

PokeAccess::Data.species_name(123)  # usa el provider activo, sea cual sea
```

## Casos Especiales

### Sky Fork

**¿Qué es Sky?** Un fork de v21.1 que backportea la UI de v22: tiene a la vez `GameData` (era GameData) y
`UI::` (v22), más los plugins que trae empaquetados (DBK, el tutor de movimientos huevo). Se detecta con
`Engine.fork` (arriba) y sus lectores viven en `<módulo>/skyflyer/`, cada uno gateado por la clase o el
método del plugin que cubre.

### Deluxe Battle Kit (DBK)

No es una versión de Essentials sino un plugin: extiende `Battle::Scene` con más métodos y añade campos al
menú de batalla. Se gatea por capacidad (clase + método), así que se activa también en un fork que lo
backportee:

```ruby
# Ojo: pbToggleSpecialActions vive en Battle (no en Battle::Scene).
if PokeAccess::Engine.has?("Battle#pbToggleSpecialActions")
  # los archivos core/battle/skyflyer/dbk_* ya hacen este gate
end
```

## Diagnóstico: Cómo Saber Qué Detectó

### Ctrl+Alt+F9 — volcado a archivo

Genera/anexa `accessibility/data/diag.txt`. Su sección de motor dice literalmente qué cree el mod que está
corriendo y, sobre todo, qué CAPACIDADES ve (que es por lo que se atan los lectores):

```
engine: kind=:gamedata version=21.1 fork=:sky caps=[battle_scene, ui_rework, $player]
voice: prism=true ready=true backend="NVDA" speaking=false
scene=Battle::Scene              ← clase de la escena actual
in_menu=true
```

### Ctrl+Alt+F10 — diagnóstico HABLADO

A diferencia de F9 (vuelca a archivo, que un usuario con lector de pantalla tendría que abrir), **F10
habla** el estado esencial al instante: escena activa, mapa y posición (en el campo), última línea hablada,
y el número de hooks que no engancharon. Es la respuesta rápida a "se quedó mudo, ¿por qué?".

### Lectura Manual en Código

```ruby
puts PokeAccess::Engine.kind              # :gamedata
puts PokeAccess::Engine.version           # 21.1  (informativo: nunca gatees con esto)
puts PokeAccess::Engine.fork              # nil
puts PokeAccess::Engine.has?(:ui_rework)  # false en v21 vanilla, true en v22/Sky
```

## Árbol de Decisión

```
¿Existe GameData::Species?
├─ Sí → USA LA API GAMEDATA
│  ├─ ¿Existe Battle::Scene?
│  │  ├─ No → v18 (transicional: GameData con PokeBattle_Scene y $Trainer)
│  │  └─ Sí → v19+
│  │     └─ ¿Versión < 21.9 Y existe UI::BaseScreen? → ES SKY FORK
│  └─ ¿Existe UI::BaseScreen con versión >= 21.9? → v22 (rework UI::)
└─ No → ES GEN-6
   └─ ¿Existe ESSENTIALSVERSION?
      ├─ Sí → Parsear versión
      └─ No → Asumir v16
```

## Referencias

- [Engine Module](../core/foundation/engine.rb) - `has?`, `CAPABILITIES`, `player`
- [const.rb](../core/foundation/const.rb) - `const_at`, la resolución 1.8.7-safe en la que se apoya `has?`
- [Data Providers](../core/data/) - Ejemplos de adaptadores
- [Battle Versions](../core/battle/) - Disparadores por versión sobre un lector agnóstico

## Próximo

- [Patching & Hooks](04_PATCHING_AND_HOOKS.md) - Cómo se engancha el código
- [Data API](05_DATA_API.md) - Sistema de acceso a datos
