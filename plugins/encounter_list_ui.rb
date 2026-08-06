# Encounter List UI: the screen listing the species on the current map, drawn as icons with no text. WHAT to
# say lives in the shared EncounterList reader in core, because a profile builds its own encounter screen on
# the same summary; only WHEN to say it is the plugin's, so only that is here.
#
# drawPresent/drawAbsent are the two ends of the same question -- the map has encounters or it does not --
# and pbStartScene only clears the cursor so reopening the screen reads again.
PokeAccess::Hooks.before_hook("EncounterList_Scene", :pbStartScene, :optional => true) { |s, _a| PokeAccess::Cursor.reset(s, :encounter_list) }
PokeAccess::Hooks.after_hook("EncounterList_Scene", :drawPresent, :optional => true) { |s, _r, _a| PokeAccess::EncounterList.read_present(s) }
PokeAccess::Hooks.after_hook("EncounterList_Scene", :drawAbsent, :optional => true) do |_s, _r, _a|
  PokeAccess.speak(PokeAccess::I18n.t(:enc_none, :loc => ($game_map.name rescue nil).to_s), true)
end
