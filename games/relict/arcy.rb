# Two small pieces of the Destiny Tower roguelike (997_Addons/ArcyGame) whose state exists only as graphics.
#
# NextFloor is the card shown between floors. It is not interactive, but it is the ONLY place the game says
# which floor you are on, and it paints it into a bitmap -- so without this the run has no sense of depth.
# The floor number is the same one the card composes, $PokemonGlobal.dungeonFloor + 1.
#
# ArcyContest is the Arceus quiz. Its questions already go through pbMessage (covered), but the remaining
# attempts are drawn as heart sprites, so a wrong answer gave no clue how close the run was to ending.
# updateHearts runs whenever that display is rebuilt, which is exactly when the count changed.
module PokeAccess
  module RelictArcy
    # Announces the floor the card is showing.
    def self.floor(_scene)
      n = ($PokemonGlobal.dungeonFloor.to_i + 1 rescue nil)
      return if n.nil?
      PokeAccess.speak(PokeAccess::I18n.t(:rel_floor, :n => n), true)
    rescue StandardError
      nil
    end

    # Announces the plate being handed over and what it does. The screen draws its description twice -- first
    # in the Unown font, then translated -- into a bitmap, so nothing reached the reader; the text itself
    # comes from the scene's own pick_plate_descriptions, which is what it paints.
    # La descripcion solo si la pantalla la TRADUCE. Con @translate a false la unica pasada que se dibuja
    # es la de la fuente Unown, que es precisamente el texto que el guion dice que nadie sabe leer todavia:
    # leerlo en claro adelanta la entrega entera. El nombre de la Losa si se dice, que eso si se ve.
    def self.plate(scene, plate)
      translated = PokeAccess.ivar(scene, :@translate)
      desc = translated ? (scene.pick_plate_descriptions(plate) rescue nil) : nil
      line = (desc.is_a?(Array) ? desc[0] : desc).to_s
      line = PokeAccess.clean(line).to_s.strip
      name = (PokeAccess::Data.item_name(plate) rescue nil)
      parts = []
      parts.push(name.to_s) if name && !name.to_s.empty?
      parts.push(line) unless line.empty?
      return if parts.empty?
      PokeAccess.speak(parts.join(". "), true)
    rescue StandardError
      nil
    end

    # Announces which of the three dungeon-map states AUX1 just switched to. The map itself is a grid of dots
    # with no text, so at least the mode is now knowable; 0 is the small map, 1 the large one and 2 hides it.
    def self.layout(_scene)
      st = ($layoutStage.to_i rescue nil)
      return if st.nil?
      key = [:rel_map_small, :rel_map_large, :rel_map_off][st] || :rel_map_small
      PokeAccess.speak(PokeAccess::I18n.t(key), true)
    rescue StandardError
      nil
    end

    # Announces the lives left, once per change.
    def self.hearts(scene)
      n = PokeAccess.ivar(scene, :@currentlives)
      return if n.nil?
      return if PokeAccess.ivar(scene, :@pa_lives) == n
      scene.instance_variable_set(:@pa_lives, n)
      PokeAccess.speak(PokeAccess::I18n.t(:rel_lives, :n => n.to_i), false)
    rescue StandardError
      nil
    end
  end
end

PokeAccess::Game.define("relict") do
  # Before, not after, for both cards: setup IS the presentation -- it composes the text, fades the card in,
  # waits and disposes -- so an after-hook read it out with the card already gone. Neither reader needs
  # anything the call produces: the floor is the global counter and the plate is the argument.
  before("NextFloor", :setup) { |s, _a| PokeAccess::RelictArcy.floor(s) }
  after("ArcyContest", :updateHearts) { |s, _r, _a| PokeAccess::RelictArcy.hearts(s) }
  before("GivePlateMessage", :setup) { |s, args| PokeAccess::RelictArcy.plate(s, args[0]) }
  kernel("rewriteDungeonLayoutAll", :after) { |_a, _r| PokeAccess::RelictArcy.layout(nil) }
end
