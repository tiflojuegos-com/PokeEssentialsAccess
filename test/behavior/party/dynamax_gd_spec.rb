# The G-Max Factor mark and the Dynamax meter the summary draws, for ZUD and for the Deluxe Battle Kit (each spells
# its methods its own way); the kit's NO_DYNAMAX switch hides only the kit's meter.
Suite.define("dynamax: the G-Max Factor mark and the Dynamax meter the summary draws") do
  t = PokeAccess::I18n
  zud = Poke.build(:name => "Chispa")
  zud.define_singleton_method(:gmaxFactor?) { true }
  zud.define_singleton_method(:dynamaxAble?) { true }
  zud.define_singleton_method(:dynamax_lvl) { 7 }
  kit = Poke.build(:name => "Otro")
  kit.define_singleton_method(:gmax_factor?) { false }
  kit.define_singleton_method(:dynamax_able?) { true }
  kit.define_singleton_method(:dynamax_lvl) { 3 }
  truthy "ZUD's factor in the header", PokeAccess::Summary.header_icons(zud).include?(t.t(:dmax_factor))
  truthy "and its meter on the stats page", PokeAccess::SummaryGameData.stats_text(zud).to_s.include?(t.t(:dmax_level, :n => 7))
  falsy "the kit's Pokemon without the factor has no mark", PokeAccess::Summary.header_icons(kit).include?(t.t(:dmax_factor))
  truthy "and its meter", PokeAccess::SummaryGameData.stats_text(kit).to_s.include?(t.t(:dmax_level, :n => 3))
  ::Settings.const_set(:NO_DYNAMAX, 498)
  $game_switches[498] = true
  begin
    falsy "the kit's switch against Dynamax hides its meter", PokeAccess::SummaryGameData.stats_text(kit).to_s.include?(t.t(:dmax_level, :n => 3))
    truthy "but not ZUD's, which draws it without asking", PokeAccess::SummaryGameData.stats_text(zud).to_s.include?(t.t(:dmax_level, :n => 7))
  ensure
    $game_switches[498] = false
    ::Settings.send(:remove_const, :NO_DYNAMAX)
  end
  plain = Poke.build(:name => "Nada")
  falsy "a Pokemon of neither plugin has neither", PokeAccess::SummaryGameData.stats_text(plain).to_s.include?(t.t(:dmax_level, :n => 0))
end
