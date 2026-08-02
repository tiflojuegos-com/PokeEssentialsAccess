# Quick Start — Resumen en 5 minutos

¿Prisa? Esto es lo esencial.

## ¿Qué es PokeEssentialsAccess?

Un mod que hace jugables con lector de pantalla los fangames de Pokémon hechos sobre **Pokémon Essentials** y ejecutados con **mkxp-z**. Añade lectura de textos (menús, diálogos, combate), navegación por sonido 3D, búsqueda de rutas con guía sonora, glosario de sonidos, grabador de sesiones y remapeo de teclas.

Si lo que quieres es **jugar**, ve al [README](../README.md): instalación, juegos soportados y teclas. Este documento explica el código.

## Cómo se carga

```
mkxp-z arranca y ejecuta loader/preload_access.rb (declarado en mkxp.json)
  ↓
El preload envuelve Graphics.update y espera a que el juego esté vivo
  ↓
Evalúa boot.rb, que carga en orden:
  ├─ core/    (por core/manifest.rb)
  ├─ game/    (el perfil de games/<juego> que copió el instalador)
  └─ los ajustes del jugador, encima de todo
```

Nada del juego se modifica: los scripts originales se quedan como están y el mod se puede desinstalar.

## Las cuatro ideas del código

### 1. Enganches (hooks)

En vez de editar los métodos de Essentials, se envuelven:

```ruby
# core/battle/gen6/battle_g6.rb
PokeAccess::Hooks.before_hook("PokeBattle_Scene", :pbDisplayPausedMessage) do |_s, args|
  PokeAccess.speak_clean(args[0], false)   # false = encolar, no cortar la voz
end
```

Si la clase o el método no existen en ese juego, el enganche simplemente no se registra. Ver [04_PATCHING_AND_HOOKS](04_PATCHING_AND_HOOKS.md).

### 2. Providers de datos

Un mismo método sirve en cualquier versión de Essentials:

```ruby
PokeAccess::Data.species_name(25)   # "Pikachu"
```

Cada era registra su provider (gen-6 lee las tablas `PB*`, la era GameData lee `GameData::*`) y gana el de mayor prioridad; hay un fallback que devuelve el id crudo, así que nunca falta provider. Ver [05_DATA_API](05_DATA_API.md).

### 3. Puertas por capacidad, no por versión

Los fangames mezclan eras (v18 con backports, forks que adelantan la UI de v22). Por eso el código no pregunta "¿qué versión es?" sino "¿existe esto?":

```ruby
PokeAccess::Engine.has?("Battle::Scene")                        # ¿existe la clase?
PokeAccess::Engine.has?("Battle::Scene::MenuBase#setIndexAndMode")  # ¿clase y método?
```

Ver [03_ENGINE_DETECTION](03_ENGINE_DETECTION.md).

### 4. Manifests, no globs

Cada carpeta cargable tiene su `manifest.rb`: una lista ordenada de módulos. El orden es el de dependencias, no el del sistema de archivos. Ver [09_LOADING_SYSTEM](09_LOADING_SYSTEM.md).

## La regla que más se incumple: Ruby 1.8.7

`core/` se carga en los dos motores, y los juegos gen-6 corren sobre **Ruby 1.8.7**. Ahí no existen `&:simbolo`, `->`, `.clamp`, `.dig`, `<<~`, `each_with_object`, `&.` ni encadenar poniendo el punto al principio de la línea. Escribir cualquiera de esas cosas en un fichero dual rompe la carga entera de esos juegos.

Lo verifica `ruby test/run_all.rb`. Antes de tocar código, lee [08_RUBY_FUNDAMENTALS](08_RUBY_FUNDAMENTALS.md).

## Dónde está cada cosa

| Qué | Dónde |
|-----|-------|
| Configuración y esquema de opciones | `core/foundation/config.rb` |
| Detección de motor y capacidades | `core/foundation/engine.rb` |
| Enganches | `core/input/hooks.rb` |
| Teclas del mod | `core/input/input.rb`, `keyboard.rb`, `focus.rb` |
| Diagnóstico | `core/input/diag.rb` |
| Voz | `core/speech/speech.rb` |
| Textos traducidos | `core/foundation/i18n.rb` + `lang/*.txt` |
| Datos agnósticos | `core/data/data.rb` (+ `gen6/`, `v21/`) |
| Rutas | `core/nav/pathfinder.rb` |
| Objetivos del mapa | `core/nav/locator.rb` |
| Audio 3D | `core/audio/audio3d.rb`, `spatial.rb` |
| Glosario de sonidos | `core/audio/glossary.rb` |
| Menú del mod | `core/menus/config_menu.rb` |
| Grabador de sesiones | `core/util/recorder.rb` |
| Lectores por juego | `games/<juego>/` |

## Métodos más usados

```ruby
# Hablar
PokeAccess.speak("Hola")                  # corta lo que se esté diciendo
PokeAccess.speak_clean(texto_del_juego)   # limpia los códigos \V[n], \C[n]... y habla
PokeAccess::I18n.t(:mod_on)               # texto traducido de lang/*.txt

# Datos (en cualquier versión)
PokeAccess::Data.species_name(25)         # "Pikachu"

# Motor
PokeAccess::Engine.kind                   # :gamedata o :gen6
PokeAccess::Engine.version                # 21.1 (solo para el diagnóstico)

# Ruta hasta una casilla contigua al objetivo
PokeAccess::Pathfinder.find_path(10, 10)

# Objetivos del mapa
PokeAccess::Locator.rebuild_targets
PokeAccess::Locator.announce_selected(true)   # true = decir también el nombre

# Configuración
PokeAccess::Config.audio3d_volume = 80
```

Lista completa en [10_API_REFERENCE](10_API_REFERENCE.md).

## Si algo falla

Dentro del juego:

- `Ctrl`+`Alt`+`F10` habla un diagnóstico corto: escena actual, mapa y posición, última línea leída y enganches que no encontraron su método.
- `Ctrl`+`Alt`+`F9` vuelca el diagnóstico completo a `accessibility/data/diag.txt`.

En la carpeta `accessibility/data/` del juego:

- `preload_started.txt` — existe si mkxp-z llegó a ejecutar el preload.
- `loader_error.txt` — errores de carga de cada módulo.
- `diag.txt` — los volcados de `Ctrl`+`Alt`+`F9`.

## Siguiente paso

- **Quiero entender el proyecto**: [01_INTRODUCTION](01_INTRODUCTION.md).
- **Voy a escribir código**: [08_RUBY_FUNDAMENTALS](08_RUBY_FUNDAMENTALS.md) → [02_ARCHITECTURE](02_ARCHITECTURE.md) → [14_EXTENDING](14_EXTENDING.md).
- **Busco algo concreto**: [12_INDEX](12_INDEX.md).
- **Quiero una ruta de lectura**: [13_READING_GUIDE](13_READING_GUIDE.md).
