# Pokemon Z's and Opalo's IV stars on the stats page (lostie_common, which the gen-6 pass's pokemon_z profile imports):
# empty, low, high or perfect by the page's thresholds, said as words in the page's order, speed last.
class ZIvStarsTest < PokeAccessTest
  # The stats as the page lists them.
  STATS = [:st_hp, :st_atk, :st_def, :st_spatk, :st_spdef, :st_speed]

  test "the stats page says each stat's star after the stats and before the ability, speed last" do
    each_star = stars(:iv_star_perfect, :iv_star_high, :iv_star_low, :iv_star_empty, :iv_star_perfect, :iv_star_low)
    assert_equal [[page_line(each_star), false]], stats_page([31, 17, 16, 7, 6, 26])
  end

  test "a value earns the star of the page's thresholds" do
    { 0 => :iv_star_empty, 6 => :iv_star_empty, 7 => :iv_star_low, 16 => :iv_star_low, 17 => :iv_star_high,
      25 => :iv_star_high, 26 => :iv_star_perfect, 31 => :iv_star_perfect }.each do |iv, star|
      assert_equal star, PokeAccess::IVStars.star(iv), "an IV of #{iv}"
    end
  end

  test "the stats page of a Pokemon whose IVs cannot be read says every star empty" do
    assert_equal [[page_line(stars(*Array.new(6, :iv_star_empty))), false]], stats_page(nil)
  end

  private

  def t(key, args = {}); PokeAccess::I18n.t(key, args); end

  # What the stats page says, drawn for a Pokemon of the builder's stats with these IVs.
  def stats_page(ivs)
    pk = Poke.build(:name => "Chispa", :iv => ivs)
    PokemonSummaryScene.new(pk).drawPageThree(pk)
    SpeakCapture.log
  end

  # The stats page's line for a Pokemon of the builder's stats: the stats, the stars sentence given, the ability.
  def page_line(each_star)
    stats = t(:sum_stats, :hp => 40, :tot => 40, :atk => 30, :def => 28, :spa => 32, :spd => 26, :spe => 35)
    "#{t(:sm_stats)}. #{stats} #{each_star} #{t(:sum_ability, :a => 'Habilidad1')}"
  end

  # The stars sentence, one star key per stat in the page's order.
  def stars(*keys)
    t(:iv_stars, :list => STATS.zip(keys).map { |stat, star| "#{t(stat)} #{t(star)}" }.join(", "))
  end
end
