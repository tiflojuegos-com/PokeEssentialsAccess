# Hooks

Enganchar es registrar código propio alrededor de un método que ya existe, sin tocar los scripts del juego.
Todo el sistema está en `core/input/hooks.rb` y es 1.8.7-safe. Varios hooks pueden envolver el mismo método:
cada uno registra un middleware y se encadenan como una cebolla alrededor del original, así una función nueva
nunca desactiva en silencio un hook existente.

## Por qué se engancha por nombre

`cname` es siempre un **string** (`"Battle::Scene"`), nunca la constante. `wrap` la resuelve con
`PokeAccess.const_at`, que camina los segmentos de uno en uno porque el `const_defined?` de 1.8.7 rechaza un
nombre con `::`. Nombrar la constante reventaría la carga en cualquier juego que no la defina, y ninguna clase
existe en los 14 perfiles a la vez: `PokemonMenu_Scene` es de gen-6, `UI::BaseScreen` de v22.

| Situación | Resultado |
|---|---|
| Clase ausente | No-op silencioso: es variación normal entre juegos |
| Método ausente sobre clase presente | Se anota en `Hooks.missing`, salvo con `:optional` |
| Método privado | Se engancha igual: `wrap` lo detecta y lo vuelve a privatizar tras redefinirlo |
| Método ya enganchado | Solo añade el middleware; el alias del original se crea una vez |

`override` es la excepción a la primera fila: un target que no resuelve **sí** cuenta en `Hooks.missing`,
porque un reemplazo declarado siempre nombra algo que debería existir.

## Los registradores

| Registrador | Firma | El bloque recibe | Cuándo |
|---|---|---|---|
| `before_hook` | `(cname, meth, opts)` | `(instancia, args)` | Hablar antes de que el original bloquee |
| `after_hook` | `(cname, meth, opts)` | `(instancia, resultado, args)` | Leer el estado ya actualizado |
| `around_hook` | `(cname, meth, opts)` | `(instancia, call_next, args)` | Decidir si el original corre, o marcar entrada y salida de un bucle |
| `frame_hook` | `(cname, meth)` | `(instancia, args)` | Poller por frame. No admite `opts` |
| `read_on_open` | `(cname, meth = :pbStartScene, opts)` | `(escena)`, devuelve el texto | Resumen hablado al abrir una pantalla |
| `override` | `(target, meth, opts)` | `(receptor, original, args)` | Reemplazo declarado de un método |
| `wrap_global` | `(name, tag, timing = :after)` | `(args, resultado)` o `(args, call_next)` | Función top-level de `Object` |
| `wrap_kernel` | `(name, tag, timing = :before)` | igual que `wrap_global` | Función que puede ser singleton de `Kernel` o top-level |
| `wrap` | `(cname, meth, opts)` | `(instancia, call_next, args)` | El motor: middleware crudo. Los demás lo usan |

`call_next` no recibe argumentos: repite la cadena con los del llamante; para cambiar lo que ve el original,
muta el array `args` **in situ** antes de llamarlo. El primer registro queda en la capa más externa, así que
con A y B en ese orden los cuerpos `before_hook` corren A, B y los `after_hook`, B, A.

`read_on_open` habla **encolado** (`PokeAccess.speak(texto, false)`): una apertura nunca corta el clic de
transición ni una línea en curso. El texto pasa por `PokeAccess.clean`; `nil` o vacío se calla.
`games/opalo/trainer_card.rb` es el caso de `:timing => :before`: su abridor bloquea en su propio bucle y un
after solo hablaría al cerrar.

`override` sustituye un método declarando la intención, frente a reabrir un módulo en silencio. `target` es
un módulo del mod (su método de singleton) o el nombre en string de una clase del juego (su método de
instancia, vía `around_hook`). El cuerpo recibe `original` como lambda: llámalo para envolver en vez de
sustituir. Cada instalación queda en `Hooks.overrides` y el diagnóstico la imprime.

```ruby
# games/reminiscencia/move_relearner.rb -- las flechas dicen solo el nombre; el detalle lo da la tecla de info
override(PokeAccess::MoveRelearnerGen6, :detail) do |_mod, _original, args|
  name = (PokeAccess::Data.move_name(PokeAccess::MoveRelearnerGen6.focused_id(args[0])) rescue nil)
  PokeAccess.speak(name.to_s, true) if name && !name.to_s.empty?
end
```

Apilar dos overrides funciona, pero el orden depende de la ruta: en un módulo del mod el segundo recibe al
primero como `original` y gana el último; en una clase del juego va por la cadena de `wrap` y es el primero el
que queda por fuera, recibiendo al segundo.

Los hooks de clase no alcanzan las funciones top-level de Essentials. `wrap_global` las busca en `Object`;
`wrap_kernel` prueba primero el singleton de `Kernel` (`def Kernel.foo`, estilo gen-6) y si no cae a
`wrap_global` (`def foo`, moderno). Una función que no está en ningún sitio se anota en `Hooks.fn_absent`.

| `timing` | El bloque recibe | La excepción del cuerpo |
|---|---|---|
| `:before` | `(args, nil)`, corre antes del original | Tragada, logueada una vez |
| `:after` | `(args, resultado)`, corre después | Tragada, logueada una vez |
| `:around` | `(args, call_next)`, debes llamar `call_next` | Logueada y relanzada |

El `:around` sobre `pbBattleAnimation` (`core/battle/gen6/battle_g6.rb`) es el patrón: la función envuelve el
combate entero, así que marcar dentro de un `begin/ensure` deja el flag limpio pase lo que pase.

## Opciones

| Opción | Vale para | Efecto |
|---|---|---|
| `:optional => true` | `wrap`, `before_hook`, `after_hook`, `around_hook`, `read_on_open`, `override` | El método falta legítimamente en algunos juegos: el enganche se salta en silencio en vez de contar como typo |
| `:hook_container => true` | `after_hook` y `read_on_open`, que lo pasa | El original corre sin la guarda de reentrancia |
| `:timing => :before` | `read_on_open` | Habla antes del abridor, para abridores que bloquean en su propio bucle |
| `:tag => "..."` | `override` | Nombra al dueño del reemplazo en el listado del diagnóstico |

`:optional` **SÍ** cuando el método falta por variación real: una variante del plugin, un fork que lo renombró,
un `pbUpdateBattlerInfo` que solo trae el Deluxe Battle Kit. Sin él esos juegos dejan entradas permanentes en
`missing`, y ocho falsos positivos esconden el real. **NO** por costumbre ni por si acaso: `missing` es por
contrato la lista de TYPOS, y cada `:optional` de más le quita una detección. Para ramificar por lo que el motor
sabe hacer el gate es `Engine.has?` ([02-motores](02-motores.md)); `:optional` solo silencia el apunte.

## La guarda de reentrancia

**El problema.** Un `after_hook` cuyo original llama sincrónicamente a OTRO método hookeado (v22:
`set_party_index` invoca `refresh` por dentro) deja hablar al hook interno, que consume el dedup del externo
y enmudece al anunciante autoritativo: el `after_hook` externo, que corre cuando el original vuelve.

**El mecanismo.** El juego es mono-hilo, así que basta una pila de nombres.

- `@active`: los nombres de método cuyo ORIGINAL está corriendo ahora mismo.
- `guarded(meth)` empuja, hace `yield` y siempre hace `pop` en un `ensure`, así un original que lanza nunca
  deja hooks anidados mudos para siempre. Solo lo llama `after_hook`, y solo cuando no es contenedor.
- `nested_other?(meth)` es cierto si la pila no está vacía y la cima no es `meth`; el dispatcher de `wrap` se
  salta entonces la cadena entera y va directo al original.

Solo `after_hook` **empuja**, pero **saltarse** la cadena le pasa a cualquier método hookeado, con el
registrador que sea: un `before_hook` anidado bajo otro guardado tampoco dispara.

| Escape | Qué hace | Cuándo lo quieres |
|---|---|---|
| Mismo nombre | Una llamada anidada al MISMO nombre atraviesa la guarda | Un hijo que llega a su padre hookeado vía `super` dispara ambos hooks |
| `:hook_container => true` | El original corre sin guarda | El método es un contenedor: delega el anuncio en métodos hookeados que él conduce |
| `frame_hook` | Igual, más el cuerpo después y sin usar el retorno | Driver por frame que puede alojar un bucle modal entero |

Por defecto es atómico (guardado): un hook que no dice nada mantiene el comportamiento seguro. **Contenedor** es
un bucle modal o un abridor que no habla él, sino que conduce lectores hookeados por dentro —la fase de comandos
de combate, el `pbUpdate` de opciones, los `pbScene`/`pbStartScene`/`main` que conducen el `drawPage` del
pokédex, el `drawPageOne` del resumen y el `selected=` de party—; guardarlos enmudece a quien hace el trabajo.

### El caso raíz: `Game_Player#update`

En gen-6, pisar hierba lanza el combate salvaje desde DENTRO del update del jugador
(`Scene_Map#update -> $game_player.update -> encounter -> el combate entero`). Con un `after_hook` atómico,
`:update` queda fijado en la pila durante todo el combate y cada lector de batalla —mensajes, menú de comandos,
movimientos— se salta como `nested_other?`. El síntoma fue exacto: combates salvajes mudos y combates de
entrenador leyendo, porque esos corren desde el intérprete del mapa, no desde el jugador. Los tres pollers
sobre ese método (`core/nav/locator.rb`, `core/audio/audio3d.rb`, `core/util/recorder.rb`) son `frame_hook`.

```ruby
# core/nav/locator.rb
PokeAccess::Hooks.frame_hook("Game_Player", :update) do |_p, _a|
  PokeAccess::Perf.measure(:map_poll) { PokeAccess::Locator.map_poll }
end
```

### Supresión invisible

Cuando la guarda descarta un hook no hay error, ni log, ni test en rojo: la pantalla se calla, y eso es lo que un
jugador ciego no puede depurar. `note_suppressed` apunta el par `"externo>interno"` (deduplicado, tope 40) y el
diagnóstico lo imprime como `guard_suppressed`. Suprimir suele ser CORRECTO: busca el par cuyo externo no habla.

## El fallo silencioso

`Hooks.missing` solo comprueba el nombre del método enganchado. Un hook que se ata perfectamente y luego lee un
ivar o un accessor que en ese juego se llama distinto no sale en ninguna lista: `PokeAccess.ivar` y
`PokeAccess.attr_of` devuelven `nil` en vez de lanzar, `run_body` no tiene nada que tragar y la pantalla calla.

Essentials renombró accesores entre eras y cada fangame conservó la grafía de la que forkeó.
`PokeAccess.attr_of(obj, :power, :base_damage)` prueba los nombres en orden y devuelve el primero que responda
algo; para los ivars el equivalente es encadenar `PokeAccess.ivar`.

```ruby
# core/battle/battle.rb -- la ventana de comandos: @window hasta v17, @cmdWindow desde v19
PokeAccess.ivar(disp, :@window) || PokeAccess.ivar(disp, :@cmdWindow)
```

Regla: **un hook instalado no prueba que el dato esté donde crees.** Verifícalo en el juego, no en `missing`.

## Errores y diagnóstico

| Registrador | Fallo del cuerpo |
|---|---|
| `before_hook`, `after_hook`, `frame_hook`, `read_on_open` | Tragado; el primero se loguea al marker, deduplicado por REGISTRO y no por método, así que si dos features enganchan `Game_Player#update` el fallo de una no silencia el diagnóstico de la otra |
| `around_hook`, `override`, `wrap_*` con `:around` | Logueado y relanzado: pueden elegir legítimamente no correr el original |

Cuatro listas distintas, impresas por el diagnóstico ([07-diagnostico](07-diagnostico.md)); `missing` además se
loguea al arrancar, en `loader/boot.rb`.

| Consulta | Qué contiene | Cómo leerlo |
|---|---|---|
| `Hooks.missing` | `"Clase#metodo"` cuya clase existe pero el método no, y los targets no resueltos de `override` | Probable typo |
| `Hooks.fn_absent` | Funciones globales que no se encontraron en ningún sitio | Informativo: hay funciones que solo existen en algunos fangames |
| `Hooks.overrides` | Los reemplazos declarados, como `"Target.meth (tag)"` | Auditoría: qué está sustituido y quién lo sustituyó |
| `Hooks.suppressed` | Pares `"externo>interno"` que la guarda descartó | Evidencia, no fallo: busca un par cuyo externo no hable |

El dedup por defecto es `PokeAccess::Cursor`; las pantallas con bucle propio se sondean con `SceneWatcher`
([04-lectores](04-lectores.md)).
