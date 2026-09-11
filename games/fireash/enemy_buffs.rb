# The enemy buffs screen (EnemyBuffs_Scene), where the player pays credits to make the challenge harder. Its
# option rows are read by the core options reader (bound to the WINDOW class); its two standing windows are
# not, since the option help binds to the SCENE class. The title is the only place that says which challenge
# the buffs apply to and the textbox the only place the credit multiplier is written. The textbox interrupts
# (it answers a keypress); the title queues, since it is painted on open.
PokeAccess::Game.define("fireash") do
  info_window "EnemyBuffs_Scene", "title", :buffs_title
  info_window "EnemyBuffs_Scene", "textbox", :buffs_detail, :interrupt => true
end
