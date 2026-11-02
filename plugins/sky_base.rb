# What La Base de Sky paints differently from stock Essentials with no class of its own, over screens core reads: the
# purple star (Graphics/UI/shiny_ur) for a super shiny, where any other shiny has the red one, and the machine rows of
# the Better Move Relearner it ships. A game on an earlier release of the base (Revival) lacks the star and the tags.
module PokeAccess
  module SkyBase
    # The word the relearner paints for each machine tag, before the game's translation.
    MACHINE_WORDS = { :TM => "MT", :HM => "MO" }
  end
end

# The word for the star says which of the two is painted.
PokeAccess::Hooks.override(PokeAccess::Party, :shiny_word, :tag => "sky_base") do |_mod, original, args|
  (args[0].super_shiny? rescue false) ? PokeAccess::I18n.t(:pk_super_shiny) : original.call
end

# The battle box draws the same purple star beside a super shiny's name.
PokeAccess::Battle.icon_mark(/\Ashiny_ur\z/i, :pk_super_shiny)

# The relearner paints a machine row's :TM and :HM tags as the words its _INTL gives "MT" and "MO"; said the same way,
# so an English build says what it paints.
PokeAccess::Hooks.override(PokeAccess::UIV21, :entry_label, :tag => "sky_base") do |_mod, original, args|
  word = PokeAccess::SkyBase::MACHINE_WORDS[(args[0][1] rescue nil)]
  word ? PokeAccess.clean((_INTL(word) rescue word).to_s) : original.call
end
