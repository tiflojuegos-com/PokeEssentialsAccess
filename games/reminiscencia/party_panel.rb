# Reminiscencia's party panel draws no level, so a member is read without one, and writes its HP figures at x 1370,
# off its bitmap (@hpX, @hpY), so only the bar shows. Out of battle a member's command menu shows the run's limits box
# (EVs, Heart Scales against their cap), said once per screen and again when it changes.
PokeAccess::Game.define("reminiscencia_party_panel") do
  override("PokeAccess::Party", :panel_level?) { |_mod, _original, _args| false }
  override("PokeAccess::Party", :panel_hp_figures?) { |_mod, _original, _args| false }

  before("PokemonScreen_Scene", :pbShowCommands, :optional => true) do |scene, args|
    shows = args.length < 4 || args[3]
    if shows && !(defined?($insideBattle) && $insideBattle)
      box = PokeAccess.sprite(scene, "infowindow")
      t = PokeAccess.clean((box.text rescue "").to_s.gsub(/\r?\n/, ". "))
      PokeAccess.speak(t, false) if !t.empty? && PokeAccess::Cursor.changed?(scene, :rem_limits, t)
    end
  end
end
