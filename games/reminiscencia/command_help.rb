# The help and caption windows of Reminiscencia's pbShowCommandsWithHelp and pbShowCommandsRogue, built from its
# own Window_AdvancedTextPokemonCentro, which the core listener does not see; noted to CommandHelp like the core's.
PokeAccess::Game.define("reminiscencia") do
  after("Window_AdvancedTextPokemonCentro", :text=) do |win, _result, args|
    ch = PokeAccess::CommandHelp
    ch.note(win, ch.current == :rogue ? :rogue : :withhelp, args[0])
  end
end
