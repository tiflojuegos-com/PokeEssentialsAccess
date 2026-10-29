# Sky's relearner (Better Move Relearner, as Royal and World Frontier ship it) paints a machine row's :TM and :HM tags
# as the words its _INTL gives "MT" and "MO"; said the same way, so an English build says what it paints.
module PokeAccess
  module SkyRelearner
    # The word the relearner paints for each machine tag, before the game's translation.
    MACHINE_WORDS = { :TM => "MT", :HM => "MO" }
  end
end

PokeAccess::Game.define("skyflyer_common") do
  override("PokeAccess::UIV21", :entry_label) do |_mod, original, args|
    word = PokeAccess::SkyRelearner::MACHINE_WORDS[(args[0][1] rescue nil)]
    word ? PokeAccess.clean((_INTL(word) rescue word).to_s) : original.call
  end
end
