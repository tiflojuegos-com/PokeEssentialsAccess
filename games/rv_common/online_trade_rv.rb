module PokeAccess
  # The online trade of the engine Reborn and Desolation share (Scene_Trade; Rejuvenation has none): offering a party
  # member paints its card on the player's half of the screen (show_information: name, level, held item, sex sign, the
  # four moves, ability, and its type pictures beside the name), of which Reborn's own reader, relayed on this screen,
  # says only the level and the name. The card is said in place of that line, as a Pokemon choice: the name, then the
  # types from medium, the rest in full.
  module OnlineTradeRV
    # Where show_information draws the first type picture, beside the name: the card says the types there.
    TYPES_AT = [186, 4]

    @painting = false

    # True while the card is painted, its own line held back from the relay.
    def self.painting?; @painting; end

    # The party member the selector is on, the one offered.
    def self.offered(scene)
      idx = PokeAccess.ivar(scene, :@index)
      idx.is_a?(Integer) && idx >= 1 ? (PokeAccess::Engine.player.party[idx - 1] rescue nil) : nil
    end

    # The card as [text, level] parts: what it paints top to bottom, the types beside the name, the empty move slots
    # left out; the name said from brief, the types from medium, the rest in full.
    # param pairs the rows the card painted, as PaintCapture.sample gives them
    def self.card(pairs, pk)
      rows = pairs.reject { |r| PokeAccess::Menus.placeholder?(PokeAccess.clean(r[0])) }
      types = PokeAccess::DataRV.pokemon_types(pk)
      typed = types.empty? ? nil : PokeAccess::I18n.t(:pc_types, :t => types.join(" "))
      rows += [[typed, :types, TYPES_AT[0], TYPES_AT[1]]] if typed
      said = PokeAccess::PaintCapture.laid_out(rows).map { |t| PokeAccess.clean(t) }.reject { |t| t.empty? }
      name = said.index(PokeAccess.clean(pk.name.to_s))
      said.each_with_index.map { |t, i| [t, i == name ? :brief : (t == typed ? :medium : :full)] }
    rescue StandardError => e
      PokeAccess.swallowed(e)
      []
    end

    # Paints the card with the game's own line about it held back, then says what it painted at the Pokemon choice's
    # level, cutting in, and keeps it whole on the info key and Ctrl+T. An egg's card paints nothing, and the game's
    # line is left to the relay.
    def self.read(scene)
      pk = offered(scene)
      return yield if pk.nil? || PokeAccess::Summary.egg?(pk)
      r = nil
      @painting = true
      begin
        pairs = PokeAccess::PaintCapture.sample { r = yield }
      ensure
        @painting = false
      end
      parts = card(pairs, pk)
      PokeAccess.speak(PokeAccess::Verbosity.info_line(:pokemon_choice, parts, ", "), true) unless parts.empty?
      r
    end

    # Hooks the card where the game has the screen and, only there, declares its reading and holds back from the relay
    # of the game's reader (Reborn's; Desolation's relay is never installed) the line the game hands it while the card
    # paints.
    def self.bind
      took = PokeAccess::Hooks.around_hook("Scene_Trade", :show_information, :optional => true) do |scene, nxt, _a|
        PokeAccess::OnlineTradeRV.read(scene) { nxt.call }
      end
      return unless took
      PokeAccess::Verbosity.define_reading(:pokemon_choice, :vb_pokemon_choice, :vbh_pokemon_choice, :pokemon)
      PokeAccess::Hooks.override("PokeAccess::OwnVoiceRV", :relay, :tag => "rv_common") do |_mod, original, _args|
        PokeAccess::OnlineTradeRV.painting? ? nil : original.call
      end
    end
  end
end

PokeAccess::OnlineTradeRV.bind if PokeAccess::DataRV.engine?
