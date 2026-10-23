module PokeAccess
  # The HM Catalogue: a key item whose pages unlock the field moves one by one, and whose pbCut, pbRockSmash,
  # pbStrength, pbSurf, pbDive and pbWaterfall ask the catalogue alone, never the party or the badges.
  module HMCatalogueMoves
    # The catalogue's flag for each move it unlocks.
    FLAGS = { :CUT => :cut, :ROCKSMASH => :rock_smash, :STRENGTH => :strength, :SURF => :surf, :DIVE => :dive,
              :WATERFALL => :waterfall, :ROCKCLIMB => :rock_climb } unless const_defined?(:FLAGS)

    # Whether the catalogue has unlocked a move it rules, as the game's own checks read it (nil when unreadable).
    def self.can?(move)
      ::HM_Catalogue.send(FLAGS[move]) == true
    rescue StandardError => e
      PokeAccess.swallowed(e)
      nil
    end
  end
end

PokeAccess::Hooks.override(PokeAccess::FieldMoves, :can?, :tag => "hm_catalogue") do |_mod, original, args|
  rules = defined?(::HM_Catalogue) && PokeAccess::HMCatalogueMoves::FLAGS.key?(args[0])
  rules ? PokeAccess::HMCatalogueMoves.can?(args[0]) : original.call
end

# The catalogue's pbSurf, which replaces the stock one, asks nothing of who walks along.
PokeAccess::Pathfinder.surf_company(:anyone) if defined?(::HM_Catalogue)

# Its screen (HM_Scene), a command list under the title it paints in its corner.
PokeAccess::Hooks.before_hook("HM_Scene", :pbUpdate, :optional => true) do |scene, _a|
  PokeAccess::ScreenTitle.say(scene)
end
