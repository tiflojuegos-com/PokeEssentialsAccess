# Royal's post-battle EXP panel (Swdfm_Exp_Screen): each member's gain (@values[i]) once on draw_party, and each
# level-up on redraw_level, which runs once per level after @levels[i] is raised.
PokeAccess::Game.define("royal") do
  after("Swdfm_Exp_Screen", :draw_party) do |scr, _ret, _args|
    next if (scr.instance_variable_get(:@access_mep) rescue false)
    scr.instance_variable_set(:@access_mep, true)
    vals = PokeAccess.ivar(scr, :@values)
    party = ($player.party rescue nil)
    next unless party && vals
    lines = party.zip(vals).map { |pk, v| PokeAccess::I18n.t(:mep_exp_gain, :name => pk.name, :n => v) if pk && v && v != 0 }.compact
    PokeAccess.speak_clean(lines.join(". "), true) unless lines.empty?
  end

  after("Swdfm_Exp_Screen", :redraw_level) do |scr, _ret, args|
    i = args[0]
    party = ($player.party rescue nil)
    levels = PokeAccess.ivar(scr, :@levels)
    next unless party && levels && i && party[i] && levels[i]
    PokeAccess.speak_clean(PokeAccess::I18n.t(:mep_level_up, :name => party[i].name, :n => levels[i]), false)
  end
end
