# Revival's pause menu (games/revival/pause_menu.rb), its edited copy of Luka's Modular Menu, gamedata pass: the lit
# button as the menu's loop moves it, queued as it opens, and again on the way back from what an entry opened.

# The Modular Menu's scene as Revival's copy keeps it: the entries shown (@entries, by key) and the lit one (@index);
# pbStartScene builds them and ends on an update, as refresh and update draw the buttons.
class RevivalModularSceneStandIn
  attr_accessor :index, :entries

  def initialize(entries, index = 0)
    @shown = entries
    @start = index
  end

  def pbStartScene
    @index = @start
    @entries = @shown
    update
  end

  def update; @index; end
end

# The menu's loop (PokemonPauseMenu#pbStartPokemonMenu): an update each frame, then the press handed for that frame
# moves the lit button, runs its entry (the block given) or, with none left, closes the menu.
class RevivalModularMenuStandIn
  def initialize(scene, presses, &entry)
    @scene = scene
    @presses = presses
    @entry = entry
  end

  def pbStartPokemonMenu
    @scene.pbStartScene
    loop do
      @scene.update
      case @presses.shift
      when :down then @scene.index = (@scene.index + 1) % @scene.entries.length
      when :up then @scene.index = (@scene.index - 1) % @scene.entries.length
      when :use then @entry.call if @entry
      else break
      end
    end
    :closed
  end
end

# The entries Revival's Config registers, by key, with the names their buttons paint.
module RevivalModularEntriesStandIn
  NAMES = { :POKEMON => "Pokémon", :BAG => "Mochila", :PHS => "PHS", :Mapa => "Mapa regional", :SAVE => "Guardar" }

  def self.name(ref); NAMES[ref]; end
end

class RevivalPauseMenuGdTest < PokeAccessTest
  PATH = File.join(Harness::ROOT, "games", "revival", "pause_menu.rb")
  # The game classes pause_menu.rb hooks, bound afresh for each test, and the module whose names it reads.
  SCENES = { "PokemonPauseMenu_Scene" => RevivalModularSceneStandIn, "PokemonPauseMenu" => RevivalModularMenuStandIn }
  NAMED = SCENES.keys + ["ModularMenu"]
  ENTRIES = [:POKEMON, :BAG, :PHS, :Mapa, :SAVE]

  test "the pause menu says its lit button with its place, queued, as it opens, and each move at once" do
    with_menu { assert_equal :closed, run_menu([:down, :down, :up]) }
    want = [[button("Pokémon", 1), false], [button("Mochila", 2), true], [button("PHS", 3), true],
            [button("Mochila", 2), true]]
    assert_equal want, SpeakCapture.log
  end

  test "the pause menu opens on the button chosen last, as the game keeps it" do
    with_menu { run_menu([], 3) }
    assert_equal [[button("Mapa regional", 4), false]], SpeakCapture.log
  end

  test "back from what an entry opened the lit button is said again" do
    with_menu do
      run_menu([:down, :use]) do
        PokeAccess::MenuReturn.enter!
        PokeAccess::MenuReturn.leave!
      end
    end
    assert_equal [[button("Pokémon", 1), false], [button("Mochila", 2), true], [button("Mochila", 2), false]],
                 SpeakCapture.log
  end

  test "a return once the menu is closed says nothing" do
    with_menu do
      run_menu([])
      SpeakCapture.clear
      PokeAccess::MenuReturn.enter!
      PokeAccess::MenuReturn.leave!
    end
    assert_nothing_spoken
  end

  private

  # Runs the menu over the presses, opening on the button at index; an entry the presses use runs the block.
  def run_menu(presses, index = 0, &entry)
    PokemonPauseMenu.new(PokemonPauseMenu_Scene.new(ENTRIES, index), presses, &entry).pbStartPokemonMenu
  end

  # Runs the block with pause_menu.rb bound to a fresh subclass of each stand-in under its game name and ModularMenu
  # naming the entries; the classes, their hook chains, the return listeners and the profile list are put back after.
  def with_menu
    chains = PokeAccess::Hooks.instance_variable_get(:@chains)
    ours = lambda { |key| SCENES.key?(key.split("#", 2)[0]) }
    kept_chains = chains.select { |key, _v| ours.call(key) }
    kept = NAMED.map { |n| [n, Object.const_defined?(n, false) ? Object.const_get(n, false) : nil] }
    listeners = PokeAccess::MenuReturn.instance_variable_get(:@listeners)
    count = listeners.length
    profiles = PokeAccess::Game.profiles.dup
    chains.delete_if { |key, _v| ours.call(key) }
    NAMED.each { |n| Object.send(:remove_const, n) if Object.const_defined?(n, false) }
    SCENES.each { |n, base| Object.const_set(n, Class.new(base)) }
    Object.const_set(:ModularMenu, RevivalModularEntriesStandIn)
    eval(Harness.source(PATH), TOPLEVEL_BINDING, PATH)
    PokeAccess::MenuReturn.reset_nesting
    yield
  ensure
    if kept_chains
      chains.delete_if { |key, _v| ours.call(key) }
      chains.update(kept_chains)
    end
    (kept || []).each do |n, k|
      Object.send(:remove_const, n) if Object.const_defined?(n, false)
      Object.const_set(n, k) if k
    end
    listeners.slice!(count..-1) if listeners
    PokeAccess::Game.instance_variable_set(:@profiles, profiles) if profiles
    PokeAccess::Game.instance_variable_set(:@profile_name, nil)
  end

  # A button as the menu says it: its words with its place among the five shown.
  def button(name, n)
    PokeAccess::I18n.t(:list_entry, :name => name, :n => n, :tot => ENTRIES.length)
  end
end
