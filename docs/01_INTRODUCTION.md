# Introducción

**PokeEssentialsAccess** es un mod de accesibilidad para fangames de Pokémon: hace jugable con lector de pantalla lo que hasta ahora era un juego enteramente visual. Está escrito en Ruby y se carga dentro del propio juego, sin modificar sus scripts.

Funciona sobre fangames hechos con **Pokémon Essentials** y ejecutados con **mkxp-z**, desde la era gen-6 (Essentials v16-v17) hasta v22 y sus forks. Hay 13 perfiles en `games/`: doce fangames concretos y uno genérico para el resto.

## Qué le da al jugador

- **Lectura de textos.** Diálogos, menús, combate, fichas de Pokémon, Pokédex, mochila, tarjeta de entrenador, minijuegos... La voz sale por **prism**, que habla con NVDA, JAWS, SAPI, UIA, ZDSR y otros lectores, y también envía a la línea braille.
- **Navegación con sonar 3D.** Un sonido binaural (Steam Audio, HRTF) sitúa a su alrededor personas, objetos, puertas, teletransportes, controles de puzzle, agua y paredes: la posición se oye, no se describe. Los pasos, los choques y la cercanía tienen sus propias señales.
- **Guía por ruta.** El jugador elige un objetivo de la lista del mapa (personas, objetos, salidas, carteles...), el mod calcula la ruta con A* y lo guía con un sonido que se desplaza hacia el siguiente paso.
- **Lectura de menús y combate.** Cada movimiento del cursor dice qué hay bajo él; en combate se leen los mensajes, los comandos, los movimientos con su tipo, potencia y PP, los PS de ambos equipos y el estado del terreno.
- **Glosario de sonidos.** Todas las señales del mod, en una lista que se puede recorrer: cada una se oye, se nombra y explica cuándo suena. Aprender el vocabulario deja de depender de encontrárselo en el campo.
- **Grabador de sesiones.** Guarda en un archivo lo que el mod vio y lo que dijo, en orden. Quien prueba el mod adjunta la grabación al reportar un fallo, en vez de intentar describir el momento en que se quedó callado.
- **Remapeo de teclas** del juego y **puzzles accesibilizados** juego a juego (hoy, Pokémon Z y Pokémon Ópalo).

Las teclas y la instalación están en el [README](../README.md); las opciones que el jugador puede ajustar, en [16_CONFIG_MENU](16_CONFIG_MENU.md).

## Sobre qué se apoya

### mkxp-z

**mkxp-z** es un intérprete libre y multiplataforma de **RGSS**, el sistema de scripting de RPG Maker XP, y es lo que ejecuta hoy la mayoría de fangames de Essentials. Al mod le importan tres cosas de él:

1. Admite un **preload script**: código Ruby que corre antes que los scripts del juego. Esa es la vía por la que entra el mod, y se declara en el `mkxp.json` del juego.
2. Da acceso a **Win32API**, necesario para hablar con el lector de pantalla, con la biblioteca de audio 3D y con el teclado físico.
3. No hace falta tocar `Scripts.rxdata`, así que la instalación es reversible.

Un build de mkxp-z puede estar compilado sin soporte de `preloadScript`; el instalador lo comprueba antes de copiar nada.

### Pokémon Essentials

**Pokémon Essentials** es el framework sobre el que se hacen los fangames: sistema de combate, Pokédex, mochila, equipo, mapas. Ha cambiado mucho entre versiones, y el mod tiene que convivir con todas:

- **Era gen-6 (v16-v17)**: clases `PokeBattle_Scene`, `PScreen_*`, datos en tablas `PB*`. Corre sobre **Ruby 1.8.7**.
- **Era GameData (v18+)**: los datos pasan a `GameData::*`. Ruby moderno.
- **v19-v21.1**: aparece `Battle::Scene` y el resto de la estructura moderna.
- **v22**: reescritura de la interfaz con clases `UI::*`.
- **Forks**: por ejemplo el de La Base de Sky, que trae la UI de v22 sobre una base v21.1.

Y los fangames reales mezclan: hay juegos v18 con backports, y forks que adelantan partes de una versión posterior.

## Las ideas que sostienen el diseño

### 1. No se modifica el juego

Los archivos del mod van a una carpeta `accessibility/` dentro del juego, y `mkxp.json` declara el preload. En tiempo de ejecución el mod **envuelve** los métodos de Essentials en vez de reescribirlos, a través de la semi-API `PokeAccess::Hooks` (`core/input/hooks.rb`): `before_hook`, `after_hook`, `around_hook`, `frame_hook`, `wrap_global` y `wrap_kernel`, con guarda de reentrancia y errores tragados, para que un fallo del mod nunca tumbe la partida.

Consecuencias: el juego original queda intacto, el mod se puede quitar, y una pantalla nueva se accesibiliza añadiendo un enganche, no editando código ajeno. Ver [04_PATCHING_AND_HOOKS](04_PATCHING_AND_HOOKS.md).

### 2. Se pregunta por capacidades, no por versiones

Como las versiones se mezclan, el código nunca decide por número de versión: pregunta si la clase o el método existen (`PokeAccess::Engine.has?`). Un enganche cuya clase no está presente simplemente no se registra, y el módulo queda inerte en ese juego. Ver [03_ENGINE_DETECTION](03_ENGINE_DETECTION.md).

### 3. Los datos se piden a un provider

Los lectores llaman a `PokeAccess::Data.species_name(id)` y no saben en qué era corren. Cada era registra su provider con una prioridad; el más alto presente sirve, y un fallback de última hora devuelve el id crudo para que nunca falte respuesta. Ver [05_DATA_API](05_DATA_API.md).

### 4. La carga es una lista, no un glob

Cada carpeta cargable tiene su `manifest.rb`: un array ordenado de módulos que el boot evalúa uno a uno. El orden es el de dependencias y se edita a mano; ningún módulo depende de cómo ordene el sistema de archivos. Ver [09_LOADING_SYSTEM](09_LOADING_SYSTEM.md).

### 5. Nada de texto hablado a pelo

Todo lo que dice el mod sale de las tablas `lang/es.txt` y `lang/en.txt` a través de `PokeAccess::I18n.t`. Lo que viene del propio juego se limpia de códigos de control antes de hablarlo. Ver [15_SPEECH_AND_I18N](15_SPEECH_AND_I18N.md).

## Capas

```
┌──────────────────────────────────────────────┐
│ Perfil del juego (games/<juego>)             │  Lectores y constantes de ese fangame
├──────────────────────────────────────────────┤
│ Adaptadores por era (core/<mod>/gen6|v21|     │  Se activan solo si su clase existe
│ v22|skyflyer)                                │
├──────────────────────────────────────────────┤
│ Core compartido (core/<mod>/)                │  Lógica universal: voz, datos, nav, audio
├──────────────────────────────────────────────┤
│ Pokémon Essentials + mkxp-z                  │  El juego, sin tocar
└──────────────────────────────────────────────┘
```

Detalle en [02_ARCHITECTURE](02_ARCHITECTURE.md).

## Antes de escribir código

`core/` se carga en los dos motores y los juegos gen-6 corren sobre **Ruby 1.8.7**: hay sintaxis moderna que no puedes usar en los ficheros duales, y usarla rompe la carga entera de esos juegos. Está explicado, con la red que lo verifica, en [08_RUBY_FUNDAMENTALS](08_RUBY_FUNDAMENTALS.md). Empieza por ahí.

## Siguiente

- [02_ARCHITECTURE](02_ARCHITECTURE.md) — las capas en detalle.
- [08_RUBY_FUNDAMENTALS](08_RUBY_FUNDAMENTALS.md) — el Ruby que hace falta, y la restricción 1.8.7.
- [14_EXTENDING](14_EXTENDING.md) — añadir lectores, puzzles y perfiles.
- [13_READING_GUIDE](13_READING_GUIDE.md) — rutas de lectura según lo que quieras hacer.
