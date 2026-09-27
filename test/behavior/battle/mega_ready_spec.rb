# The stock gen-6 fight menu's Mega Evolution button, set every turn: its coming up is said after the move, and so
# are pressing and releasing it.

# Loads the gen-6 battle hooks again, now that a FightMenuDisplay exists for them to bind to.
def mega_ready_replay_g6
  verbose = $VERBOSE
  $VERBOSE = nil
  path = File.join(Harness::ROOT, "core", "battle", "gen6", "battle_g6.rb")
  eval(File.read(path), TOPLEVEL_BINDING, path)
ensure
  $VERBOSE = verbose
end

Suite.define("battle (gen-6): the Mega Evolution button is said when it comes up, each turn") do
  begin
    stock = Class.new do
      def initialize; @index = 0; @battler = nil; end
      def setIndex(v); @index = v; end
      def battler=(b); @battler = b; end
      def megaButton=(v); @megaButton = v; end
    end
    Object.const_set(:FightMenuDisplay, stock)
    mega_ready_replay_g6
    disp = FightMenuDisplay.new
    t = PokeAccess::I18n
    SpeakCapture.clear
    disp.megaButton = 0
    disp.megaButton = 1
    disp.megaButton = 2
    disp.megaButton = 1
    disp.megaButton = 0
    disp.megaButton = 1
    eq "available, on, off, and available again next turn", SpeakCapture.lines,
       [t.t(:bt_mega_ready), t.t(:bt_mega_on), t.t(:bt_mega_off), t.t(:bt_mega_ready)]
  ensure
    Object.send(:remove_const, :FightMenuDisplay) if Object.const_defined?(:FightMenuDisplay)
  end
end
