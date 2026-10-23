# ChampChar13's Modular Pokemon Selection (ModularSelection_Scene): a carousel of Pokemon icons and one card for the
# focused one (@pokemon at @index), painted again by drawPage on every move. The card is read from what drawPage paints,
# in reading order, with the types from the Pokemon (they are icons); its confirmation is the game's own message.
module PokeAccess
  module ModularSelection
    TAG = :modular_selection

    # Runs drawPage with its paint armed, then reads the card it painted.
    def self.draw(scene)
      PokeAccess::PaintCapture.arm(TAG)
      yield
    ensure
      read(scene, PokeAccess::PaintCapture.laid_out(PokeAccess::PaintCapture.take_pairs(TAG)))
    end

    # The card as parts at the level each is said from: the name, the types, then the rest it paints in reading order.
    def self.parts(pk, painted)
      name = (pk.name rescue nil).to_s
      rest = painted.map { |t| t.to_s }
      i = rest.index(name)
      rest.delete_at(i) if i
      types = PokeAccess::Data.pokemon_types(pk)
      typed = types.empty? ? "" : PokeAccess::I18n.t(:mv_type, :t => types.join("/"))
      [[name, :brief], [typed, :medium], [PokeAccess::PaintCapture.text(rest, false), :full]]
    end

    # Says the focused Pokemon when the carousel moves (the first, behind what the screen opened with), and keeps its
    # whole card for the info key and Ctrl+T.
    def self.read(scene, painted)
      pk = PokeAccess.ivar(scene, :@pokemon)
      return if pk.nil?
      parts = parts(pk, painted)
      PokeAccess::Info.set_info(:pokemon, pk, PokeAccess::Verbosity.full_line(parts))
      PokeAccess::Cursor.announce(scene, :modular_selection, PokeAccess.ivar(scene, :@index), true, false) do
        PokeAccess::Verbosity.line(:pokemon_choice, parts)
      end
    rescue StandardError => e
      PokeAccess.swallowed(e)
      nil
    end
  end
end

PokeAccess::Hooks.around_hook("ModularSelection_Scene", :drawPage, :optional => true) do |scene, nxt, _a|
  PokeAccess::ModularSelection.draw(scene) { nxt.call }
end

PokeAccess::Verbosity.define_reading(:pokemon_choice, :vb_pokemon_choice, :vbh_pokemon_choice, :pokemon)
