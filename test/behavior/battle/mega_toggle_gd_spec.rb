# v21's setIndexAndMode sets @mode without the mode= setter, so its hook primes @access_mega from the opening mode:
# the open says no toggle, and the first available (1) to registered (2) toggle is voiced.
Suite.define("battle (gamedata): first v21 mega toggle sounds after opening via setIndexAndMode") do
  menu = ::Battle::Scene::FightMenu.new
  menu.setIndexAndMode(0, 1)
  not_spoke "opening the fight menu does not announce a mega toggle",
            /#{Regexp.escape(PokeAccess::I18n.t(:bt_mega_on))}|#{Regexp.escape(PokeAccess::I18n.t(:bt_mega_off))}/
  eq "the open primes the mega state from the opening mode", menu.instance_variable_get(:@access_mega), 1
  menu.mode = 2
  spoke "the first toggle to registered is announced",
        /#{Regexp.escape(PokeAccess::I18n.t(:bt_mega_on))}/
end

# Opening with the mechanic available is said, by the name the battle kit gave it (note_special_action) if any.
Suite.define("battle (gamedata): a fight menu that opens with the mechanic available says so") do
  menu = ::Battle::Scene::FightMenu.new
  SpeakCapture.clear
  PokeAccess::Battle.note_special_action(true)
  menu.setIndexAndMode(0, 1)
  eq "plain Mega Evolution", SpeakCapture.lines, [PokeAccess::I18n.t(:bt_mega_ready)]
  SpeakCapture.clear
  PokeAccess::Battle.note_special_action(:dynamax)
  menu.setIndexAndMode(0, 1)
  eq "the kit's dynamax by its name", SpeakCapture.lines,
     [PokeAccess::I18n.t(:bt_special_ready, :name => PokeAccess::I18n.t(:bt_m_dynamax))]
  SpeakCapture.clear
  menu.setIndexAndMode(0, 0)
  eq "hidden, nothing", SpeakCapture.lines, []
  PokeAccess::Battle.note_special_action(nil)
end

# Toggling back from registered (2) to available (1) is said as off.
Suite.define("battle (gamedata): mega toggle still deactivates on the second press") do
  menu = ::Battle::Scene::FightMenu.new
  menu.setIndexAndMode(0, 1)
  menu.mode = 2
  SpeakCapture.clear
  menu.mode = 1
  spoke "toggling back to available is announced as off",
        /#{Regexp.escape(PokeAccess::I18n.t(:bt_mega_off))}/
end
