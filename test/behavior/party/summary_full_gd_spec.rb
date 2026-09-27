# The modern summary says what it shows: page one's trainer lines, the memo's own paragraph, the stats page's
# ability text and nature effect, and each move's type.

# A modern Pokemon as the summary asks it: owner, experience, growth rate and an ability object.
class FullSumPoke < TestPoke
  attr_accessor :exp
  Owner = Struct.new(:name, :public_id)
  Ability = Struct.new(:id, :name, :description)
  Rate = Struct.new(:table)
  def owner; Owner.new("Ceniza", 1234); end
  def growth_rate; Rate.new(nil).tap { |r| def r.minimum_exp_for_level(l); l * 100; end }; end
  def ability; Ability.new(:STATIC, "Electricidad Estatica", "Puede paralizar al contacto."); end
  def speciesName; "Pikachu"; end
  def types; [:ELECTRIC]; end
  def item; nil; end
end

Suite.define("summary (modern): page one adds the trainer lines the page paints") do
  t = PokeAccess::I18n
  pk = FullSumPoke.build(:name => "Chispa", :level => 12)
  pk.exp = 1250
  line = PokeAccess::SummaryGameData.info_text(pk).to_s
  truthy "the original trainer", line.index(t.t(:sum_ot, :name => "Ceniza"))
  truthy "the ID number, padded as the page prints it", line.index(t.t(:sum_id, :id => "01234"))
  truthy "the experience", line.index(t.t(:sum_exp, :n => 1250))
  truthy "and what the next level needs", line.index(t.t(:sum_exp_next, :n => 50))
end

# The SV summary (Anil, Emerald) paints the ability's name and a Details button, keeping the description behind it.
Suite.define("summary (modern): the memo is the paragraph the page writes, and the stats page the ability's text") do
  t = PokeAccess::I18n
  pk = FullSumPoke.build(:name => "Chispa", :level => 12)
  painted = ["<c3=F83818,E09890>Naturaleza Firme.\n<c3=404040,B0B0B0>18 septiembre, 2026\nRuta 3\nEncontrado con Nv. 5.\n\nLe encanta comer."]
  eq "the memo reads the page's own paragraph, one sentence per line, the colour codes gone",
     PokeAccess::SummaryGameData.memo_text(pk, painted),
     "#{t.t(:sm_memo)}. Naturaleza Firme. 18 septiembre, 2026. Ruta 3. Encontrado con Nv. 5. Le encanta comer."
  natured = FullSumPoke.build(:name => "Chispa", :level => 12)
  natured.define_singleton_method(:nature) { Struct.new(:name).new("Firme") }
  eq "with nothing painted it still says the nature", PokeAccess::SummaryGameData.memo_text(natured, []).to_s,
     "#{t.t(:sm_memo)}. #{t.t(:sm_nature, :n => 'Firme')}."

  stats = PokeAccess::SummaryGameData.stats_text(pk).to_s
  truthy "the stats page ends with the ability and the description written under it",
         stats.index(t.t(:sum_ability_desc, :a => "Electricidad Estatica", :d => "Puede paralizar al contacto."))

  written = PokeAccess::SummaryGameData.stats_text(pk, ["Electricidad Estatica", "Puede paralizar al contacto."]).to_s
  truthy "a page that paints the description has it said",
         written.index(t.t(:sum_ability_desc, :a => "Electricidad Estatica", :d => "Puede paralizar al contacto."))
  kept = PokeAccess::SummaryGameData.stats_text(pk, ["Electricidad Estatica", "Detalles"]).to_s
  truthy "a page that keeps it behind a button has only the name said",
         kept.index(t.t(:sum_ability, :a => "Electricidad Estatica")) && !kept.index("Puede paralizar")
end

# Anil and Royal show modified move properties: Hidden Power's icon is the type its IVs make it.
Suite.define("summary: the moves page names each move's type, as its icon does") do
  t = PokeAccess::I18n
  move = Struct.new(:id, :name, :type, :pp, :total_pp).new(:THUNDERBOLT, "Rayo", :TYPE1, 15, 15)
  pk = FullSumPoke.build(:name => "Chispa", :moves => [move])
  eq "name, type and pp", PokeAccess::Summary.moves_text(pk),
     t.t(:sm_moves, :list => "Rayo. #{t.t(:mv_type, :t => "TypeTYPE1")}. #{t.t(:mv_pp, :pp => 15, :tot => 15)}")

  hidden = Struct.new(:id, :name, :type, :pp, :total_pp).new(:HIDDENPOWER, "Poder Oculto", :NORMAL, 15, 15)
  def hidden.display_type(_pkmn); :FIRE; end
  eq "a move whose shown type is not its own says the shown one",
     PokeAccess::Summary.moves_text(FullSumPoke.build(:name => "Chispa", :moves => [hidden])),
     t.t(:sm_moves, :list => "Poder Oculto. #{t.t(:mv_type, :t => "TypeFIRE")}. #{t.t(:mv_pp, :pp => 15, :tot => 15)}")
end

# A Pokemon whose nature moves two stats, with IVs and EVs for the pages that write them.
class NatureSumPoke < FullSumPoke
  Nature = Struct.new(:name, :stat_changes)
  def nature; Nature.new("Firme", [[:ATTACK, 10], [:SPECIAL_ATTACK, -10]]); end
  def iv; { :HP => 31, :ATTACK => 30, :DEFENSE => 29, :SPECIAL_ATTACK => 28, :SPECIAL_DEFENSE => 27, :SPEED => 26 }; end
  def ev; { :HP => 4, :ATTACK => 252, :DEFENSE => 0, :SPECIAL_ATTACK => 0, :SPECIAL_DEFENSE => 0, :SPEED => 252 }; end
end

# The same Pokemon after a mint: its stats play with another nature.
class MintSumPoke < NatureSumPoke
  def nature_for_stats; Nature.new("Miedosa", [[:SPEED, 10], [:ATTACK, -10]]); end
end

Suite.define("summary (modern): the stats page says the nature's effect, and a profile adds its IV/EV columns") do
  t = PokeAccess::I18n
  pk = NatureSumPoke.build(:name => "Chispa")
  line = PokeAccess::SummaryGameData.stats_text(pk).to_s
  truthy "the nature's raised and lowered stats, as the coloured labels show them",
         line.index(t.t(:sm_nature_effect, :up => "StatATTACK", :down => "StatSPECIAL_ATTACK"))

  minted = MintSumPoke.build(:name => "Chispa")
  truthy "after a mint, the stock page colours the stats the mint's nature moves",
         PokeAccess::SummaryGameData.stats_text(minted).to_s.index(t.t(:sm_nature_effect, :up => "StatSPEED", :down => "StatATTACK"))

  sgd = PokeAccess::SummaryGameData
  plain = sgd.method(:stats_extras)
  plain_nature = PokeAccess::Summary.method(:stats_nature)
  begin
    load File.expand_path("../../../games/fireash/summary_ivs.rb", File.dirname(__FILE__))
    line = sgd.stats_text(pk).to_s
    truthy "with Fire Ash's page the IVs and EVs follow the stats", line.index(sgd.iv_ev_text(pk))
    truthy "and the ability still closes the page", line.rindex(t.t(:sum_ability_desc, :a => "Electricidad Estatica",
                                                                    :d => "Puede paralizar al contacto.")) > line.index(sgd.iv_ev_text(pk))
    truthy "Fire Ash's page colours by the Pokemon's own nature, mint or not",
           sgd.stats_text(minted).to_s.index(t.t(:sm_nature_effect, :up => "StatATTACK", :down => "StatSPECIAL_ATTACK"))

    zud = NatureSumPoke.build(:name => "Chispa")
    zud.define_singleton_method(:dynamaxAble?) { true }
    zud.define_singleton_method(:dynamax_lvl) { 7 }
    ::Settings.const_set(:NO_DYNAMAX, 498)
    $game_switches[498] = true
    zline = sgd.stats_text(zud).to_s
    meter = zline.index(t.t(:dmax_level, :n => 7))
    truthy "ZUD's Dynamax meter is still said below the IV/EV columns, whatever the kit's switch says",
           meter && meter > zline.index(sgd.iv_ev_text(zud))
  ensure
    $game_switches[498] = false
    ::Settings.send(:remove_const, :NO_DYNAMAX) if ::Settings.const_defined?(:NO_DYNAMAX)
    sgd.define_singleton_method(:stats_extras, plain)
    PokeAccess::Summary.define_singleton_method(:stats_nature, plain_nature)
  end
end

# Soulstones 2's columns: outside purist mode its special attack row shows Attack's effort.
Suite.define("summary (modern): Soulstones 2's columns, the special attack row mixed outside purist mode") do
  sgd = PokeAccess::SummaryGameData
  plain = sgd.method(:stats_extras)
  begin
    load File.expand_path("../../../games/soulstones2/summary_ivs.rb", File.dirname(__FILE__))
    pk = NatureSumPoke.build(:name => "Chispa")
    truthy "the special attack row carries Attack's effort", sgd.stats_text(pk).to_s.index(sgd.iv_ev_text(pk, :ATTACK))
  ensure
    sgd.define_singleton_method(:stats_extras, plain)
  end
end
