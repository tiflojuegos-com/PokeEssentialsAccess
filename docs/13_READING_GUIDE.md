# Guía de lectura

Qué leer según lo que quieras hacer. Si buscas algo concreto (un módulo, un método, un término), ve al [12_INDEX](12_INDEX.md).

## Según tu papel

### Juego con el mod

Lo tuyo está fuera de `docs/`: el [README](../README.md) tiene la instalación, los juegos soportados y las teclas. Luego, [16_CONFIG_MENU](16_CONFIG_MENU.md) explica cada opción del menú del mod (tecla `O`), incluido el glosario de sonidos.

### Hago un fangame y quiero que sea accesible

1. [01_INTRODUCTION](01_INTRODUCTION.md) — qué hace el mod y sobre qué se apoya.
2. [02_ARCHITECTURE](02_ARCHITECTURE.md) — dónde encaja lo tuyo.
3. [08_RUBY_FUNDAMENTALS](08_RUBY_FUNDAMENTALS.md) §1 — si tu juego es gen-6, esto no es opcional.
4. [14_EXTENDING](14_EXTENDING.md) — crear `games/<tujuego>/` y escribir lectores.
5. [15_SPEECH_AND_I18N](15_SPEECH_AND_I18N.md) — hablar y traducir bien.

### Quiero contribuir al mod

**Primero:**

1. [01_INTRODUCTION](01_INTRODUCTION.md)
2. [08_RUBY_FUNDAMENTALS](08_RUBY_FUNDAMENTALS.md) — entero, y con calma la §1
3. [09_LOADING_SYSTEM](09_LOADING_SYSTEM.md)
4. [02_ARCHITECTURE](02_ARCHITECTURE.md)

**Después, según a qué le vayas a meter mano:**

5. [03_ENGINE_DETECTION](03_ENGINE_DETECTION.md) y [04_PATCHING_AND_HOOKS](04_PATCHING_AND_HOOKS.md) — para cualquier lector.
6. [05_DATA_API](05_DATA_API.md) — si tocas datos del juego.
7. [06_PATHFINDING](06_PATHFINDING.md) y [07_AUDIO3D](07_AUDIO3D.md) — navegación y sonido.
8. [15_SPEECH_AND_I18N](15_SPEECH_AND_I18N.md) — voz y traducción.
9. [10_API_REFERENCE](10_API_REFERENCE.md) y [11_DEPENDENCIES_TREE](11_DEPENDENCIES_TREE.md) — como referencia, cuando hagan falta.

## Según la tarea

### Dar voz a una pantalla que está muda

1. [14_EXTENDING](14_EXTENDING.md) §0 y §2 — el flujo completo y el caso más común.
2. [14_EXTENDING](14_EXTENDING.md) §8 — cómo averiguar qué clase y qué método hay detrás de esa pantalla (`Ctrl`+`Alt`+`F9`).
3. [15_SPEECH_AND_I18N](15_SPEECH_AND_I18N.md) — decidir entre una clave i18n y un texto del juego.
4. Si la DSL no basta: [04_PATCHING_AND_HOOKS](04_PATCHING_AND_HOOKS.md).

### Añadir un perfil de juego nuevo

1. [14_EXTENDING](14_EXTENDING.md) §5.
2. [03_ENGINE_DETECTION](03_ENGINE_DETECTION.md) — saber en qué era corre.
3. `games/catalog.json` — declarar cómo se reconoce el juego.
4. [08_RUBY_FUNDAMENTALS](08_RUBY_FUNDAMENTALS.md) §1 — si es gen-6, el perfil entero es código 1.8.7.

### Accesibilizar un puzzle

1. [14_EXTENDING](14_EXTENDING.md) §4.
2. `core/puzzles/puzzles.rb` y, como ejemplos completos, `games/pokemon_z/puzzles.rb` y `games/opalo/puzzles.rb`.

### Añadir una opción al menú del mod

1. [16_CONFIG_MENU](16_CONFIG_MENU.md) §2 — una opción es una fila en `Config::SCHEMA`.
2. Las etiquetas y la ayuda son claves i18n: [15_SPEECH_AND_I18N](15_SPEECH_AND_I18N.md).

### Soportar una versión de Essentials nueva

1. [03_ENGINE_DETECTION](03_ENGINE_DETECTION.md) — y sobre todo: se activa por capacidad, no por número de versión.
2. [02_ARCHITECTURE](02_ARCHITECTURE.md) — dónde va una carpeta por era.
3. [09_LOADING_SYSTEM](09_LOADING_SYSTEM.md) — añadirla al manifest.
4. Si la carpeta solo la cargan juegos modernos, métela en la lista `MODERN` de `test/check187.py` **y** de `test/check187_real.rb`.

### Diagnosticar que el mod se ha quedado callado

1. En el juego: `Ctrl`+`Alt`+`F10` (diagnóstico hablado) y `Ctrl`+`Alt`+`F9` (volcado completo).
2. En `accessibility/data/`: `preload_started.txt`, `loader_error.txt` y `diag.txt`.
3. [09_LOADING_SYSTEM](09_LOADING_SYSTEM.md) — si falló la carga.
4. [08_RUBY_FUNDAMENTALS](08_RUBY_FUNDAMENTALS.md) §1 — si el juego es gen-6 y el módulo mudo desapareció entero, sospecha de sintaxis moderna en un archivo dual.
5. Para reproducirlo con alguien: activa el grabador de sesiones desde el menú del mod y comparte el archivo.

## Según el tiempo que tengas

- **5 minutos** → [00_QUICK_START](00_QUICK_START.md).
- **Media hora** → [00_QUICK_START](00_QUICK_START.md) + [01_INTRODUCTION](01_INTRODUCTION.md).
- **Una tarde** → añade [08_RUBY_FUNDAMENTALS](08_RUBY_FUNDAMENTALS.md), [02_ARCHITECTURE](02_ARCHITECTURE.md) y [14_EXTENDING](14_EXTENDING.md): con eso ya puedes escribir un lector.
- **Todo** → la ruta de contributor de arriba, en dos o tres sesiones, con el editor abierto al lado.

## Comprobaciones antes de mandar un cambio

- `ruby test/run_all.rb` pasa (incluye las comprobaciones de Ruby 1.8.7, los manifests y la paridad de idiomas).
- Si has añadido texto hablado, está en `lang/es.txt` **y** en `lang/en.txt`.
- Si has añadido un módulo, está en el `manifest.rb` de su carpeta, en su sitio del orden de dependencias.
- Si has tocado código dual, no has metido sintaxis de Ruby 1.9+.

## Volver

- [_index](_index.md) — el catálogo de la documentación.
- [12_INDEX](12_INDEX.md) — búsqueda por tema, módulo o término.
