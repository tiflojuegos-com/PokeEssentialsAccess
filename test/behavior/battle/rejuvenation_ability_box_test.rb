# Rejuvenation's ability box (games/rejuvenation/ability_box.rb): the line the box shows, the game's own
# pbAbilityBoxToText, goes ahead of what is said next, or is dropped where the message after it names the battler and
# what the box shows, and is said as the box leaves, or the battle's scene ends, when nothing followed; a repaint in
# place says the new line. The stand-ins below hold the scene's and the battler's names only while the file is
# evaluated, so its hooks bind to them; its override of the dialogue line is kept aside and put in for each test, so
# the other tests keep core's.

# The box as AbilityBox keeps what it shows: setBattler takes the battler, the item and the attribute's name, and
# getDisplayVars answers what pbShowAbilityBox compares.
class RjAbilityBoxSprite
  attr_reader :index
  attr_accessor :onscreen

  def initialize
    @onscreen = false
  end

  def setBattler(battler, item = nil, attrname = nil, crest = nil)
    @index = battler.index
    @pokename = "#{battler.name}'s"
    @pokeattr = attrname || (item ? battler.item : battler.ability)
    @item = item
    @crest = crest
  end

  def getDisplayVars
    [@index, @pokeattr, @item, @crest]
  end
end

# The scene's box methods as Battle_Scene.rb runs them, less the frames each slide takes. A message goes to the
# dialogue reader as core's message hook hands it over, and an HP change, two lists, to the HP reader as core's
# pbHPChanged hook hands them over.
class RjAbilityScene
  def initialize
    @sprites = { "abilityboxplayer" => RjAbilityBoxSprite.new, "abilityboxfoe" => RjAbilityBoxSprite.new }
  end

  def box_of(battler)
    @sprites["abilitybox#{(battler.index & 1) == 0 ? 'player' : 'foe'}"]
  end

  def pbShowAbilityBox(battler, item: nil, attrname: nil, crest: nil)
    abilitybox = box_of(battler)
    vars_before = abilitybox.getDisplayVars
    abilitybox.setBattler(battler, item, attrname, crest)
    if abilitybox.onscreen
      return :unchanged if abilitybox.getDisplayVars == vars_before
      pbHideAbilityBox(battler)
    end
    abilitybox.onscreen = true
    :shown
  end

  def pbHideAbilityBox(battler)
    abilitybox = box_of(battler)
    return unless abilitybox.onscreen
    return if abilitybox.index != battler.index
    abilitybox.onscreen = false
  end

  def pbChangeAbilityBox(battler)
    abilitybox = box_of(battler)
    return unless abilitybox.onscreen
    return if abilitybox.index != battler.index
    abilitybox.setBattler(battler)
  end

  def pbAbilityBoxToText(battler, item = nil, attrname = nil)
    "[#{battler.name}'s #{attrname || (item ? battler.item : battler.ability)}]"
  end

  def pbEndBattle(_result)
    @sprites.each_value { |box| box.onscreen = false }
  end

  def pbDisplayMessage(msg)
    PokeAccess.say_dialogue(msg)
  end

  def pbHPChanged(mons, oldhps, _anim = false)
    PokeAccess::Battle.hp_changed(mons, oldhps)
  end
end

# A battler as Battler.rb changes its HP: the scene's bar first, then the message passed in, only for a change. Each
# starts at 40 HP of 80.
class RjAbilityBattler
  attr_reader :index, :name, :item, :hp, :totalhp
  attr_accessor :ability

  def initialize(scene, index, name, ability, item = nil)
    @scene = scene
    @index = index
    @name = name
    @ability = ability
    @item = item
    @hp = 40
    @totalhp = 80
  end

  def pbReduceHP(amt, anim = false, _emercheck = true, message: nil)
    oldhp = @hp
    @hp -= amt
    if amt > 0
      @scene.pbHPChanged([self], [oldhp], anim)
      @scene.pbDisplayMessage(message) if message
    end
    amt
  end

  def pbRecoverHP(amt, anim = false, _hpbaranim = true, message: nil)
    oldhp = @hp
    @hp += amt
    if amt > 0
      @scene.pbHPChanged([self], [oldhp], anim)
      @scene.pbDisplayMessage(message) if message
    end
    amt
  end
end

# The profile file evaluated once over the stand-ins, its override of the dialogue line kept aside and core's put back.
module RjAbilityBoxBinding
  STAND_INS = { :PokeBattle_Scene => RjAbilityScene, :PokeBattle_Battler => RjAbilityBattler }.freeze

  class << self
    # The profile's say_dialogue.
    attr_reader :say
  end

  def self.load
    meta = PokeAccess.singleton_class
    core = meta.instance_method(:say_dialogue)
    overrides = PokeAccess::Hooks.overrides.length
    priors = STAND_INS.keys.map { |n| [n, Object.const_defined?(n) ? Object.send(:remove_const, n) : nil] }
    STAND_INS.each { |n, k| Object.const_set(n, k) }
    path = File.join(Harness::ROOT, "games", "rejuvenation", "ability_box.rb")
    eval(Harness.source(path), TOPLEVEL_BINDING, path)
    @say = meta.instance_method(:say_dialogue)
  ensure
    meta.send(:define_method, :say_dialogue, core)
    PokeAccess::Hooks.overrides.slice!(overrides..-1)
    STAND_INS.each_key { |n| Object.send(:remove_const, n) if Object.const_defined?(n) }
    (priors || []).each { |n, k| Object.const_set(n, k) if k }
  end
  load
end

class RejuvenationAbilityBoxTest < PokeAccessTest
  def setup
    super
    PokeAccess::RejuvAbilityBox.instance_variable_set(:@pending, nil)
  end

  test "says the box ahead of a message that does not name it, both queued" do
    scene, pika, _foe = field
    with_profile do
      scene.pbShowAbilityBox(pika)
      scene.pbDisplayMessage("Pikachu's Attack rose!")
      scene.pbHideAbilityBox(pika)
    end
    assert_equal [["[Pikachu's Wind Rider]", false], ["Pikachu's Attack rose!", false]], SpeakCapture.log
  end

  test "leaves the box to a message naming its battler and what it shows, not the next box to one that does not" do
    scene, pika, _foe = field
    with_profile do
      scene.pbShowAbilityBox(pika, :item => true)
      scene.pbDisplayMessage("Pikachu used its Mirror Herb to mirror its opponent's stat boosts!")
      scene.pbHideAbilityBox(pika)
      scene.pbShowAbilityBox(pika)
      scene.pbDisplayMessage("Pikachu's Attack rose!")
      scene.pbHideAbilityBox(pika)
    end
    assert_equal ["Pikachu used its Mirror Herb to mirror its opponent's stat boosts!", "[Pikachu's Wind Rider]",
                  "Pikachu's Attack rose!"], SpeakCapture.lines
  end

  test "keeps the box ahead of a message that names what it shows but not whose" do
    scene, _pika, _foe = field
    weezing = RjAbilityBattler.new(scene, 3, "Weezing", "Neutralizing Gas")
    with_profile do
      scene.pbShowAbilityBox(weezing)
      scene.pbDisplayMessage("Neutralizing gas filled the area!")
      scene.pbHideAbilityBox(weezing)
    end
    assert_equal ["[Weezing's Neutralizing Gas]", "Neutralizing gas filled the area!"], SpeakCapture.lines
  end

  test "says a box still waiting as the battle's scene ends, and not again ahead of the first line after the fight" do
    scene, pika, _foe = field
    at_end = with_profile do
      scene.pbShowAbilityBox(pika)
      scene.pbEndBattle(1)
      ended = SpeakCapture.log.dup
      SpeakCapture.clear
      PokeAccess.say_dialogue("What? Pikachu is evolving!")
      ended
    end
    assert_equal [[["[Pikachu's Wind Rider]", false]], ["What? Pikachu is evolving!"]], [at_end, SpeakCapture.lines]
  end

  test "says a box no message follows as it leaves, and a box shown again unchanged once" do
    scene, pika, _foe = field
    again = with_profile do
      scene.pbShowAbilityBox(pika)
      kept = scene.pbShowAbilityBox(pika)
      scene.pbHideAbilityBox(pika)
      kept
    end
    assert_equal [:unchanged, [["[Pikachu's Wind Rider]", false]]], [again, SpeakCapture.log]
  end

  test "says the box ahead of the HP change it causes, unless the change's message names it" do
    scene, pika, foe = field
    with_profile do
      scene.pbShowAbilityBox(foe, :item => true)
      foe.pbRecoverHP(3, true, :message => "Ferrothorn restored a little HP using its Leftovers!")
      scene.pbHideAbilityBox(foe)
      scene.pbShowAbilityBox(foe)
      pika.pbReduceHP(5, true, :message => "Pikachu was hurt!")
      scene.pbHideAbilityBox(foe)
    end
    assert_equal [foe_hp(:bt_gain, 3, 53), "Ferrothorn restored a little HP using its Leftovers!",
                  "[Ferrothorn's Iron Barbs]", own_hp(:bt_lose, 5, 35), "Pikachu was hurt!"], SpeakCapture.lines
  end

  test "says a box repainted in place: the line it showed, then the new one ahead of the message" do
    scene, pika, _foe = field
    with_profile do
      scene.pbShowAbilityBox(pika)
      pika.ability = "Static"
      scene.pbChangeAbilityBox(pika)
      scene.pbDisplayMessage("Pikachu swapped Abilities with its target!")
      scene.pbHideAbilityBox(pika)
    end
    assert_equal ["[Pikachu's Wind Rider]", "[Pikachu's Static]", "Pikachu swapped Abilities with its target!"],
                 SpeakCapture.lines
  end

  test "says nothing for a repaint of a box that is not on screen, and the box that then slides in" do
    scene, pika, foe = field
    with_profile do
      scene.pbChangeAbilityBox(pika)
      scene.pbShowAbilityBox(foe)
      scene.pbDisplayMessage("Pikachu's Attack fell!")
    end
    assert_equal ["[Ferrothorn's Iron Barbs]", "Pikachu's Attack fell!"], SpeakCapture.lines
  end

  test "says a waiting box before the next one slides in on the other side" do
    scene, pika, foe = field
    with_profile do
      scene.pbShowAbilityBox(pika)
      scene.pbShowAbilityBox(foe)
      scene.pbDisplayMessage("The battlers glared at each other!")
    end
    assert_equal ["[Pikachu's Wind Rider]", "[Ferrothorn's Iron Barbs]", "The battlers glared at each other!"],
                 SpeakCapture.lines
  end

  test "the box's methods and the HP changes keep the game's values, the box said ahead of the first change" do
    scene, pika, _foe = field
    values = with_profile { [scene.pbShowAbilityBox(pika), pika.pbReduceHP(4), pika.pbRecoverHP(2)] }
    assert_equal [[:shown, 4, 2], ["[Pikachu's Wind Rider]", own_hp(:bt_lose, 4, 36), own_hp(:bt_gain, 2, 38)]],
                 [values, SpeakCapture.lines]
  end

  private

  def t(key, vars = nil)
    PokeAccess::I18n.t(key, vars)
  end

  # The HP reader's line for Pikachu, on the player's side, losing or gaining n HP to hp of its 80.
  def own_hp(verb, n, hp)
    t(:bt_hp_change, :name => "Pikachu", :verb => t(verb), :n => n, :rest => t(:bt_hp_exact, :hp => hp, :tot => 80))
  end

  # The HP reader's line for Ferrothorn across, as the change of its bar's share, pct points to left percent.
  def foe_hp(verb, pct, left)
    t(:bt_hp_change_pct, :name => "Ferrothorn", :verb => t(verb), :n => pct, :rest => t(:bt_hp_pct, :n => left))
  end

  # A scene with Pikachu (Wind Rider, holding a Mirror Herb) on the player's side and Ferrothorn (Iron Barbs, holding
  # Leftovers) across.
  def field
    scene = RjAbilityScene.new
    [scene, RjAbilityBattler.new(scene, 0, "Pikachu", "Wind Rider", "Mirror Herb"),
     RjAbilityBattler.new(scene, 1, "Ferrothorn", "Iron Barbs", "Leftovers")]
  end

  # The block's value with the profile's say_dialogue in core's place.
  def with_profile
    meta = PokeAccess.singleton_class
    core = meta.instance_method(:say_dialogue)
    meta.send(:define_method, :say_dialogue, RjAbilityBoxBinding.say)
    yield
  ensure
    meta.send(:define_method, :say_dialogue, core)
  end
end
