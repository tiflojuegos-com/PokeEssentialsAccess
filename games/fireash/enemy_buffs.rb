# The enemy buffs screen (EnemyBuffs_Scene): core reads its option rows; this reads the title (the challenge)
# and the textbox (the credit multiplier), queued so the textbox's reset on each move does not cut the option.
PokeAccess::Game.define("fireash") do
  info_window "EnemyBuffs_Scene", "title", :buffs_title
  info_window "EnemyBuffs_Scene", "textbox", :buffs_detail
end
