# Data API - Acceso Agnóstico a Datos

## El Problema: Datos Fragmentados

Essentials guarda la información de Pokémon de dos formas incompatibles según la era del motor:

| Dato | Gen-6 (`:gen6`) | Era GameData (`:gamedata`, v19+) |
|---|---|---|
| Especie | `PBSpecies.getName(123)` | `GameData::Species.get(123).name` |
| Tipo | `PBTypes.getName(1)` | `GameData::Type.get(1).name` |
| Movimiento | `PBMoves.getName(1)` | `GameData::Move.get(1).name` |
| Objeto | `PBItems.getName(1)` | `GameData::Item.get(1).name` |
| Modelo | tablas globales indexadas por entero | registros con getters, indexados por símbolo |

**Solución**: patrón provider — un adaptador por era, una única interfaz. Los lectores llaman a
`PokeAccess::Data.*` y nunca ramifican por motor.

## Arquitectura Provider

Un provider es un **módulo** (no una clase con `.new`) con métodos de clase, uno por consulta. Los
resolutores van **crudos, sin `rescue`**: `Data.resolve` envuelve cada llamada nil-safe, así no se repite
un rescue por método.

```ruby
# core/data/gen6/data_g6.rb
module PokeAccess::DataG6
  def self.species_name(id); PBSpecies.getName(id); end
end
PokeAccess::Data.register(10, PokeAccess::DataG6) if defined?(PBMoves) && !defined?(GameData)

# core/data/v21/data_v21.rb
module PokeAccess::DataV21
  def self.species_name(id); GameData::Species.get(id).name; end
end
PokeAccess::Data.register(20, PokeAccess::DataV21) if defined?(GameData) && defined?(GameData::Move)
```

### Selección por prioridad

```ruby
module PokeAccess::Data
  def self.register(priority, provider)
    @providers.push([priority, provider]); @active_entry = nil
  end

  # [prioridad, provider] de MÁS ALTA prioridad, memoizado hasta el próximo register
  def self.active_entry; @active_entry ||= @providers.max_by { |pr| pr[0] }; end
  def self.active; e = active_entry; e && e[1]; end
  def self.active_priority; e = active_entry; e && e[0]; end

  # Cada lector público delega en resolve, que llama al provider activo bajo begin/rescue
  def self.species_name(id); resolve(:species_name, id); end

  def self.resolve(method, arg)
    pr = active
    return nil unless pr
    begin
      pr.send(method, arg)
    rescue StandardError => e
      note_error(method, e)  # log una sola vez, sin crashear
      nil
    end
  end
end
```

| Prioridad | Provider | Cuándo se registra |
|---|---|---|
| 20 | `DataV21` (GameData) | `GameData` y `GameData::Move` definidos |
| 10 | `DataG6` (PB*) | `PBMoves` definido y `GameData` NO |
| 0 | `DataFallback` | siempre, incondicional |

El de prioridad 0 existe para que **nunca** haya cero providers: en un motor que ninguno reconozca, sigue
hablando el id crudo en vez de callar. El arranque avisa cuando el provider activo es ese.

## Interfaz de `Data`

```ruby
module PokeAccess::Data
  # Movimiento
  def self.move_name(id)              # "Tackle"
  def self.move_type_name(id)         # "Normal"
  def self.move_power(id)             # 40
  def self.move_accuracy(id)          # 100
  def self.move_description(id)       # "Ataca al oponente de frente..."

  # Tipo, objeto, especie
  def self.type_name(id)              # "Fire"
  def self.item_name(id)              # "Potion"
  def self.item_name_plural(id)       # "Potions" (para cantidades > 1)
  def self.item_description(id)       # "Recupera 20 PS..."
  def self.item_id(sym)               # :POTION -> [id, "Potion"] (PAR, no solo el id)
  def self.species_name(id)           # "Pikachu"
  def self.species_entry(id)          # [nombre, categoría, texto de la Pokédex]

  # Habilidad, naturaleza, estadísticas
  def self.ability_name(id)           # "Static"
  def self.nature_name(id)            # "Timid"
  def self.stat_name(s)               # "Ataque"
  def self.status_name(st)            # nombre del estado; en gen-6, la CLAVE i18n de Config.status_names
  def self.pokemon_types(pk)          # ["Fire", "Flying"] -- nunca nil, [] si no resuelve
end
```

## Implementación por Versión

### Gen-6 — `core/data/gen6/data_g6.rb`

Tablas `PB*` más `pbGetMessage` para los textos largos.

```ruby
module PokeAccess::DataG6
  def self.move_name(id);        PBMoves.getName(id); end
  def self.move_power(id);       PBMoveData.new(id).basedamage; end
  def self.move_accuracy(id);    PBMoveData.new(id).accuracy; end
  def self.move_type_name(id);   PBTypes.getName(PBMoveData.new(id).type); end
  def self.move_description(id); pbGetMessage(MessageTypes::MoveDescriptions, id); end
  def self.status_name(st);      PokeAccess::Config.status_names[st]; end

  # La ficha de Pokédex como [nombre, categoría, texto], desde las tablas de mensajes.
  def self.species_entry(id)
    [PBSpecies.getName(id), (pbGetMessage(MessageTypes::Kinds, id) rescue nil),
     (pbGetMessage(MessageTypes::Entries, id) rescue nil)]
  end

  # Los ids gen-6 son enteros: el símbolo se mapea por la constante de PBItems (o getID).
  def self.item_id(sym)
    id = (PBItems.const_get(sym) rescue nil)
    id = (getID(PBItems, sym.to_sym) rescue nil) if id.nil?
    [id, (id ? (PBItems.getName(id) rescue nil) : nil)]
  end
end
```

### Era GameData — `core/data/v21/data_v21.rb`

Encadena directo (`.name`); la seguridad ante nil la da `Data.resolve`, no `&.` (Ruby 1.8.7).

```ruby
module PokeAccess::DataV21
  def self.move_name(id);      GameData::Move.get(id).name; end
  def self.move_power(id);     GameData::Move.get(id).power; end
  def self.move_type_name(id); GameData::Type.get(GameData::Move.get(id).type).name; end
  def self.status_name(st);    GameData::Status.get(st).name; end

  # El plural cae a portion_name_plural, luego portion_name, y por último al nombre singular.
  def self.item_name_plural(id)
    d = GameData::Item.get(id)
    (d.portion_name_plural rescue nil) || (d.portion_name rescue nil) || d.name
  end

  # Los items modernos se indexan por símbolo: el símbolo ES el id.
  def self.item_id(sym); s = sym.to_s.to_sym; [s, (GameData::Item.get(s).name rescue nil)]; end
end
```

### Fallback — `core/data/data_fallback.rb`

Último recurso: devuelve el id crudo como string y deja en `nil` los campos ricos.

```ruby
module PokeAccess::DataFallback
  def self.species_name(id);  id.to_s; end
  def self.move_name(id);     id.to_s; end
  def self.move_power(id);    nil; end
  def self.species_entry(id); [id.to_s, nil, nil]; end
  def self.item_id(sym);      [sym, sym.to_s]; end
  # Etc.
end

PokeAccess::Data.register(0, PokeAccess::DataFallback)
```

## Uso en el Código

```ruby
# El lector no sabe qué motor corre: gen-6 llama PBSpecies.getName, moderno GameData::Species.get.
name = PokeAccess::Data.species_name(pokemon_id)
PokeAccess.speak(PokeAccess::I18n.t(:sum_species, :s => name), true) if name
```

Un provider personalizado se registra por encima de los de serie:

```ruby
PokeAccess::Data.register(75, MiProvider)  # 75 > 20 (GameData) > 10 (gen-6): gana sobre ambos
```

## Errores y Recuperación

`resolve` devuelve `nil` en dos casos distintos: **el dato no existe** (silencio intencionado) o **el
provider ha lanzado** (probable bug). El segundo se registra una sola vez por `(método, clase de error)`
en el marcador, y el lector degrada en vez de crashear.

```ruby
# accessibility/data/hook_loaded.txt
data provider error -- species_name: NoMethodError: undefined method 'name' for nil:NilClass
```

Escribe siempre contra un `nil` posible:

```ruby
name = PokeAccess::Data.species_name(999)
PokeAccess.speak(name || PokeAccess::I18n.t(:loc_object))  # bien
PokeAccess.speak(name.upcase)                              # crashea si nil
```

### Ver el estado

```ruby
PokeAccess::Data.active           # -> PokeAccess::DataV21 / DataG6 / DataFallback (un módulo)
PokeAccess::Data.active_priority  # -> 20, 10 o 0
PokeAccess::Data.errors           # -> ["species_name: NoMethodError: ..."]; vacío en una run limpia
```

## Caching

`Data` no cachea. Cachear en el llamante es seguro e indefinido: las tablas gen-6 son constantes y los
registros de GameData son singletons.

```ruby
@species_names = {}
def species_name(id); @species_names[id] ||= PokeAccess::Data.species_name(id); end
```

## Tabla Rápida: Mapeo Gen-6 → era GameData

| Gen-6 | Era GameData | Método de `Data` |
|---|---|---|
| `PBSpecies.getName(id)` | `GameData::Species.get(id).name` | `species_name(id)` |
| `PBMoves.getName(id)` | `GameData::Move.get(id).name` | `move_name(id)` |
| `PBTypes.getName(id)` | `GameData::Type.get(id).name` | `type_name(id)` |
| `PBItems.getName(id)` | `GameData::Item.get(id).name` | `item_name(id)` |
| `PBItems.getNamePlural(id)` | `GameData::Item.get(id).portion_name_plural` | `item_name_plural(id)` |
| `PBAbilities.getName(id)` | `GameData::Ability.get(id).name` | `ability_name(id)` |
| `PBNatures.getName(id)` | `GameData::Nature.get(id).name` | `nature_name(id)` |
| `PBStats.getName(s)` | `GameData::Stat.get(s).name` | `stat_name(s)` |
| `PBMoveData.new(id).type` | `GameData::Move.get(id).type` | `move_type_name(id)` |
| `PBMoveData.new(id).basedamage` | `GameData::Move.get(id).power` | `move_power(id)` |
| `PBMoveData.new(id).accuracy` | `GameData::Move.get(id).accuracy` | `move_accuracy(id)` |
| `pbGetMessage(MoveDescriptions, id)` | `GameData::Move.get(id).description` | `move_description(id)` |

## MoveInfo: detalle hablado de un movimiento

**Archivo**: `core/battle/move_info.rb`

`PokeAccess::MoveInfo` centraliza el formateo del detalle de un movimiento para que todos los lectores de
movimientos (combate, relearner, tutores de huevo, página de movimientos del resumen) hablen la misma línea.

- `MoveInfo.power_phrase(pw)` — "sin daño" si el poder es <= 0, "variable" si es 1 (daño fijo o por nivel),
  si no el número. Textos vía `PokeAccess::I18n.t`.
- `MoveInfo.accuracy_phrase(acc)` — "nunca falla" si <= 0 (el centinela "siempre acierta" del motor), si no
  el valor.
- `MoveInfo.line(name, type_name, power, accuracy, opts = {})` — arma
  "nombre. tipo. poder. precisión[. pp][. descripción]" a partir de partes ya resueltas. Opciones: `:pp` y
  `:total_pp` (ambos requeridos para hablar los PP) y `:desc`. Un poder o precisión **nil** significa "sin
  resolver" y omite su frase: solo un 0 real dice "sin daño" / "nunca falla".

Dos resolutores por id:

```ruby
# Resuelve vía GameData directamente (compartido por v21 y v22). nil si el id no resuelve.
PokeAccess::MoveInfo.by_id(id)

# Resuelve a través del adaptador Data por-motor (PBMoveData en gen-6, GameData en moderno),
# para que un lector gen-6 también reciba la línea completa. Lo usa el move relearner de gen-6,
# cuyos ids son enteros PBMove planos.
PokeAccess::MoveInfo.by_id_via_data(id)
```

`by_id_via_data` encadena `Data.move_name` / `move_type_name` / `move_power` / `move_accuracy` /
`move_description` y devuelve nil si el nombre resuelve a vacío. Es el motivo por el que gen-6 SÍ expone
poder/precisión/tipo de un movimiento (vía `PBMoveData.new(id)`), no solo el moderno.

## Referencias

- [Data Module](../core/data/data.rb)
- [Gen-6 Provider](../core/data/gen6/data_g6.rb)
- [GameData Provider](../core/data/v21/data_v21.rb)
- [Fallback](../core/data/data_fallback.rb)
- [MoveInfo](../core/battle/move_info.rb)

## Próximo

- [Pathfinding](06_PATHFINDING.md) - Navegación por rutas
- [Audio3D](07_AUDIO3D.md) - Sonido posicional
