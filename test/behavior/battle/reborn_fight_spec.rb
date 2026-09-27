# Reborn's fight menu (games/reborn/fight_menu.rb): the move line carries the type the move will have, the one the
# field adds and the field's boost, as the game's own pbFieldNotesBattle works it out; the Z-Move button toggles the
# Z-move in the move's place. Reborn's battle objects stand in below, with pbFieldNotesBattle answering per move.
def pbFieldNotesBattle(move); ($reborn_spec_boost || {})[move.move].to_i; end

module RebornFightSpec
  # A battle move of Reborn: the symbol in move, its real type from pbType, the field's extra types.
  class Move
    attr_reader :move, :name, :pp, :totalpp, :type, :category
    def initialize(move, name, type, real = nil, extra = nil)
      @move = move; @name = name; @type = type; @real = real || type; @extra = extra
      @pp = 10; @totalpp = 15; @category = :special
    end
    def pbType(_attacker); @real; end
    def getSecondaryType(_attacker); @extra; end
  end

  Battle = Struct.new(:FE)

  # The battler: its moves, the Z-moves they turn into, and whether a slot has one.
  class Battler
    attr_reader :moves, :zmoves, :battle
    def initialize(moves, zmoves, fe)
      @moves = moves; @zmoves = zmoves; @battle = Battle.new(fe)
    end
    def pbCompatibleZMoveFromMove?(idx, _flag); !@zmoves[idx].nil?; end
  end

  # Reborn's fight window as far as the reader goes: its zButton, set from the menu; installed for the suite only,
  # since other specs install and remove their own FightMenuDisplay.
  DISPLAY = Class.new do
    attr_reader :zButton
    def zButton=(v); @zButton = v; end
  end

  def self.display(battler, idx)
    d = ::FightMenuDisplay.new
    d.instance_variable_set(:@battler, battler)
    d.instance_variable_set(:@index, idx)
    d
  end
end

Suite.define("reborn: the fight menu says the field's part of each move") do
  bs = (class << PokeAccess::Battle; self; end)
  bs.send(:alias_method, :reborn_spec_read_fight_move, :read_fight_move)
  prior = Object.const_defined?(:FightMenuDisplay) ? Object.send(:remove_const, :FightMenuDisplay) : nil
  Object.const_set(:FightMenuDisplay, RebornFightSpec::DISPLAY)
  begin
    load File.expand_path("../../../games/reborn/fight_menu.rb", File.dirname(__FILE__))
    t = PokeAccess::I18n
    pixie = RebornFightSpec::Move.new(:HYPERVOICE, "Hyper Voice", :NORMAL, :FAIRY)
    press = RebornFightSpec::Move.new(:FLYINGPRESS, "Flying Press", :FIGHTING, nil, [:FLYING])
    rock = RebornFightSpec::Move.new(:ROCKSLIDE, "Rock Slide", :ROCK, nil, [:GROUND])
    zmove = RebornFightSpec::Move.new(:BREAKNECKBLITZ, "Breakneck Blitz", :NORMAL)
    b = RebornFightSpec::Battler.new([pixie, press, rock], [zmove, nil, nil], :CAVE)
    $reborn_spec_boost = { :HYPERVOICE => 1, :ROCKSLIDE => 2 }
    d = RebornFightSpec.display(b, 0)

    SpeakCapture.clear
    PokeAccess::Battle.read_fight_move(d)
    line = SpeakCapture.lines.last.to_s
    truthy "the core call now reads Reborn's line, named by the data (#{line})",
           line.include?(PokeAccess::Data.move_name(:HYPERVOICE).to_s)
    truthy "with the type the move will have, not its base one", line.include?(t.t(:mv_type, :t => PokeAccess::Data.type_name(:FAIRY)))
    truthy "and the field boost", line.include?(t.t(:reb_move_boosted))

    SpeakCapture.clear
    d.instance_variable_set(:@index, 1)
    PokeAccess::Battle.read_fight_move(d)
    line = SpeakCapture.lines.last.to_s
    truthy "a second type is named (#{line})", line.include?(t.t(:reb_move_also_type, :t => PokeAccess::Data.type_name(:FLYING)))

    SpeakCapture.clear
    d.instance_variable_set(:@index, 2)
    PokeAccess::Battle.read_fight_move(d)
    line = SpeakCapture.lines.last.to_s
    truthy "a weakened move says so (#{line})", line.include?(t.t(:reb_move_weakened))

    b2 = RebornFightSpec::Battler.new([rock], [nil], :RAINBOW)
    SpeakCapture.clear
    PokeAccess::Battle.read_fight_move(RebornFightSpec.display(b2, 0))
    truthy "on Rainbow the added type is a random one", SpeakCapture.lines.last.to_s.include?(t.t(:reb_move_random_type))

    SpeakCapture.clear
    d.instance_variable_set(:@index, 0)
    d.zButton = 0
    d.zButton = 1
    eq "the Z-Move button coming up is said", SpeakCapture.lines.last, PokeAccess::Battle.ready_text(:zmove)
    SpeakCapture.clear
    d.zButton = 2
    eq "turning it on says so, then the Z-move takes the move's place",
       [SpeakCapture.lines[0], SpeakCapture.lines[1].to_s.include?(PokeAccess::Data.move_name(:BREAKNECKBLITZ).to_s)],
       [t.t(:bt_special_on, :name => t.t(:bt_m_zmove)), true]
    falsy "a Z-move has no pp of its own", SpeakCapture.lines[1].to_s.include?(t.t(:mv_pp, :pp => 10, :tot => 15))
  ensure
    $reborn_spec_boost = nil
    Object.send(:remove_const, :FightMenuDisplay)
    Object.const_set(:FightMenuDisplay, prior) if prior
    bs.send(:alias_method, :read_fight_move, :reborn_spec_read_fight_move)
    bs.send(:remove_method, :reborn_spec_read_fight_move)
  end
end
