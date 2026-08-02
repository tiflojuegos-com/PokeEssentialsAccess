# Documentación de PokeEssentialsAccess

Bienvenido. Aquí está explicado el mod por dentro: cómo se carga, cómo engancha con el juego, cómo habla y cómo se extiende.

Si lo que buscas es **instalarlo y jugar**, eso está en el [README](../README.md): instalación, juegos soportados y teclas.

## Por dónde empezar

| Quiero... | Lee |
|-----------|-----|
| Hacerme una idea en cinco minutos | [00_QUICK_START](00_QUICK_START.md) |
| Entender qué es el proyecto y por qué está hecho así | [01_INTRODUCTION](01_INTRODUCTION.md) |
| **Escribir código** | [08_RUBY_FUNDAMENTALS](08_RUBY_FUNDAMENTALS.md) primero, sin excepción |
| Añadir accesibilidad a una pantalla o a un juego nuevo | [14_EXTENDING](14_EXTENDING.md) |
| Buscar un módulo, un método o un término concreto | [12_INDEX](12_INDEX.md) |
| Una ruta de lectura hecha a medida | [13_READING_GUIDE](13_READING_GUIDE.md) |

> **Aviso antes de tocar nada:** parte del mod corre sobre **Ruby 1.8.7** y ahí no vale la sintaxis moderna. Está explicado, con la red de tests que lo verifica, en [08_RUBY_FUNDAMENTALS](08_RUBY_FUNDAMENTALS.md) §1.

## Los documentos

### Empezar

- [00_QUICK_START](00_QUICK_START.md) — lo esencial: cómo se carga, las cuatro ideas del diseño, dónde está cada cosa.
- [01_INTRODUCTION](01_INTRODUCTION.md) — qué hace el mod por el jugador, sobre qué se apoya y qué decisiones lo estructuran.
- [08_RUBY_FUNDAMENTALS](08_RUBY_FUNDAMENTALS.md) — el Ruby que hace falta y la restricción de 1.8.7.

### Cómo está construido

- [02_ARCHITECTURE](02_ARCHITECTURE.md) — las capas, el flujo de ejecución y los patrones que se repiten.
- [03_ENGINE_DETECTION](03_ENGINE_DETECTION.md) — convivir con todas las versiones de Essentials sin ramificar por número de versión.
- [09_LOADING_SYSTEM](09_LOADING_SYSTEM.md) — preload, boot y manifests.
- [11_DEPENDENCIES_TREE](11_DEPENDENCIES_TREE.md) — qué módulo depende de cuál y por qué el orden importa.

### Los sistemas

- [04_PATCHING_AND_HOOKS](04_PATCHING_AND_HOOKS.md) — `PokeAccess::Hooks`: envolver métodos del juego sin editarlos.
- [05_DATA_API](05_DATA_API.md) — pedir datos del juego sin saber en qué era corres.
- [06_PATHFINDING](06_PATHFINDING.md) — búsqueda de rutas: A*, HPA*, ledges, cachés.
- [07_AUDIO3D](07_AUDIO3D.md) — el sonar posicional: Steam Audio, emisores, oclusión.
- [15_SPEECH_AND_I18N](15_SPEECH_AND_I18N.md) — hablar, limpiar texto del juego y traducir.

### Usar y extender

- [14_EXTENDING](14_EXTENDING.md) — añadir lectores, puzzles y perfiles de juego, paso a paso.
- [16_CONFIG_MENU](16_CONFIG_MENU.md) — el menú hablado del mod y sus opciones.
- [10_API_REFERENCE](10_API_REFERENCE.md) — los métodos públicos, por módulo.

### Índices

- [12_INDEX](12_INDEX.md) — búsqueda por tema, por módulo del código y por término.
- [13_READING_GUIDE](13_READING_GUIDE.md) — rutas de lectura por rol y por tarea.

## Cómo está escrita

- **En español**, y pensada para leerse de forma lineal con lector de pantalla: sin tablas anchas, sin arte ASCII que no aporte y con los enlaces nombrados por lo que son.
- **Los ejemplos son código real** del proyecto, con la ruta del archivo del que salen. Si un ejemplo y el código discrepan, manda el código: avísalo o corrígelo.
- **Se describe lo que hay**, no lo que hubo. La documentación no lleva historial; los cambios están en las releases del repositorio.

Las contribuciones a la documentación son bienvenidas, igual que las de código.
