# The party panel inside the bag ("Bag screen with interactable party" addon): each icon said once, the state kept
# under an annotation, the shiny star and its own pokerus icon only where its settings draw them.

module BagPanelSpec
  # Runs the block with the addon's two switches set as given, restoring whatever was there.
  def self.with(pkrs, shiny)
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
  def self.without
    had = Object.const_defined?(:BagScreenWiInParty) ? BagScreenWiInParty : nil
    Object.send(:remove_const, :BagScreenWiInParty) if had
    Object.const_set(:BagScreenWiInParty, Module.new)
    yield
  ensure
    Object.send(:remove_const, :BagScreenWiInParty)
    Object.const_set(:BagScreenWiInParty, had) if had
  end
end

Suite.define("bag party: each icon of its panel is said once, and its own pokerus icon as it draws it") do
  t = PokeAccess::I18n
  pk = Poke.build(:name => "Pika", :level => 20, :hp => 30, :totalhp => 50, :status => :POISON, :shiny => true, :item => :ORANBERRY)
  pk.define_singleton_method(:pokerusStage) { 2 }
  BagPanelSpec.with(true, true) do
    line = PokeAccess::BagParty.member(pk, nil)
    eq "shiny once", line.scan(t.t(:pk_shiny)).length, 1
    truthy "the cured pokerus the panel draws", line.include?(t.t(:pk_pokerus_cured))
    truthy "the item as the icon says it", line.include?(t.t(:pty_item))
    ann = PokeAccess::BagParty.member(pk, "APTO")
    falsy "an annotation hides the HP numbers", ann.include?("30")
    truthy "but this panel keeps the state under it", ann.include?(PokeAccess::Party.status_word(:POISON).to_s)
    catching = Poke.build(:name => "Pika", :level => 20, :hp => 30, :totalhp => 50)
    catching.define_singleton_method(:pokerusStage) { 1 }
    eq "a catching infection is its own icon, never the state slot as well",
       PokeAccess::BagParty.member(catching, nil).scan(t.t(:pk_pokerus)).length, 1
  end
  BagPanelSpec.with(false, false) do
    line = PokeAccess::BagParty.member(pk, nil)
    falsy "with its switches off it draws neither star nor pokerus", line.include?(t.t(:pk_shiny)) || line.include?(t.t(:pk_pokerus_cured))
  end
end

Suite.define("bag party: the older release draws the star and pokerus its own way, and no Exp. Share icon") do
  t = PokeAccess::I18n
  pk = Poke.build(:name => "Pika", :level => 20, :hp => 30, :totalhp => 50, :shiny => true)
  pk.define_singleton_method(:pokerusStage) { 1 }
  pk.define_singleton_method(:expshare) { true }
  BagPanelSpec.without do
    line = PokeAccess::BagParty.member(pk, nil)
    truthy "Soulstones 2's copy has no switches and always draws the star", line.include?(t.t(:pk_shiny))
    truthy "and puts a catching infection in the state slot", line.include?(t.t(:pk_pokerus))
  end
  BagPanelSpec.with(true, true) do
    falsy "no panel of the addon draws the game's Exp. Share icon", PokeAccess::BagParty.member(pk, nil).include?(t.t(:pty_expshare))
  end
end

# The panels as pbUpdateAnnotation leaves them: each with its Pokemon and the word it shows in place of its HP.
class BagAnnotationPanel
  attr_accessor :text
  def initialize(pk, text); @pokemon = pk; @text = text; end
end

class BagAnnotationList
  attr_accessor :item
end

# The bag's item loop as the addon's copy runs it: each frame of pbChooseItem focuses an item of the list, and
# pbUpdateAnnotation writes on every panel the word its words table gives for that item.
class BagAnnotationScene
  attr_accessor :browsed, :words
  def initialize(panels)
    @panels = panels
    @sprites = { "itemlist" => BagAnnotationList.new }
    panels.each_with_index { |p, i| @sprites["pokemon#{i}"] = p }
    @browsed = []
    @words = {}
  end

  def pbChooseItem
    @browsed.each do |item|
      @sprites["itemlist"].item = item
      pbUpdateAnnotation
    end
    @sprites["itemlist"].item
  end

  def pbUpdateAnnotation
    words = @words[@sprites["itemlist"].item] || []
    @panels.each_with_index { |p, i| p.text = words[i] }
  end
end

module BagPartyHooks
  PATH = File.join(Harness::ROOT, "plugins", "bag_screen_party.rb")

  # Runs the block with this repo's PokemonBag_Scene hooks of plugins/bag_screen_party.rb bound to the stand-in under
  # the game's name. A hook binds once per class name and Soulstones 2's bag spec binds pbChooseItem to a scene of its
  # own, so whatever is bound under the name is set aside and put back after, with the name.
  def self.bound
    chains = PokeAccess::Hooks.instance_variable_get(:@chains)
    aside = {}
    chains.keys.grep(/\APokemonBag_Scene#/).each { |k| aside[k] = chains.delete(k) }
    held = Object.const_defined?(:PokemonBag_Scene) ? Object.const_get(:PokemonBag_Scene) : nil
    begin
      Object.send(:remove_const, :PokemonBag_Scene) if held
      Object.const_set(:PokemonBag_Scene, BagAnnotationScene)
      eval(File.read(PATH).scan(/^PokeAccess::Hooks\.around_hook\("PokemonBag_Scene".*?^end\r?\n/m).join,
           TOPLEVEL_BINDING, PATH)
      yield
    ensure
      chains.keys.grep(/\APokemonBag_Scene#/).each { |k| chains.delete(k) }
      chains.update(aside)
      Object.send(:remove_const, :PokemonBag_Scene) if Object.const_defined?(:PokemonBag_Scene)
      Object.const_set(:PokemonBag_Scene, held) if held
    end
  end
end

# Through the loop's two hooks: browsing marks the scene whose annotations are said, and each annotation pass says
# what changed.
Suite.define("bag party: browsing a machine, what each panel shows for it is said after the row, once per item") do
  panels = [BagAnnotationPanel.new(Poke.build(:name => "Pika", :level => 20, :hp => 30, :totalhp => 50), nil),
            BagAnnotationPanel.new(Poke.build(:name => "Bulbi", :level => 12, :hp => 20, :totalhp => 30), nil),
            BagAnnotationPanel.new(Poke.build(:name => "Squi", :level => 15, :hp => 25, :totalhp => 40), nil)]
  scene = BagAnnotationScene.new(panels)
  able = ["APTO", "NO APTO", "APTO"]
  scene.words = { :TM26 => able, :TM27 => able, :TM28 => ["APRENDIDO", "NO APTO", "APTO"] }
  BagPartyHooks.bound do
    begin
      scene.browsed = [:TM26, :TM26, :TM27, :POTION]
      SpeakCapture.clear
      eq "the item loop keeps its own return", scene.pbChooseItem, :POTION
      eq "grouped by the word the panels show, in team order, queued after the row; the same machine once, another " \
         "machine again even with the same words, and an item they annotate nothing for not at all", SpeakCapture.log,
         [["APTO: Pika, Squi. NO APTO: Bulbi", false], ["APTO: Pika, Squi. NO APTO: Bulbi", false]]

      PokeAccess::Config.verbosity = :brief
      scene.browsed = [:TM28]
      SpeakCapture.clear
      scene.pbChooseItem
      silent "brief leaves the annotations out"
      PokeAccess::Config.verbosity = :full

      SpeakCapture.clear
      scene.pbChooseItem
      silent "back on the list from an item's menu, nothing the panels already showed is repeated"

      scene.words[:TM28] = able
      SpeakCapture.clear
      scene.pbUpdateAnnotation
      silent "and outside the item list nothing is said"
    ensure
      PokeAccess::Config.verbosity = :full
    end
  end
end
