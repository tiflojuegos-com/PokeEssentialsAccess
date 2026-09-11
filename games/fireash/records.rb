# Fire Ash's six records halls. Each is a copy-paste clone of FL's Hall of Fame scene -- same
# writePokemonData painting the same panel, same writeWelcome, same PC browser -- with the class name, the
# global array and the header changed. Core binds the two vanilla spellings; these are this game's.
#
# All six were mute from end to end, and worse than mute: the focused member is marked ONLY by opacity
# (255 against 64), so nothing at all told a blind player which of the six the screen was showing.
#
# Challenge_Scene is the Sync/Titan team viewer rather than a records hall, but it is the same clone with
# the same panel, so it gets the same reader.
PokeAccess::Game.define("fireash") do
  hall_of_fame "Practice_Scene", "Club_Scene", "Gauntlet_Scene", "Duet_Scene", "Mayhem_Scene", "Challenge_Scene"
end
