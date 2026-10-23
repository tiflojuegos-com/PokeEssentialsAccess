# The party panel inside the bag ("Bag screen with interactable party" addon): each member as its panel draws it, the
# focused one read while a selection loop runs, and the word each panel writes for the item the list is on.

# A panel as the addon draws it: its Pokemon, and the word pbUpdateAnnotation writes in place of its HP.
class BagAnnotationPanel
  attr_accessor :text
  def initialize(pk, text = nil); @pokemon = pk; @text = text; end
end

# The bag's item list: the item its cursor is on.
class BagAnnotationList
  attr_accessor :item
end

# The addon's bag scene, put under the game's name while its hooks bind: each loop (pbChoosePoke, pbChoosePokemon,
# pbChooseItem) runs the frames the test hands it in loops, and pbUpdateAnnotation writes on every panel the word its
# words table gives the focused item.
class BagAnnotationScene
  attr_accessor :words
  attr_reader :loops

  def initialize(panels)
    @panels = panels
    @sprites = { "itemlist" => BagAnnotationList.new }
    panels.each_with_index { |p, i| @sprites["pokemon#{i}"] = p }
    @words = {}
    @loops = {}
  end

  def list; @sprites["itemlist"]; end
  def pbChoosePoke(*_a); run_loop(:pbChoosePoke); end
  def pbChoosePokemon(*_a); run_loop(:pbChoosePokemon); end
  def pbChooseItem(*_a); run_loop(:pbChooseItem); end
  def run_loop(name); @loops[name] ? @loops[name].call(self) : nil; end

  # The selection cursor on panel i (nil, or anything that is no panel, as the screen leaves it between loops).
  def select(i); @activecmd = i; end

  # One frame of the item loop: the list's cursor on item, then the annotation pass that frame runs.
  def focus(item)
    list.item = item
    pbUpdateAnnotation
  end

  def pbUpdateAnnotation
    words = @words[list.item] || []
    @panels.each_with_index { |p, i| p.text = words[i] }
  end
end

class BagPartyPanelGdTest < PokeAccessTest
  T = PokeAccess::I18n
  BAG = PokeAccess::BagParty
  PATH = File.join(Harness::ROOT, "plugins", "bag_screen_party.rb")
  HOOK_BLOCK = /^PokeAccess::Hooks\.around_hook\("PokemonBag_Scene".*?^end\r?\n/m
  BOUND = {}
  MALE = " ♂"
  ABLE = ["APTO", "NO APTO", "APTO"].freeze
  GROUPS = "APTO: Pika, Squi. NO APTO: Bulbi"

  test "says a member with every icon its panel draws, the star once and the cured pokerus as its own icon" do
    with_switches(true, true) do
      assert_equal [member("Pika", 20, 30, 50), "StatusPOISON", T.t(:pk_shiny), T.t(:pty_item), T.t(:pk_pokerus_cured)].join(", "),
                   BAG.member(marked(2), nil)
    end
  end

  test "keeps the state under an annotation, which takes the place of the HP" do
    with_switches(true, true) do
      assert_equal [T.t(:pty_head, :name => "Pika, Species1", :sex => MALE, :level => 20), "StatusPOISON", T.t(:pk_shiny), T.t(:pty_item),
                    T.t(:pk_pokerus_cured), "APTO"].join(", "),
                   BAG.member(marked(2), "APTO")
    end
  end

  test "says a catching infection once, as the panel's own icon and not in the state slot" do
    with_switches(true, true) do
      assert_equal [member("Pika", 20, 30, 50), T.t(:pk_pokerus)].join(", "), BAG.member(staged(plain("Pika", 20, 30, 50), 1), nil)
    end
  end

  test "draws neither star nor pokerus with its switches off" do
    with_switches(false, false) do
      [1, 2].each do |stage|
        assert_equal [member("Pika", 20, 30, 50), "StatusPOISON", T.t(:pty_item)].join(", "), BAG.member(marked(stage), nil),
                     "pokerus stage #{stage}"
      end
    end
  end

  test "draws no pokerus for a Pokemon that has no pokerus stage" do
    with_switches(true, true) do
      assert_equal member("Pika", 20, 30, 50), BAG.member(plain("Pika", 20, 30, 50), nil)
    end
  end

  test "in the older release without switches, draws the star and puts a catching infection in the state slot" do
    shiny = lambda { |stage| staged(Poke.build(:name => "Pika", :level => 20, :hp => 30, :totalhp => 50, :shiny => true), stage) }
    with_older_release do
      assert_equal [member("Pika", 20, 30, 50), T.t(:pk_pokerus), T.t(:pk_shiny)].join(", "), BAG.member(shiny.call(1), nil),
                   "a catching infection"
      assert_equal [member("Pika", 20, 30, 50), T.t(:pk_shiny)].join(", "), BAG.member(shiny.call(2), nil),
                   "a cured one, which that release draws no icon for"
    end
  end

  test "never says the game's Exp. Share icon, which no release of the panel draws" do
    pk = plain("Pika", 20, 30, 50)
    pk.define_singleton_method(:expshare) { true }
    with_switches(true, true) { assert_equal member("Pika", 20, 30, 50), BAG.member(pk, nil), "the release with switches" }
    with_older_release { assert_equal member("Pika", 20, 30, 50), BAG.member(pk, nil), "the older release" }
  end

  test "says an egg as an egg, with the panel's annotation after it" do
    egg = Poke.build(:name => "Pichu", :shiny => true)
    def egg.egg?; true; end
    with_switches(true, true) do
      assert_equal T.t(:pty_egg), BAG.member(egg, nil)
      assert_equal "#{T.t(:pty_egg)}, NO APTO", BAG.member(egg, "NO APTO")
    end
  end

  test "reads the focused member while a selection loop runs, interrupting" do
    scene = team_scene
    bound do
      scene.loops[:pbChoosePoke] = lambda do |s|
        [0, 2].each { |i| s.select(i); BAG.poll }
      end
      scene.pbChoosePoke
    end
    assert_equal [[member("Pika", 20, 30, 50), true], [member("Squi", 15, 25, 40), true]], SpeakCapture.log
  end

  test "says a member once while the cursor rests on it" do
    scene = team_scene
    bound do
      scene.loops[:pbChoosePoke] = lambda { |s| s.select(1); 3.times { BAG.poll } }
      scene.pbChoosePoke
    end
    assert_equal [[member("Bulbi", 12, 20, 30), true]], SpeakCapture.log
  end

  test "keeps the focused member whole for the info key and Ctrl+T at any verbosity" do
    scene = team_scene
    PokeAccess::Config.verbosity = :brief
    bound do
      scene.loops[:pbChoosePoke] = lambda { |s| s.select(0); BAG.poll }
      scene.pbChoosePoke
    end
    assert_equal [[T.t(:pty_member_nolv, :name => "Pika", :sex => "", :hp => 30, :tot => 50), true]], SpeakCapture.log,
                 "brief says the name and HP"
    assert_equal member("Pika", 20, 30, 50), PokeAccess::Info.row_text, "Ctrl+T says the whole panel"
    assert_equal "#{T.t(:pk_glance, :name => 'Pika', :level => 20, :hp => 30, :tot => 50)}#{MALE}.", PokeAccess::Info.info_text,
                 "the info key reads the focused Pokemon"
  end

  test "stops reading once the selection loop returns" do
    scene = team_scene
    bound do
      scene.loops[:pbChoosePoke] = lambda { |s| s.select(0); BAG.poll }
      scene.pbChoosePoke
      SpeakCapture.clear
      scene.select(1)
      BAG.poll
    end
    assert_nothing_spoken
  end

  test "keeps reading the outer selection loop after the fusion picker inside it returns" do
    scene = team_scene
    bound do
      scene.loops[:pbChoosePokemon] = lambda { |s| s.select(0); BAG.poll }
      scene.loops[:pbChoosePoke] = lambda do |s|
        s.pbChoosePokemon
        s.select(1)
        BAG.poll
      end
      scene.pbChoosePoke
    end
    assert_equal [[member("Pika", 20, 30, 50), true], [member("Bulbi", 12, 20, 30), true]], SpeakCapture.log
  end

  test "reads the member a loop opens on, though the party screen last said that same one" do
    scene = team_scene
    PokeAccess::UIV21.speak_changed(:party, member("Pika", 20, 30, 50), 0)
    SpeakCapture.clear
    bound do
      scene.loops[:pbChoosePoke] = lambda { |s| s.select(0); BAG.poll }
      scene.pbChoosePoke
    end
    assert_equal [[member("Pika", 20, 30, 50), true]], SpeakCapture.log
  end

  test "leaves the party screen free to say a member again once the loop returns" do
    scene = team_scene
    bound do
      scene.loops[:pbChoosePoke] = lambda { |s| s.select(0); BAG.poll }
      scene.pbChoosePoke
    end
    SpeakCapture.clear
    PokeAccess::UIV21.speak_changed(:party, member("Pika", 20, 30, 50), 0)
    assert_equal [[member("Pika", 20, 30, 50), true]], SpeakCapture.log
  end

  test "reads nothing where the selection cursor is on no member" do
    blank = BagAnnotationPanel.new(nil)
    scene = BagAnnotationScene.new([BagAnnotationPanel.new(plain("Pika", 20, 30, 50)), blank])
    bound do
      scene.loops[:pbChoosePoke] = lambda do |s|
        [nil, -1, "0", 1, 2].each { |i| s.select(i); BAG.poll }
      end
      scene.pbChoosePoke
    end
    assert_nothing_spoken "no index, a negative or a non-integer one, a blank panel, past the panels"
  end

  test "survives a focused member it cannot read, saying nothing" do
    scene = BagAnnotationScene.new([BagAnnotationPanel.new(unreadable)])
    bound do
      scene.loops[:pbChoosePoke] = lambda { |s| s.select(0); BAG.poll }
      scene.pbChoosePoke
    end
    assert_nothing_spoken
  end

  test "survives a panel it cannot read in the item list, saying nothing for that item" do
    scene = BagAnnotationScene.new([BagAnnotationPanel.new(plain("Pika", 20, 30, 50)), BagAnnotationPanel.new(unreadable)])
    scene.words = { :TM26 => ["APTO", "APTO"] }
    assert_equal [], browsed(scene, [:TM26])
  end

  test "answers what the game's loops answer" do
    scene = team_scene
    bound do
      [:pbChoosePoke, :pbChoosePokemon, :pbChooseItem].each do |loop|
        scene.loops[loop] = lambda { |_s| loop }
        assert_equal loop, scene.send(loop), loop.to_s
      end
    end
  end

  test "says, queued after the row, who each word the panels write applies to, in team order" do
    assert_equal [[GROUPS, false]], browsed(team_scene, [:TM26])
  end

  test "says a machine once while it stays focused, and the next machine though its words are the same" do
    assert_equal [[GROUPS, false], [GROUPS, false]], browsed(team_scene, [:TM26, :TM26, :TM27])
  end

  test "says nothing for an item the panels write nothing for" do
    assert_equal [], browsed(team_scene, [:POTION])
  end

  test "leaves out a panel that writes no word, and names an egg as an egg" do
    egg = Poke.build(:name => "Pichu")
    def egg.egg?; true; end
    scene = BagAnnotationScene.new([BagAnnotationPanel.new(plain("Pika", 20, 30, 50)), BagAnnotationPanel.new(egg),
                                    BagAnnotationPanel.new(plain("Squi", 15, 25, 40))])
    scene.words = { :FIRESTONE => ["APTO", "NO APTO", ""] }
    assert_equal [["APTO: Pika. NO APTO: #{T.t(:pty_egg)}", false]], browsed(scene, [:FIRESTONE])
  end

  test "leaves out a panel with no Pokemon, whatever word it holds" do
    scene = BagAnnotationScene.new([BagAnnotationPanel.new(plain("Pika", 20, 30, 50)), BagAnnotationPanel.new(nil)])
    scene.words = { :TM26 => ["APTO", "NO APTO"] }
    assert_equal [["APTO: Pika", false]], browsed(scene, [:TM26])
  end

  test "says the annotations from the bag reading's medium level" do
    logs = vb_levels { browsed(team_scene, [:TM26]) }
    assert_equal [[], [[GROUPS, false]], [[GROUPS, false]]], logs, "brief, medium, full"
  end

  test "keeps the annotations with the item's row for Ctrl+T, at any verbosity" do
    PokeAccess::Config.verbosity = :brief
    scene = team_scene
    bound do
      scene.loops[:pbChooseItem] = lambda do |s|
        PokeAccess::Info.set_info(:text, "MT26", "MT26")
        s.focus(:TM26)
      end
      scene.pbChooseItem
    end
    assert_equal "MT26. #{GROUPS}", PokeAccess::Info.row_text
  end

  test "repeats nothing the panels already showed when the list comes back from an item's menu" do
    scene = team_scene
    browsed(scene, [:TM26])
    assert_equal [], browsed(scene, [:TM26])
  end

  test "a new bag screen says the item it opens on, though the last one said the same" do
    browsed(team_scene, [:TM26])
    assert_equal [[GROUPS, false]], browsed(team_scene, [:TM26])
  end

  test "says what the panels already show for the item the list opens on" do
    scene = team_scene
    bound do
      scene.focus(:TM26)
      scene.loops[:pbChooseItem] = lambda { |s| s.focus(:TM26) }
      scene.pbChooseItem
    end
    assert_equal [[GROUPS, false]], SpeakCapture.log
  end

  test "says nothing for the panels redrawn once the item loop has returned" do
    scene = team_scene
    bound do
      scene.loops[:pbChooseItem] = lambda { |s| s.focus(:TM26) }
      scene.pbChooseItem
      SpeakCapture.clear
      scene.focus(:TM27)
    end
    assert_nothing_spoken
  end

  test "says nothing for the panels of a screen whose item list is not the one browsed" do
    scene = team_scene
    other = team_scene
    bound do
      scene.focus(:TM26)
      scene.loops[:pbChooseItem] = lambda { |_s| other.focus(:TM26) }
      scene.pbChooseItem
    end
    assert_nothing_spoken "outside any item loop, and another screen's panels during one"
  end

  private

  # A party member's head as the panel writes it at full: name, the species its icon shows after the nickname (species
  # 1's), sign, level and HP.
  def member(name, level, hp, tot)
    T.t(:pty_member, :name => "#{name}, Species1", :sex => MALE, :level => level, :hp => hp, :tot => tot)
  end

  # A male Pokemon with no state, star or item.
  def plain(name, level, hp, tot)
    Poke.build(:name => name, :level => level, :hp => hp, :totalhp => tot)
  end

  # A Pokemon whose name the engine fails to give.
  def unreadable
    pk = plain("Pika", 20, 30, 50)
    def pk.name; raise "no name"; end
    pk
  end

  # pk answering pokerusStage with stage.
  def staged(pk, stage)
    pk.define_singleton_method(:pokerusStage) { stage }
    pk
  end

  # Pika poisoned, shiny and holding a berry, at the given pokerus stage.
  def marked(stage)
    staged(Poke.build(:name => "Pika", :level => 20, :hp => 30, :totalhp => 50, :status => :POISON, :shiny => true,
                      :item => :ORANBERRY), stage)
  end

  # A scene with Pika, Bulbi and Squi on its panels; each machine gets the words ABLE.
  def team_scene
    scene = BagAnnotationScene.new([BagAnnotationPanel.new(plain("Pika", 20, 30, 50)), BagAnnotationPanel.new(plain("Bulbi", 12, 20, 30)),
                                    BagAnnotationPanel.new(plain("Squi", 15, 25, 40))])
    scene.words = { :TM26 => ABLE, :TM27 => ABLE }
    scene
  end

  # What browsing items one frame each in scene's item loop says, with the hooks bound.
  def browsed(scene, items)
    SpeakCapture.clear
    bound do
      scene.loops[:pbChooseItem] = lambda { |s| items.each { |it| s.focus(it) } }
      scene.pbChooseItem
    end
    SpeakCapture.log.dup
  end

  # Runs the block with the addon's two switches set as given, restoring whatever was there.
  def with_switches(pkrs, shiny)
    made = !Object.const_defined?(:BagScreenWiInParty)
    Object.const_set(:BagScreenWiInParty, Module.new) if made
    saved = {}
    { :PKRSICON => pkrs, :SHINYICON => shiny }.each do |k, v|
      saved[k] = BagScreenWiInParty.const_defined?(k) ? [BagScreenWiInParty.const_get(k)] : nil
      BagScreenWiInParty.send(:remove_const, k) if saved[k]
      BagScreenWiInParty.const_set(k, v)
    end
    yield
  ensure
    saved.each do |k, v|
      BagScreenWiInParty.send(:remove_const, k)
      BagScreenWiInParty.const_set(k, v[0]) if v
    end
    Object.send(:remove_const, :BagScreenWiInParty) if made
  end

  # Runs the block with the addon's older release in place: its settings module has neither switch.
  def with_older_release
    had = Object.const_defined?(:BagScreenWiInParty) ? BagScreenWiInParty : nil
    Object.send(:remove_const, :BagScreenWiInParty) if had
    Object.const_set(:BagScreenWiInParty, Module.new)
    yield
  ensure
    Object.send(:remove_const, :BagScreenWiInParty)
    Object.const_set(:BagScreenWiInParty, had) if had
  end

  # Runs the block with the plugin's PokemonBag_Scene hooks on the stand-in under the game's name. A hook binds once
  # per class name and another spec binds pbChooseItem to a scene of its own, so whatever is bound under the name is
  # set aside and put back after, with the name; the plugin's hooks are bound the first time and their chains kept.
  def bound
    chains = PokeAccess::Hooks.instance_variable_get(:@chains)
    aside = {}
    chains.keys.grep(/\APokemonBag_Scene#/).each { |k| aside[k] = chains.delete(k) }
    held = Object.const_defined?(:PokemonBag_Scene) ? Object.const_get(:PokemonBag_Scene) : nil
    begin
      Object.send(:remove_const, :PokemonBag_Scene) if held
      Object.const_set(:PokemonBag_Scene, BagAnnotationScene)
      BOUND.empty? ? bind_plugin_hooks(chains) : chains.update(BOUND)
      yield
    ensure
      chains.keys.grep(/\APokemonBag_Scene#/).each { |k| chains.delete(k) }
      chains.update(aside)
      Object.send(:remove_const, :PokemonBag_Scene) if Object.const_defined?(:PokemonBag_Scene)
      Object.const_set(:PokemonBag_Scene, held) if held
    end
  end

  # Evaluates each PokemonBag_Scene hook block of the plugin at its own line, as the harness would load it, and keeps
  # the chains they bind in BOUND.
  def bind_plugin_hooks(chains)
    src = Harness.source(PATH)
    blocks = []
    src.scan(HOOK_BLOCK) { blocks.push([$&, $~.begin(0)]) }
    blocks.each { |code, at| eval(code, TOPLEVEL_BINDING, PATH, src[0, at].count("\n") + 1) }
    chains.each { |k, v| BOUND[k] = v if k =~ /\APokemonBag_Scene#/ }
  end
end
