# Realidea clears its obstacles with no Pokemon at all: its Kernel.pbCut asks switch 142 alone, and its
# Kernel.pbRockSmash two badges.
PokeAccess::Game.define("realidea") do
  override("PokeAccess::FieldMoves", :can?) do |_mod, original, args|
    case args[0]
    when :CUT then $game_switches[142] ? true : false
    when :ROCKSMASH
      n = (PokeAccess::Engine.player.numbadges rescue nil)
      n.nil? ? nil : n >= 2
    else original.call
    end
  end

  # Its Kernel.pbSurf (0195_Following.rb) refuses while anyone walks along as a dependent event, unless the following
  # Pokemon's switch is on.
  surf_company(:dependents) { $game_switches[Following_Activated_Switch] }
end
