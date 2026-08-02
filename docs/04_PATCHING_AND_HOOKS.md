# Patching & Hooks (Sistema de Enganches)

## Concepto Fundamental

**Hooking** es insertar código propio en métodos que ya existen, sin modificar los archivos del juego.
Interceptas la llamada para ejecutar lógica antes, después o en lugar del método original.

PokeEssentialsAccess **NO MODIFICA** los scripts de Essentials:

```
Essentials original          PokeAccess
└─ class PokeBattle_Scene    ├─ registra un middleware en memoria
   └─ def pbDisplayMessage   ├─ ejecuta PokeAccess.speak_clean(...)
      └─ mostrar ventana     └─ llama al método original
```

**Ventajas**: el juego queda intacto, varios enganches conviven sobre el mismo método, desinstalar es
borrar una carpeta, y el mismo código sirve para versiones distintas de Essentials.

---

## Los registradores

**Ubicación**: `core/input/hooks.rb`. Todo el módulo es 1.8.7-safe (los juegos gen-6 corren un Ruby
antiguo). `cname` es siempre un **string** con el nombre de la clase (`"Battle::Scene"`, resuelto
1.8.7-safe por `PokeAccess.const_at`) y `meth` un **símbolo**.

| Registrador | Firma | Yield | Para qué |
|---|---|---|---|
| `before_hook` | `(cname, meth, opts = {})` | `(instancia, args)` | Hablar ANTES de que el original bloquee |
| `after_hook` | `(cname, meth, opts = {})` | `(instancia, resultado, args)` | Leer el estado ya actualizado |
| `around_hook` | `(cname, meth, opts = {})` | `(instancia, call_next, args)` | Decidir si el original corre, o envolver un bucle |
| `frame_hook` | `(cname, meth)` | `(instancia, args)` | Driver por-frame (poller) |
| `read_on_open` | `(cname, meth = :pbStartScene, opts = {})` | `(escena) -> texto` | Resumen hablado al abrir una pantalla |
| `override` | `(target, meth, opts = {})` | `(receptor, original, args)` | REEMPLAZO declarado de un método |
| `wrap_global` | `(name, tag, timing = :after)` | `(args, x)` | Función top-level (de `Object`) |
| `wrap_kernel` | `(name, tag, timing = :before)` | `(args, x)` | Función que puede ser singleton de `Kernel` o top-level |
| `wrap` | `(cname, meth, opts = {})` | `(instancia, call_next, args)` | El motor: middleware crudo (los demás lo usan) |

**Gate por existencia, siempre.** `wrap` resuelve la clase antes de atar nada:

- **Clase ausente** → no-op silencioso (es variación normal entre juegos).
- **Método ausente sobre clase presente** → se anota en `Hooks.missing` (casi siempre un typo), salvo
  con `:optional`.
- Un método **privado** también se puede enganchar: `wrap` lo detecta y lo vuelve a privatizar tras
  redefinirlo.

No hace falta reimplementar esa comprobación en cada hook.

### Opciones (`opts`)

| Opción | Vale para | Efecto |
|---|---|---|
| `:optional => true` | `wrap`, `before_hook`, `after_hook`, `around_hook`, `read_on_open`, `override` | El método **falta legítimamente** en algunos juegos (una variante del plugin, un fork que lo renombró): el enganche se salta **en silencio** en vez de contar como typo en `Hooks.missing`. Así `missing` conserva su significado exacto: "este método DEBERÍA existir aquí y no está". |
| `:hook_container => true` | `after_hook` (y `read_on_open`, que lo pasa) | El método es un **contenedor**: un bucle modal o un abridor de escena que **delega el anuncio** en métodos hookeados que él mismo conduce. Su original corre **SIN la guarda de reentrancia**. |
| `:timing => :before` | `read_on_open` | Habla antes del abridor, para abridores que **bloquean** en su propio bucle. |
| `:tag => "..."` | `override` | Nombra al dueño del reemplazo en el listado del diagnóstico. |

```ruby
# core/battle/skyflyer/dbk_battlerinfo.rb -- solo existe con el Deluxe Battle Kit; en un juego sin DBK
# la clase Battle::Scene sí existe pero el método no, y eso NO es un typo.
PokeAccess::Hooks.after_hook("Battle::Scene", :pbUpdateBattlerInfo, :optional => true) do |scene, _ret, args|
  # ...
end
```

---

## Uso básico

### `before_hook` — hablar antes de que el original bloquee

```ruby
# core/battle/gen6/battle_g6.rb
PokeAccess::Hooks.before_hook("PokeBattle_Scene", :pbDisplayMessage) do |scene, args|
  PokeAccess::Battle.set_battle(scene.instance_variable_get(:@battle))
  PokeAccess.speak_clean(args[0], false)   # encolado: no cortar lo que suene
end
```

El cuerpo puede **mutar `args` in situ** para cambiar lo que recibe el original.

### `after_hook` — leer el estado ya actualizado

```ruby
# core/menus/neo_pausemenu.rb
PokeAccess::Hooks.after_hook("PokemonMenu_Scene", :update, :optional => true) do |scene, _r, _a|
  if defined?(MenuHandlers)
    PokeAccess::Menus.poll_sprite_menu(scene, :@entries, :neo_last) do |entry|
      (MenuHandlers.getName(entry) rescue entry.to_s)
    end
  end
end
```

### `around_hook` — controlar si el original corre

No hay un `throw :skip_original`: el control es `call_next`. **No recibe argumentos**; replay de la
cadena con los argumentos originales del llamante (para cambiarlos, muta `args` antes de llamarlo).

```ruby
# core/field/minigame_text.rb -- marcar la mano activa mientras dura el bucle del minijuego
PokeAccess::Hooks.around_hook("TriadScene", :pbPlayerChooseCard, :optional => true) do |scene, call_next, _a|
  PokeAccess::TripleTriad.start_hand(scene)
  begin; call_next.call; ensure; PokeAccess::TripleTriad.stop; end
end
```

### `frame_hook` — driver por-frame

Un método que el motor llama cada frame y que puede alojar sincrónicamente un bucle modal entero.
El cuerpo corre DESPUÉS (un poller lee el frame ya actualizado) y no usa el valor de retorno.

```ruby
# core/nav/locator.rb
PokeAccess::Hooks.frame_hook("Game_Player", :update) do |_p, _a|
  PokeAccess::Perf.measure(:map_poll) { PokeAccess::Locator.map_poll }
end
```

### `read_on_open` — resumen hablado al abrir una pantalla

Engancha el abridor de la escena y habla el texto del bloque **encolado** (una lectura de apertura nunca
debe cortar el clic de transición ni una línea en curso; solo los lectores de navegación interrumpen).
El texto pasa por `PokeAccess.clean`; `nil` o vacío se queda callado.

```ruby
# core/menus/trainer_card.rb
PokeAccess::Hooks.read_on_open("PokemonTrainerCardScene") { |_s| PokeAccess::TrainerCard.text }

# games/opalo/trainer_card.rb -- este abridor BLOQUEA en su propio bucle; con un after solo hablaría al cerrar
PokeAccess::Game.define("opalo") do
  read_on_open("OpaloCard", :pbStartScene, :timing => :before) { |_s| PokeAccess::OpaloCard.main_text }
end
```

### `override` — reemplazo declarado

`override` **sustituye** un método, declarando la intención (frente a reabrir un módulo en silencio, que
nadie ve). `target` es un **módulo del mod** (se reemplaza su método de singleton) o el **nombre de una
clase del juego** en string (se reemplaza su método de instancia, vía `around_hook`).

- El cuerpo recibe `(receptor, original, args)`. `original` es un lambda con la implementación
  reemplazada: **llámalo para envolver** en vez de sustituir.
- Semántica de `around`: los fallos del cuerpo se loguean y **se relanzan** (nunca se tragan).
- **Apilable**: un segundo `override` sobre el mismo método recibe el PRIMERO como su `original`; gana el
  último y los dos quedan listados.
- Cada instalación se registra en `Hooks.overrides` y **el diagnóstico la imprime**, así que pisar un
  lector del core nunca es invisible.
- Un nombre que toda clase responde en su singleton (`:name`, `:to_s`, heredados de `Module`) solo cuenta
  como singleton si el target lo define él mismo; si no, se entiende el método de instancia.

```ruby
# games/reminiscencia/move_relearner.rb -- este juego quiere que las flechas digan solo el nombre
# del movimiento (el detalle completo lo da la tecla de info), así que reemplaza el lector del core.
PokeAccess::Game.define("reminiscencia") do
  override(PokeAccess::MoveRelearnerGen6, :detail) do |_mod, _original, args|
    id = (PokeAccess::MoveRelearnerGen6.focused_id(args[0]) rescue nil)
    name = id ? (PokeAccess::Data.move_name(id) rescue nil) : nil
    PokeAccess.speak(name.to_s, true) if name && !name.to_s.empty?
  end
end
```

> Desde la DSL de perfiles la firma es `override(target, meth)` (sin `opts`): el tag lo pone ella,
> `"game_<perfil>"`.

### `wrap_global` / `wrap_kernel` — funciones que no son de clase

Los hooks de clase no alcanzan las funciones top-level de Essentials (`pbDisplayMail`,
`pbShowCommandsWithHelp`, `pbItemBall`...).

| | Busca en | timing por defecto |
|---|---|---|
| `wrap_global(name, tag, timing)` | método top-level de `Object` | `:after` |
| `wrap_kernel(name, tag, timing)` | singleton de `Kernel` (`def Kernel.foo`, estilo gen-6) y, si no, cae a `wrap_global` (`def foo`, estilo moderno) | `:before` |

Contrato del bloque según `timing`:

| timing | Bloque | Se traga la excepción |
|---|---|---|
| `:before` | `(args, nil)`, corre antes del original | Sí (se loguea una vez) |
| `:after` | `(args, resultado)`, corre después | Sí (se loguea una vez) |
| `:around` | `(args, call_next)`, **debes** llamar `call_next`; devuelve su resultado | No: se loguea y se relanza |

Una función que no existe **en ningún sitio** se anota en `Hooks.fn_absent` y se salta; una ya envuelta es
no-op.

```ruby
# core/field/mail.rb -- leer el correo antes de que aparezca su tarjeta modal
PokeAccess::Hooks.wrap_global("pbDisplayMail", "hook_mail", :before) { |args, _r| PokeAccess.say_mail(args[0]) }

# core/field/hud_text.rb -- pbDisplayText es Kernel en unos juegos y top-level en otros
PokeAccess::Hooks.wrap_kernel("pbDisplayText", "hud_text", :after) { |args, _r| PokeAccess::HudText.say(args[0]) }

# core/battle/gen6/battle_g6.rb -- envolver el combate entero, marcando entrada y salida pase lo que pase
PokeAccess::Hooks.wrap_kernel("pbBattleAnimation", "hook_battle_sonar", :around) do |_args, call_next|
  PokeAccess::Battle.battle_started
  begin; call_next.call; ensure; PokeAccess::Battle.battle_ended; end
end
```

---

## Implementación interna: la cebolla

Varios hooks pueden envolver el mismo método: cada uno registra un middleware y **se encadenan** alrededor
del original, así una función nueva nunca desactiva en silencio un hook existente.

`wrap` no redefine de cero cada vez. La PRIMERA vez crea el alias del original (con nombre por-clase,
p.ej. `update__pa_orig_Game_Player`) y un `define_method` que recorre la cadena; cada hook posterior solo
añade su middleware. Resumido:

```ruby
key = "#{cname}##{meth}"
fresh = !@chains.has_key?(key)
(@chains[key] ||= []).push(mw)
return unless fresh
k.send(:alias_method, orig, meth)
k.send(:define_method, meth) do |*args, &blk|
  return send(orig, *args, &blk) if PokeAccess::Hooks.nested_other?(meth)
  call = lambda { send(orig, *args, &blk) }        # el original, al fondo de la cebolla
  chains[key].reverse_each do |w|                  # envolver cada middleware alrededor
    nxt = call
    call = lambda { w.call(self, nxt, args) }
  end
  call.call
end
```

El alias se comprueba contra los métodos **propios** de la clase, así que enganchar un padre y luego un
hijo que sobrescribe el mismo método no se salta la lógica del hijo.

`before_hook`/`after_hook` son capas finas sobre `wrap`: el "before" corre el cuerpo y luego `nxt.call`;
el "after" hace `r = nxt.call`, corre el cuerpo con `r` y devuelve `r`.

**Orden**: el PRIMER registro queda en la capa MÁS EXTERNA de la cebolla. Por tanto, con dos hooks A y B
registrados en ese orden sobre el mismo método:

- los cuerpos de `before_hook` corren **A, B** (y luego el original);
- los cuerpos de `after_hook` corren **B, A** (el más interno vuelve antes).

Todos reciben el mismo resultado del original, así que el orden solo importa si dos hooks hablan; si te
descubres dependiendo de él, casi siempre lo correcto es fusionarlos en un lector.

---

## La guarda de reentrancia

Este es el concepto más difícil del motor y el que más bugs ha causado. Léelo antes de escribir un
`after_hook` sobre algo que abra pantallas.

El juego es mono-hilo, así que basta una pila de módulo (`@active`) con los NOMBRES de los métodos cuyo
ORIGINAL está corriendo ahora mismo:

- `nested_other?(meth)` → `true` si hay algo en la pila y la cima NO es `meth`.
- El dispatcher de `wrap`: si la llamada es una entrada **anidada** a un método hookeado de nombre
  **distinto** al de la cima, **se salta la cadena entera** y va directo al original.
- `guarded(meth)` empuja `meth`, hace `yield` y SIEMPRE hace `pop` (`ensure`): un original que lanza nunca
  deja hooks anidados mudos para siempre.

**Para qué.** Un `after_hook` cuyo original llama SINCRÓNICAMENTE a OTRO método hookeado (p.ej.
`set_party_index`, que por dentro invoca `refresh`) no debe dejar que el hook interno hable y consuma el
dedup del externo: el `after_hook` EXTERNO, cuando el original vuelve, es el anunciante autoritativo.

La guarda es correcta SOLO para **anunciantes atómicos**: métodos cuyo propio cuerpo es la voz.

### Los tres escapes

| Escape | Qué pasa | Cuándo lo quieres |
|---|---|---|
| **Mismo nombre** | Una llamada anidada al MISMO nombre sí atraviesa la guarda | Un hijo que llega a su padre hookeado vía `super` dispara ambos hooks (la cebolla documentada) |
| **`:hook_container => true`** (y `frame_hook`, su alias con forma de poller) | El original corre SIN guarda | El método es un CONTENEDOR: delega el anuncio en métodos hookeados que él conduce |
| **Solo `after_hook` guarda** | `before_hook` y `around_hook` nunca empujan su original a la pila | Un `before` ya habló antes del original, así que no tiene dedup que proteger; un `around` controla la llamada él mismo |

**Qué es un CONTENEDOR.** Un bucle modal o un abridor de escena que no habla él mismo, sino que conduce
lectores hookeados por dentro: la fase de comandos de combate (`pbShowCommands`/`pbCommandMenu` conducen
`CommandMenuDisplay#index=` y `FightMenuDisplay#setIndex`), o los abre-escenas
(`pbScene`/`pbStartScene`/`main` conducen el `drawPage` del pokédex, el `drawPageOne` del resumen, el
`selected=` del panel de party). Guardarlos enmudece a los lectores que hacen el trabajo.

```ruby
# core/battle/gen6/battle_g6.rb -- selección de objetivo en dobles: el original conduce los setters
# de índice ya hookeados del display; guardarlo los silenciaría.
PokeAccess::Hooks.after_hook("PokeBattle_Scene", :pbUpdateSelected, :hook_container => true) do |scene, _r, args|
  PokeAccess::Battle.announce_target(scene, args[0])
end
```

**Qué es un DRIVER por-frame.** Un método que el motor llama cada frame y que puede alojar un bucle modal
entero. El caso canónico es `Game_Player#update`: en gen-6, pisar hierba lanza el combate salvaje DESDE
DENTRO (`Scene_Map#update -> $game_player.update -> encounter -> el combate entero`). Guardarlo fija
`:update` en la pila durante todo el combate y cada lector de batalla se salta como `nested_other?`. El
síntoma es exacto: "los combates salvajes son mudos, los de entrenador leen" (el de entrenador corre desde
el intérprete del mapa, no desde el player). Para eso está `frame_hook`.

**Por defecto es atómico (guardado)**: un hook que no dice nada mantiene el comportamiento seguro.

---

## Manejo de errores

El cuerpo de `before_hook`/`after_hook`/`frame_hook`/`read_on_open` corre dentro de `run_body`, que
**traga la excepción** (un lector que peta no rompe el juego) y **loguea el PRIMER fallo** al marker,
deduplicado por REGISTRO (no por método): si dos features enganchan `Game_Player#update`, el fallo de una
no silencia el diagnóstico de la otra. Por eso el cuerpo no necesita su propio `begin/rescue`:

```ruby
PokeAccess::Hooks.after_hook("PokeBattle_Scene", :pbDisplayMessage) do |_scene, _result, args|
  PokeAccess.speak(args[0])   # si lanza, run_body lo traga y anota el primer fallo
end
```

`around_hook` y `override` son la excepción: como pueden elegir legítimamente no ejecutar el original, su
primer fallo se loguea y **se relanza**.

---

## Diagnóstico de enganches

Tres listas, con significados distintos. El volcado de diagnóstico (Ctrl+Alt+F9) imprime las tres en su
línea `hooks:`, y el diagnóstico hablado (Ctrl+Alt+F10) canta cuántos `missing` hay si hay alguno.

| Consulta | Qué contiene | Cómo leerlo |
|---|---|---|
| `Hooks.missing` | `"Clase#metodo"` cuya **clase existe pero el método no** (y no era `:optional`); también los targets no resueltos de `override` | **Probable typo.** Casi siempre un nombre de método mal escrito |
| `Hooks.fn_absent` | Nombres de función global que `wrap_global`/`wrap_kernel` **no encontraron en ningún sitio** (ni singleton de `Kernel` ni `Object`) | **Informativo.** Una función que solo existe en algunos fangames es variación normal; aquí es donde asoma un nombre mal escrito |
| `Hooks.overrides` | Los reemplazos declarados, como `"Target.meth (tag)"` | **Auditoría.** Qué está sustituido y quién lo sustituyó |

```
hooks: missing=[] fn_absent=["pbDisplayText"] overrides=["PokeAccess::MoveRelearnerGen6.detail (game_reminiscencia)"]
```

---

## Patrones comunes

### Lectura de cursor deduplicada (`Cursor`)

La UI re-afirma la selección cada frame, así que un lector de cursor debe hablar SOLO cuando el foco
cambia. `PokeAccess::Cursor` (`core/menus/cursor.rb`) es la primitiva de dedup **por defecto**: úsala en
todo lector nuevo en vez de abrir un ivar `@access_*` propio.

```ruby
PokeAccess::Hooks.after_hook("MiVisuals", :refresh_on_index_changed) do |vis, _r, _a|
  idx = (vis.index rescue nil)
  PokeAccess::Cursor.announce(vis, :mi_lista, idx) { texto_de(vis, idx) }   # habla solo si idx cambió
end
# Al (re)abrir la escena, para que relea el mismo índice:
PokeAccess::Hooks.before_hook("MiScene", :pbStartScene) { |s, _a| PokeAccess::Cursor.reset(s, :mi_lista) }
```

La key puede ser un índice, un texto o una tupla (`[página, índice]`). El `holder` es la instancia (estado
por escena, muere con ella) o `nil` para una tabla global por slot. API completa en
[10_API_REFERENCE.md](10_API_REFERENCE.md).

> **La excepción acotada.** El dedup a mano con un ivar propio se tolera solo donde el hook **ya recibe
> por `args` el dato que se compara** (un `after_hook` cuyo método toma el índice o la clave como
> argumento): ahí la comparación es local al hook y el ivar solo guarda el valor anterior. Los lectores
> in-battle de DBK son ese caso. En cuanto tengas que ir a buscar el foco a la instancia, o necesites
> `reset`/`pending?`/clave-tupla, es `Cursor`.

### Menús con su propio bucle bloqueante (`SceneWatcher`)

Si la pantalla corre su propio bucle de entrada, los hooks de cursor no disparan a mitad y hay que sondear
por frame. `PokeAccess::SceneWatcher` (`core/menus/scene_watcher.rb`) sujeta la escena durante el bucle
(con un `around`) y corre el poll:

```ruby
# core/menus/v21/pausemenu_v21.rb -- el bloque devuelve [key, texto]; una key nueva habla el texto
PauseMenuV21 = SceneWatcher.reader("PokemonPauseMenu_Scene", :pbShowCommands, :pausemenu_v21) do |s|
  w = PokeAccess.sprite(s, "cmdwindow")
  idx = w ? (w.index rescue nil) : nil
  (idx.nil? || idx < 0) ? nil : [idx, (PokeAccess::Menus.generic_focus(w, idx) rescue nil)]
end
```

### Gate por capacidad

Casi nunca hace falta ramificar por versión de Essentials: registra el hook donde la CLASE existe (es
no-op si no), y para lo que difiere dentro de una misma clase, gatea por CAPACIDAD con `Engine.has?`. Así
un fork que backportee el método se activa solo.

```ruby
# core/battle/v21/battle_v21.rb
if PokeAccess::Engine.has?("Battle::Scene::MenuBase#setIndexAndMode")
  PokeAccess::Hooks.after_hook("Battle::Scene::MenuBase", :setIndexAndMode) do |menu, _r, args|
    # ...
  end
end
```

Si lo único que quieres es que un método ausente no cuente como typo, `:optional => true` es más directo
que un `Engine.has?` alrededor.

### Información contextual para la tecla de info

```ruby
PokeAccess::Hooks.after_hook("MoveRelearnerScene", :pbDrawMoveList) do |scene, _r, _a|
  PokeAccess::Info.set_info(:text, texto_del_movimiento_enfocado(scene))
end
```

---

## Limitaciones

1. **Rendimiento.** Cada hook añade una llamada a bloque por invocación. En métodos por-frame, mide con
   `PokeAccess::Perf.measure(:etiqueta) { ... }` y evita recalcular lo que no cambió (para eso está
   `Cursor`).
2. **Compatibilidad con otros mods.** Otro mod que reabra la misma clase con `alias_method` puede quedar
   por debajo o por encima de la cadena según el orden de carga. Enganches sobre métodos distintos no
   interfieren.

---

## Referencias

- [Hooks](../core/input/hooks.rb) - el motor de cadena/middleware
- [Cursor](../core/menus/cursor.rb) - primitiva de dedup
- [SceneWatcher](../core/menus/scene_watcher.rb) - pantallas con bucle propio
- [Game](../core/foundation/game.rb) - la DSL de perfiles sobre estos registradores
- [Battle G6](../core/battle/gen6/battle_g6.rb) / [Battle V21](../core/battle/v21/battle_v21.rb) - ejemplos reales
- [Guía de extensión](14_EXTENDING.md) - cómo añadir tus propios lectores

## Próximo

- [Data API](05_DATA_API.md) - Acceso a datos
- [Pathfinding](06_PATHFINDING.md) - Navegación
