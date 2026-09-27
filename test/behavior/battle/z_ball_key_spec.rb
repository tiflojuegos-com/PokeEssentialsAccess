# Pokemon Z's ball key (games/pokemon_z/ball_key.rb), through the command reader the profile wraps: in a wild battle,
# whose command menu draws the key's panel, the menu's opening ends on the key's hint, said again only when the ball
# it throws changes; pressing it moves the cursor to a fifth command, said as that ball. The ball is the one the
# battle throws (the homemade ones first), not the one the panel's icon ranks first.
module ZBallKeySpec
  BALLS = { :POKEBALLCASERA => 822, :SUPERBALLCASERA => 823, :ULTRABALLCASERA => 824,
            :ULTRABALL => 265, :GREATBALL => 266, :POKEBALL => 267 }

  # A bag holding the given balls.
  class Bag
    def initialize(held); @held = held; end
    def pbHasItem?(sym); @held.include?(sym); end
  end

  # A command menu with its four labels, with the key's panel (a wild battle) or without it (a trainer's).
  def self.menu(wild)
    win = Object.new
    win.instance_variable_set(:@commands, ["Luchar", "Mochila", "Pokémon", "Huir"])
    disp = Object.new
    disp.instance_variable_set(:@window, win)
    disp.instance_variable_set(:@atajoBall, Object.new) if wild
    disp
  end
end

Suite.define("z ball key: a wild battle's menu ends its opening on the key's hint; the key says the ball it throws") do
  t = PokeAccess::I18n
  battle = PokeAccess::Battle
  name = lambda { |sym| PBItems.getName(ZBallKeySpec::BALLS[sym]) }
  hint = lambda { |sym| t.t(:zball_hint, :key => "S", :ball => name[sym]) }
  made = []
  old_bag = $PokemonBag
  begin
    ZBallKeySpec::BALLS.each do |sym, id|
      next if PBItems.const_defined?(sym)
      PBItems.const_set(sym, id)
      made.push(sym)
    end
    $PokemonBag = ZBallKeySpec::Bag.new([:ULTRABALL, :POKEBALLCASERA])
    wild = ZBallKeySpec.menu(true)

    SpeakCapture.clear
    battle.read_command(wild, 0, false)
    eq "the opening: the command, then the hint with the ball thrown first, a homemade one before the Ultra Ball",
       SpeakCapture.log, [["Luchar", false], [hint[:POKEBALLCASERA], false]]

    SpeakCapture.clear
    battle.read_command(wild, 1, true)
    eq "moving through the menu: the command alone", SpeakCapture.lines, ["Mochila"]

    SpeakCapture.clear
    battle.read_command(wild, 4, true)
    eq "the key pressed: the ball it throws, interrupting", SpeakCapture.log,
       [[t.t(:zball_throw, :ball => name[:POKEBALLCASERA]), true]]

    SpeakCapture.clear
    battle.read_command(wild, 4, false)
    eq "a menu that opens on the key's command, after a throw: that ball, queued, and no hint",
       SpeakCapture.log, [[t.t(:zball_throw, :ball => name[:POKEBALLCASERA]), false]]

    SpeakCapture.clear
    battle.read_command(wild, 0, false)
    eq "the next opening with the same ball: no hint again", SpeakCapture.lines, ["Luchar"]

    $PokemonBag = ZBallKeySpec::Bag.new([:ULTRABALL])
    SpeakCapture.clear
    battle.read_command(wild, 0, false)
    eq "the homemade balls spent: the hint again, with the Ultra Ball", SpeakCapture.lines, ["Luchar", hint[:ULTRABALL]]

    $PokemonBag = ZBallKeySpec::Bag.new([])
    other = ZBallKeySpec.menu(true)
    SpeakCapture.clear
    battle.read_command(other, 0, false)
    battle.read_command(other, 4, true)
    eq "no ball in the bag: no hint, and the key's command names none", SpeakCapture.lines, ["Luchar"]

    $PokemonBag = ZBallKeySpec::Bag.new([:POKEBALL])
    trainer = ZBallKeySpec.menu(false)
    SpeakCapture.clear
    battle.read_command(trainer, 0, false)
    battle.read_command(trainer, 4, true)
    eq "a trainer's battle, with no panel: the command alone, and nothing past the four", SpeakCapture.lines, ["Luchar"]

    PokeAccess::Config.verbosity = :brief
    SpeakCapture.clear
    battle.read_command(ZBallKeySpec.menu(true), 0, false)
    eq "brief, which leaves key hints out: the command alone", SpeakCapture.lines, ["Luchar"]
  ensure
    PokeAccess::Config.verbosity = :full
    $PokemonBag = old_bag
    made.each { |sym| PBItems.send(:remove_const, sym) }
  end
end
