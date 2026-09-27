module PokeAccess
  # The frontier rental list (BattleSwapScene, same in every era): a rented row, marked only in red, is said as chosen;
  # the title as the list first opens, and a changed help line after the next row read.
  module BattleSwapList
    # Remembers the scene whose list is being navigated, for the length of one pbChoosePokemon; the title the first
    # time, and a changed help line kept for the next row read.
    def self.watch(scene)
      @scene = scene
      say_title(scene)
      note_help(scene)
    end

    def self.stop; @scene = nil; end

    # The row's generic text, plus the chosen mark when it is one of the watched scene's rented choices, and the
    # help line when one is due.
    def self.row(win, i)
      base = PokeAccess::Menus.generic_focus(win, i)
      base = "#{base}, #{PokeAccess::I18n.t(:swap_chosen)}" if base && chosen?(win, i)
      help = due_help(win)
      help ? PokeAccess.sentences([base, help]) : base
    end

    def self.chosen?(win, i)
      return false unless @scene && win.equal?(PokeAccess.sprite(@scene, "list"))
      choices = PokeAccess.ivar(@scene, :@choices)
      choices.is_a?(Array) && choices.include?(i)
    end

    # The cleaned text of one of the scene's text windows ("title", "help"), or "".
    def self.box_text(scene, key)
      box = PokeAccess.sprite(scene, key)
      box ? PokeAccess.clean((box.text rescue "").to_s) : ""
    end

    # Queues the title ("RENTAL POKéMON", "POKéMON SWAP") once per scene.
    def self.say_title(scene)
      return if PokeAccess.ivar(scene, :@access_swap_titled)
      scene.instance_variable_set(:@access_swap_titled, true)
      t = box_text(scene, "title")
      PokeAccess.speak(t, false) unless t.empty?
    end

    # Marks the help line due when it differs from the last one said.
    def self.note_help(scene)
      t = box_text(scene, "help")
      return if t.empty? || t == PokeAccess.ivar(scene, :@access_swap_help_said)
      scene.instance_variable_set(:@access_swap_help_due, t)
    end

    # The watched list's due help line, taken (marked said), or nil.
    def self.due_help(win)
      return nil unless @scene && win.equal?(PokeAccess.sprite(@scene, "list"))
      t = PokeAccess.ivar(@scene, :@access_swap_help_due)
      return nil if t.nil?
      @scene.instance_variable_set(:@access_swap_help_due, nil)
      @scene.instance_variable_set(:@access_swap_help_said, t)
      t
    end
  end
end

# Around: pbChoosePokemon is the list's own loop, and the scene is only watched while it runs.
PokeAccess::Hooks.around_hook("BattleSwapScene", :pbChoosePokemon, :optional => true) do |scene, nxt, _a|
  PokeAccess::BattleSwapList.watch(scene)
  begin
    nxt.call
  ensure
    PokeAccess::BattleSwapList.stop
  end
end

PokeAccess::Menus.def_extractor("Window_AdvancedCommandPokemonEx") { |win, i| PokeAccess::BattleSwapList.row(win, i) }
