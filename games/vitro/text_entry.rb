# Vitro's text entry mode, $PokemonSystem.keyboardEntry (0170_PScreen_Options "Input de Texto": 0 the computer's keyboard, 1
# the game's own grid of letters, read by 0061_TextEntry): a new game starts with the keyboard. This is an exception the user
# asked for to the rule that a profile leaves the game's settings alone. It is set only as a new game begins, when
# $PokemonTemp.begunNewGame first turns true (0378_MultiSave_Load's new game, then pbTrainerName), never on a loaded game, so a
# choice made later in the options stays.
PokeAccess::Game.define("vitro") do
  before("PokemonTemp", :begunNewGame=, :optional => true) do |temp, args|
    next unless args[0] && !temp.begunNewGame && $PokemonSystem && $PokemonSystem.respond_to?(:keyboardEntry=)
    $PokemonSystem.keyboardEntry = 0
  end
end
