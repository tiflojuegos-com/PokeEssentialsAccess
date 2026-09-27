# The Destiny Tower roguelike's graphic-only state (ArcyGame): the floor card, the Arceus quiz's hearts and clue
# board, the plate delivery, the dungeon map's mode and the starter's presentation.
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

    # Announces the plate handed over with its description (pick_plate_descriptions) when @translate is on; off, the
    # scene names nothing and shows the inscription in the Unown font alone, so that is all that is said.
    def self.plate(scene, plate)
      return PokeAccess.speak(PokeAccess::I18n.t(:rel_plate_unown), true) unless PokeAccess.ivar(scene, :@translate)
      desc = (scene.pick_plate_descriptions(plate) rescue nil)
      line = PokeAccess.clean((desc.is_a?(Array) ? desc[0] : desc).to_s)
      name = (PokeAccess::Data.item_name(plate) rescue nil)
      parts = []
      parts.push(name.to_s) if name && !name.to_s.empty?
      parts.push(line) unless line.empty?
      return if parts.empty?
      PokeAccess.speak(parts.join(". "), true)
    rescue StandardError
      nil
    end

    # Announces the dungeon map's mode after AUX1 switches it ($layoutStage: 0 small, 1 large, 2 hidden).
    def self.layout(_scene)
      st = ($layoutStage.to_i rescue nil)
      return if st.nil?
      key = [:rel_map_small, :rel_map_large, :rel_map_off][st] || :rel_map_small
      PokeAccess.speak(PokeAccess::I18n.t(key), true)
    rescue StandardError
      nil
    end

    # The starter's presentation (ShowStarterPokemon): its help line naming the Pokemon, queued as main_loop waits,
    # and the shiny its sprite shows, from the Pokemon kept as the scene was built.
    def self.starter(scene)
      t = PokeAccess.clean((PokeAccess.sprite(scene, "helpwindow").text rescue "").to_s)
      pk = PokeAccess.ivar(scene, :@pa_starter)
      shiny = pk && PokeAccess::Party.shiny?(pk) ? PokeAccess::I18n.t(:pk_shiny_hatch) : nil
      line = [t, shiny].compact.reject { |p| p.empty? }.join(" ")
      PokeAccess.speak(line, false) unless line.empty?
    rescue StandardError
      nil
    end

    # Announces the hearts left, once per change.
    def self.hearts(scene)
      n = PokeAccess.ivar(scene, :@currentlives)
      return if n.nil?
      return if PokeAccess.ivar(scene, :@pa_lives) == n
      scene.instance_variable_set(:@pa_lives, n)
      PokeAccess.speak(PokeAccess::I18n.t(:rel_lives, :n => n.to_i), false)
    rescue StandardError
      nil
    end

    # Keeps the clue board addTips paints (every clue so far, two to a row) for the info key while its quiz is on
    # screen, without speaking it.
    def self.board(scene, pairs)
      lines = PokeAccess::PaintCapture.lines(pairs)
      return if lines.empty?
      @board = [scene, lines.join(" ")]
      PokeAccess::Info.set_info(:text, @board[1])
    rescue StandardError
      nil
    end

    # The clue board while its quiz's viewport is live, else nil.
    def self.board_text
      scene, text = @board
      vp = scene && PokeAccess.ivar(scene, :@viewport)
      (vp && !(vp.disposed? rescue true)) ? text : nil
    end

    # Lets go of the clue board as the quiz closes.
    def self.close_board
      @board = nil
      PokeAccess::Info.clear_text
    end
  end
end

PokeAccess::Game.define("relict") do
  # Before setup for both cards, since setup is the whole presentation (the card is gone when it returns).
  before("NextFloor", :setup) { |s, _a| PokeAccess::RelictArcy.floor(s) }
  after("ArcyContest", :updateHearts) { |s, _r, _a| PokeAccess::RelictArcy.hearts(s) }
  before("ArcyContest", :pick_question) { |s, _a| PokeAccess::RelictArcy.hearts(s) }
  around("ArcyContest", :addTips) do |s, nxt, _a|
    ret = nil
    PokeAccess::RelictArcy.board(s, PokeAccess::PaintCapture.sample { ret = nxt.call })
    ret
  end
  before("ArcyContest", :dispose) { |_s, _a| PokeAccess::RelictArcy.close_board }
  # The quiz runs over the map, whose frames under its messages would hand the info key back to the trainer.
  override("PokeAccess::Locator", :refresh_info) do |_mod, original, _args|
    t = PokeAccess::RelictArcy.board_text
    (t && !PokeAccess::CommandHelp.current) ? PokeAccess::Info.set_info(:text, t) : original.call
  end
  before("GivePlateMessage", :setup) { |s, args| PokeAccess::RelictArcy.plate(s, args[0]) }
  kernel("rewriteDungeonLayoutAll", :after) { |_a, _r| PokeAccess::RelictArcy.layout(nil) }
  before("ShowStarterPokemon", :initialize, :optional => true) { |s, args| s.instance_variable_set(:@pa_starter, args[0]) }
  before("ShowStarterPokemon", :main_loop, :optional => true) { |s, _a| PokeAccess::RelictArcy.starter(s) }
end
