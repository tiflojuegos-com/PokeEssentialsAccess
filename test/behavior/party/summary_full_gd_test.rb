# The modern summary says what each page shows: page one's header, data and trainer lines, the memo's own paragraph,
# the stats page's nature effect and ability text (and the IV/EV columns a game's page adds), and each move's type.
class SummaryFullGdTest < PokeAccessTest
  T = PokeAccess::I18n
  SGD = PokeAccess::SummaryGameData
  MALE = "\xE2\x99\x82"
  # The paragraph a Shadow Pokemon's page one paints in place of the experience.
  HEART = "La puerta de su corazón está cerrada."

  # A modern Pokemon as the summary asks it: owner, experience, growth rate, species, types and an ability object.
  class FullPoke < TestPoke
    attr_accessor :exp
    Owner = Struct.new(:name, :public_id)
    Ability = Struct.new(:id, :name, :description)
    Rate = Struct.new(:per_level) do
      def minimum_exp_for_level(level); level * per_level; end
    end
    def owner; Owner.new("Ceniza", 1234); end
    def growth_rate; Rate.new(100); end
    def ability; Ability.new(:STATIC, "Electricidad Estatica", "Puede paralizar al contacto."); end
    def speciesName; "Pikachu"; end
    def types; [:ELECTRIC]; end
    def item; nil; end
  end

  # A Pokemon whose nature raises Attack and lowers Special Attack, with the IVs and EVs the columns write.
  class NaturedPoke < FullPoke
    Nature = Struct.new(:name, :stat_changes)
    def nature; Nature.new("Firme", [[:ATTACK, 10], [:SPECIAL_ATTACK, -10]]); end
    def iv; { :HP => 31, :ATTACK => 30, :DEFENSE => 29, :SPECIAL_ATTACK => 28, :SPECIAL_DEFENSE => 27, :SPEED => 26 }; end
    def ev; { :HP => 4, :ATTACK => 252, :DEFENSE => 0, :SPECIAL_ATTACK => 0, :SPECIAL_DEFENSE => 0, :SPEED => 252 }; end
  end

  # The same Pokemon after a mint: its stats play with another nature.
  class MintedPoke < NaturedPoke
    def nature_for_stats; Nature.new("Miedosa", [[:SPEED, 10], [:ATTACK, -10]]); end
  end

  # An engine's data answering an ability's descriptions (the full one, and the short one only some engines keep) and
  # the nature stats only some keep.
  class ExtraData
    def ability_description(id); { :STATIC => "Puede paralizar al contacto." }[id]; end
    def ability_summary(_id); "Paraliza."; end
    def nature_stats(nature); { :ADAMANT => [:ATTACK, :SPECIAL_ATTACK], :HARDY => [:ATTACK, :ATTACK] }[nature]; end
    def stat_name(stat); { :ATTACK => "Ataque", :SPECIAL_ATTACK => "Ataque Especial" }[stat]; end
  end

  # An engine's data that names every type, and every move's type, blank.
  class BlankTypes
    def type_name(_type); ""; end
    def move_type_name(_move); ""; end
  end

  test "page one says the name, species, type, item and trainer lines in the page's order" do
    assert_equal page_one("Chispa", 12, *chispa_data, trainer_lines(true)), SGD.info_text(chispa)
  end

  test "page one says the Pokedex number the page paints after the header" do
    assert_equal page_one("Chispa", 12, T.t(:sum_dex, :n => "025"), *chispa_data, trainer_lines(true)),
                 SGD.info_text(chispa, "025")
  end

  test "page one says the header's icons right after the name" do
    pk = chispa
    pk.shiny = true
    assert_equal page_one("Chispa", 12, "#{T.t(:pk_shiny)}.", *chispa_data, trainer_lines(true)), SGD.info_text(pk)
  end

  test "page one of a Pokemon with no species or types leaves both out" do
    blank = Poke.build(:name => "Pika", :level => 20)
    def blank.speciesName; ""; end
    def blank.types; []; end
    want = page_one("Pika", 20, T.t(:sum_item, :i => T.t(:sum_none)), T.t(:sum_ot, :name => T.t(:sum_loaned)),
                    T.t(:sum_id, :id => T.t(:pdx_unknown_short)))
    assert_equal want, SGD.info_text(Poke.build(:name => "Pika", :level => 20)), "none asked of it"
    assert_equal want, SGD.info_text(blank), "a blank species and no types"
  end

  test "page one names the held item: an id through the data, an object by its own name, else none" do
    nameless = Struct.new(:name).new("")
    [[:POTION, "ItemPOTION"], [Struct.new(:name).new("Baya"), "Baya"], [nameless, T.t(:sum_none)],
     [0, T.t(:sum_none)], [nil, T.t(:sum_none)]].each do |item, name|
      assert_equal T.t(:sum_item, :i => name), PokeAccess::Summary.item_fact(Poke.build(:item => item)), item.inspect
    end
  end

  test "page one says the sex the original trainer's name is tinted with, by the owner's gender" do
    { 0 => "Ceniza, #{T.t(:chr_male)}", 1 => "Ceniza, #{T.t(:chr_female)}", 2 => "Ceniza" }.each do |gender, name|
      assert_equal T.t(:sum_ot, :name => name), PokeAccess::Summary.trainer_facts(owned_by(gender))[0], "gender #{gender}"
    end
  end

  test "page one of a Pokemon at the level cap has no experience to the next level" do
    pk = FullPoke.build(:name => "Chispa", :level => 100)
    pk.exp = 1250
    assert_equal page_one("Chispa", 100, *chispa_data, T.t(:sum_ot, :name => "Ceniza"), T.t(:sum_id, :id => "01234"),
                          T.t(:sum_exp, :n => 1250)), SGD.info_text(pk)
  end

  test "a Shadow Pokemon's page one ends on its heart paragraph in place of the experience" do
    pk = chispa
    def pk.shadowPokemon?; true; end
    assert_equal [[page_one("Chispa", 12, *chispa_data, trainer_lines(false), HEART), false]], opened_with_heart(pk)
  end

  test "the paragraphs page one paints are no heart for a Pokemon that is not a Shadow" do
    pk = chispa
    assert_equal [[page_one("Chispa", 12, *chispa_data, trainer_lines(true)), false]], opened_with_heart(pk)
  end

  test "the memo reads the page's own paragraph, one sentence per line, the colour codes gone" do
    painted = ["<c3=F83818,E09890>Naturaleza Firme.\n<c3=404040,B0B0B0>18 septiembre, 2026\nRuta 3\n" \
               "Encontrado con Nv. 5.\n\nLe encanta comer."]
    assert_equal "#{T.t(:sm_memo)}. Naturaleza Firme. 18 septiembre, 2026. Ruta 3. Encontrado con Nv. 5. Le encanta comer.",
                 SGD.memo_text(chispa, painted)
  end

  test "with nothing painted the memo says the nature" do
    assert_equal "#{T.t(:sm_memo)}. #{T.t(:sm_nature, :n => 'Firme')}.", SGD.memo_text(NaturedPoke.build(:name => "Chispa"), [])
  end

  test "with nothing painted and no nature to name, the memo is its heading alone" do
    nameless = NaturedPoke.build(:name => "Chispa")
    def nameless.nature; NaturedPoke::Nature.new("", []); end
    [chispa, nameless].each { |pk| assert_equal "#{T.t(:sm_memo)}.", SGD.memo_text(pk, nil), pk.nature.inspect }
  end

  test "the memo page adds what the game draws beside the memo" do
    pk = chispa
    def pk.hptype; :FIRE; end
    assert_equal "#{T.t(:sm_memo)}. #{T.t(:sm_hidden_power, :t => 'TypeFIRE')}", SGD.page_text(scene_of(pk), 2)
  end

  test "the classic numbering reads pages one to five as the data, memo, stats, moves and ribbons" do
    pk = Poke.build(:name => "Pika", :level => 20)
    want = { 1 => SGD.info_text(pk), 2 => "#{T.t(:sm_memo)}.", 3 => stats_page(T.t(:sum_ability, :a => "Ability1")),
             4 => T.t(:sm_no_moves), 5 => T.t(:sm_ribbons_none) }
    want.each { |page, text| assert_equal text, SGD.page_text(scene_of(pk), page), "page #{page}" }
    assert_nil SGD.page_text(scene_of(pk), 6), "there is no page six"
  end

  test "a plugin's page order reads each page by its id, and leaves the egg page to the egg reader" do
    pk = Poke.build(:name => "Pika", :level => 20)
    want = { :page_info => SGD.info_text(pk), :page_memo => "#{T.t(:sm_memo)}.",
             :page_skills => stats_page(T.t(:sum_ability, :a => "Ability1")), :page_moves => T.t(:sm_no_moves),
             :page_ribbons => T.t(:sm_ribbons_none) }
    want.each { |id, text| assert_equal text, SGD.page_text(scene_of(pk, id), 1), id.inspect }
    assert_nil SGD.page_text(scene_of(pk, :page_egg), 1), "the egg page"
  end

  test "a summary showing no Pokemon has no page to say" do
    assert_nil SGD.page_text(World.stub_scene(:@pokemon => nil), 1)
  end

  test "the stats page ends with the ability and the description the page writes under it" do
    assert_equal stats_page(ability_desc), SGD.stats_text(chispa)
  end

  test "a page that paints the description has it said, and one that keeps it behind a button only the name" do
    assert_equal stats_page(ability_desc), SGD.stats_text(chispa, ["Electricidad Estatica", "Puede paralizar al contacto."])
    assert_equal stats_page(T.t(:sum_ability, :a => "Electricidad Estatica")),
                 SGD.stats_text(chispa, ["Electricidad Estatica", "Detalles"]), "behind a Details button"
  end

  test "a page that paints the engine's short description has that one said" do
    Harness.with_provider(ExtraData.new, 30) do
      assert_equal stats_page(T.t(:sum_ability_desc, :a => "Electricidad Estatica", :d => "Paraliza.")),
                   SGD.stats_text(chispa, ["Electricidad Estatica", "Paraliza."])
    end
  end

  test "an ability kept as a bare id is named through the data" do
    assert_equal stats_page(T.t(:sum_ability, :a => "AbilitySTATIC")), SGD.stats_text(Poke.build(:ability => :STATIC))
  end

  test "an ability with no description of its own says the one the data gives its id" do
    ability = Struct.new(:id, :name).new(:STATIC, "Electricidad")
    Harness.with_provider(ExtraData.new, 30) do
      assert_equal stats_page(T.t(:sum_ability_desc, :a => "Electricidad", :d => "Puede paralizar al contacto.")),
                   SGD.stats_text(Poke.build(:ability => ability))
    end
  end

  test "no ability, or a nameless one, adds no ability sentence" do
    [nil, 0, Struct.new(:id, :name).new(:STATIC, "")].each do |ability|
      assert_equal stats_page, SGD.stats_text(Poke.build(:ability => ability)), ability.inspect
    end
  end

  test "the stats page says the stats the nature raises and lowers, as the coloured labels show them" do
    assert_equal stats_page(effect("StatATTACK", "StatSPECIAL_ATTACK"), ability_desc),
                 SGD.stats_text(NaturedPoke.build(:name => "Chispa"))
  end

  test "after a mint, the stock page colours the stats the mint's nature moves" do
    assert_equal stats_page(effect("StatSPEED", "StatATTACK"), ability_desc), SGD.stats_text(MintedPoke.build(:name => "Chispa"))
  end

  test "a stat the nature leaves alone is neither raised nor lowered, and a neutral nature colours none" do
    alone = NaturedPoke.build(:name => "Chispa")
    def alone.nature; NaturedPoke::Nature.new("Firme", [[:ATTACK, 10], [:SPECIAL_ATTACK, -10], [:SPEED, 0]]); end
    neutral = NaturedPoke.build(:name => "Chispa")
    def neutral.nature; NaturedPoke::Nature.new("Fuerte", []); end
    assert_equal stats_page(effect("StatATTACK", "StatSPECIAL_ATTACK"), ability_desc), SGD.stats_text(alone)
    assert_equal stats_page(ability_desc), SGD.stats_text(neutral), "a neutral nature"
  end

  test "a nature kept as an id is coloured by the stats the engine's data gives it" do
    Harness.with_provider(ExtraData.new, 30) do
      assert_equal stats_page(effect("Ataque", "Ataque Especial")),
                   SGD.stats_text(Poke.build(:nature => :ADAMANT, :ability => nil))
      assert_equal stats_page, SGD.stats_text(Poke.build(:nature => :HARDY, :ability => nil)),
                   "a nature that raises what it lowers"
    end
  end

  test "a Shadow Pokemon past heart stage 3 has its nature uncoloured" do
    coloured = stats_page(effect("StatATTACK", "StatSPECIAL_ATTACK"), ability_desc)
    { 3 => coloured, 4 => stats_page(ability_desc) }.each do |stage, want|
      pk = NaturedPoke.build(:name => "Chispa")
      pk.define_singleton_method(:shadowPokemon?) { true }
      pk.define_singleton_method(:heartStage) { stage }
      assert_equal want, SGD.stats_text(pk), "heart stage #{stage}"
    end
  end

  test "the moves page names each move with its type and pp" do
    move = Struct.new(:id, :name, :type, :pp, :total_pp).new(:THUNDERBOLT, "Rayo", :TYPE1, 15, 15)
    assert_equal T.t(:sm_moves, :list => "Rayo. #{T.t(:mv_type, :t => 'TypeTYPE1')}. #{T.t(:mv_pp, :pp => 15, :tot => 15)}"),
                 PokeAccess::Summary.moves_text(FullPoke.build(:name => "Chispa", :moves => [move]))
  end

  test "a move whose shown type is not its own says the shown one, as its icon does" do
    hidden = Struct.new(:id, :name, :type, :pp, :total_pp).new(:HIDDENPOWER, "Poder Oculto", :NORMAL, 15, 15)
    def hidden.display_type(_pkmn); :FIRE; end
    assert_equal T.t(:sm_moves, :list => "Poder Oculto. #{T.t(:mv_type, :t => 'TypeFIRE')}. " \
                                         "#{T.t(:mv_pp, :pp => 15, :tot => 15)}"),
                 PokeAccess::Summary.moves_text(FullPoke.build(:name => "Chispa", :moves => [hidden]))
  end

  test "a move whose type the data names blank says no type" do
    move = Struct.new(:id, :name, :type, :pp, :total_pp).new(:THUNDERBOLT, "Rayo", :TYPE1, 15, 15)
    Harness.with_provider(BlankTypes.new, 30) do
      assert_equal T.t(:sm_moves, :list => "Rayo. #{T.t(:mv_pp, :pp => 15, :tot => 15)}"),
                   PokeAccess::Summary.moves_text(FullPoke.build(:name => "Chispa", :moves => [move]))
    end
  end

  test "a Pokemon with no moves says it has none, and one whose moves cannot be read says nothing" do
    assert_equal T.t(:sm_no_moves), PokeAccess::Summary.moves_text(Poke.build(:moves => []))
    assert_nil PokeAccess::Summary.moves_text(Poke.build(:moves => nil)), "no move list at all"
  end

  test "the IV/EV columns write each stat's IV and EV, the special attack row the effort of the stat a game puts there" do
    pk = NaturedPoke.build(:name => "Chispa")
    assert_equal iv_ev(0), SGD.iv_ev_text(pk), "the special attack row's own effort"
    assert_equal iv_ev(252), SGD.iv_ev_text(pk, :ATTACK), "Attack's, where the game shows it on that row"
  end

  test "a Pokemon whose IVs cannot be read has no IV/EV columns" do
    assert_nil SGD.iv_ev_text(Poke.build(:iv => nil))
  end

  test "with Fire Ash's page the IVs and EVs follow the stats, before the nature and the ability" do
    with_profile_file("games/fireash/summary_ivs.rb") do
      assert_equal stats_page(iv_ev(0), effect("StatATTACK", "StatSPECIAL_ATTACK"), ability_desc),
                   SGD.stats_text(NaturedPoke.build(:name => "Chispa"))
    end
  end

  test "Fire Ash's page colours by the Pokemon's own nature, mint or not" do
    with_profile_file("games/fireash/summary_ivs.rb") do
      assert_equal stats_page(iv_ev(0), effect("StatATTACK", "StatSPECIAL_ATTACK"), ability_desc),
                   SGD.stats_text(MintedPoke.build(:name => "Chispa"))
    end
  end

  test "Fire Ash's page leaves a Shadow Pokemon's nature uncoloured up to heart stage 3" do
    with_profile_file("games/fireash/summary_ivs.rb") do
      { 3 => [], 4 => [effect("StatATTACK", "StatSPECIAL_ATTACK")] }.each do |stage, nature|
        pk = NaturedPoke.build(:name => "Chispa")
        pk.define_singleton_method(:shadowPokemon?) { true }
        pk.define_singleton_method(:heartStage) { stage }
        assert_equal stats_page(iv_ev(0), *nature, ability_desc), SGD.stats_text(pk), "heart stage #{stage}"
      end
    end
  end

  test "ZUD's Dynamax meter is said below Fire Ash's IV/EV columns, whatever the kit's switch says" do
    with_profile_file("games/fireash/summary_ivs.rb") do
      with_dynamax_switch(498) do
        assert_equal stats_page(iv_ev(0), T.t(:dmax_level, :n => 7), effect("StatATTACK", "StatSPECIAL_ATTACK"), ability_desc),
                     SGD.stats_text(dynamax_chispa)
      end
    end
  end

  test "Soulstones 2's columns show Attack's effort on the special attack row outside purist mode" do
    with_profile_file("games/soulstones2/summary_ivs.rb") do
      assert_equal stats_page(iv_ev(252), effect("StatATTACK", "StatSPECIAL_ATTACK"), ability_desc),
                   SGD.stats_text(NaturedPoke.build(:name => "Chispa"))
    end
  end

  test "Soulstones 2's columns in purist mode show each row's own effort" do
    with_profile_file("games/soulstones2/summary_ivs.rb") do
      with_setting(:PURIST_MODE, true) do
        assert_equal stats_page(iv_ev(0), effect("StatATTACK", "StatSPECIAL_ATTACK"), ability_desc),
                     SGD.stats_text(NaturedPoke.build(:name => "Chispa"))
      end
    end
  end

  test "another extra of the stats page, ZUD's Dynamax meter here, is said below Soulstones 2's IV/EV columns" do
    with_profile_file("games/soulstones2/summary_ivs.rb") do
      assert_equal stats_page(iv_ev(252), T.t(:dmax_level, :n => 7), effect("StatATTACK", "StatSPECIAL_ATTACK"), ability_desc),
                   SGD.stats_text(dynamax_chispa)
    end
  end

  private

  # The modern Pokemon the page-one tests show: Chispa, level 12, 1250 experience points.
  def chispa
    pk = FullPoke.build(:name => "Chispa", :level => 12)
    pk.exp = 1250
    pk
  end

  # Chispa with Ceniza as her owner, of gender as v19+ keeps it (0 a boy, 1 a girl, 2 neither).
  def owned_by(gender)
    pk = chispa
    owner = Struct.new(:name, :public_id, :gender).new("Ceniza", 1234, gender)
    pk.define_singleton_method(:owner) { owner }
    pk
  end

  # Page one of a male Pokemon named name at level: its heading, then the given sentences.
  def page_one(name, level, *parts)
    ([T.t(:sum_data_of, :name => "#{name} #{MALE}", :level => level)] + parts).join(" ")
  end

  # Chispa's species, type and item sentences.
  def chispa_data
    [T.t(:sum_species, :s => "Pikachu"), T.t(:sum_type, :t => "TypeELECTRIC"), T.t(:sum_item, :i => T.t(:sum_none))]
  end

  # Chispa's trainer lines: Ceniza and the padded ID, then (unless a Shadow's) the experience and the 50 left to level 13.
  def trainer_lines(with_exp)
    lines = [T.t(:sum_ot, :name => "Ceniza"), T.t(:sum_id, :id => "01234")]
    lines += [T.t(:sum_exp, :n => 1250), T.t(:sum_exp_next, :n => 50)] if with_exp
    lines.join(" ")
  end

  # What opening the summary on pk says, its page one painting the heart paragraph as a formatted text.
  def opened_with_heart(pk)
    scene = PokemonSummary_Scene.new
    scene.on_draw = lambda { |_page| drawFormattedTextEx(nil, 0, 0, 200, HEART) }
    scene.pbStartScene([pk], 0)
    SpeakCapture.log.dup
  end

  # A summary scene showing pk, numbered by a plugin's page id or (nil) classically.
  def scene_of(pk, page_id = nil)
    World.stub_scene(:@pokemon => pk, :@page_id => page_id)
  end

  # The stats page of a stub Pokemon: the heading and the stats, then the given parts in order.
  def stats_page(*parts)
    ["#{T.t(:sm_stats)}.", T.t(:sum_stats, :hp => 40, :tot => 40, :atk => 30, :def => 28, :spa => 32, :spd => 26, :spe => 35),
     *parts].join(" ")
  end

  # Chispa's ability with the description the page writes under it.
  def ability_desc
    T.t(:sum_ability_desc, :a => "Electricidad Estatica", :d => "Puede paralizar al contacto.")
  end

  # The nature's effect sentence for the stats raised and lowered.
  def effect(up, down)
    T.t(:sm_nature_effect, :up => up, :down => down)
  end

  # NaturedPoke's IV/EV columns, with sae the effort written on the special attack row.
  def iv_ev(sae)
    T.t(:sm_ivev, :hpi => 31, :hpe => 4, :ai => 30, :ae => 252, :di => 29, :de => 0, :sai => 28, :sae => sae,
                  :sdi => 27, :sde => 0, :si => 26, :se => 252)
  end

  # A NaturedPoke that can Dynamax, at Dynamax level 7 (ZUD's question).
  def dynamax_chispa
    pk = NaturedPoke.build(:name => "Chispa")
    pk.define_singleton_method(:dynamaxAble?) { true }
    pk.define_singleton_method(:dynamax_lvl) { 7 }
    pk
  end

  # Runs the block with a profile's summary file evaluated as boot does, its overrides and its profile name taken back
  # out after.
  def with_profile_file(rel)
    extras = SGD.method(:stats_extras)
    nature = PokeAccess::Summary.method(:stats_nature)
    profiles = PokeAccess::Game.profiles.dup
    overrides = PokeAccess::Hooks.overrides.length
    path = File.join(Harness::ROOT, rel)
    eval(Harness.source(path), TOPLEVEL_BINDING, path)
    yield
  ensure
    SGD.define_singleton_method(:stats_extras, extras)
    PokeAccess::Summary.define_singleton_method(:stats_nature, nature)
    PokeAccess::Game.profiles.replace(profiles)
    PokeAccess::Hooks.overrides.slice!(overrides..-1)
  end

  # Runs the block with the Deluxe Battle Kit's no-Dynamax switch declared as switch and turned on.
  def with_dynamax_switch(switch)
    with_setting(:NO_DYNAMAX, switch) do
      $game_switches[switch] = true
      begin
        yield
      ensure
        $game_switches[switch] = false
      end
    end
  end

  # Runs the block with ::Settings::name set to value, the game's own value (or none) put back after.
  def with_setting(name, value)
    had = ::Settings.const_defined?(name, false)
    was = had ? ::Settings.const_get(name) : nil
    ::Settings.send(:remove_const, name) if had
    ::Settings.const_set(name, value)
    yield
  ensure
    ::Settings.send(:remove_const, name) if ::Settings.const_defined?(name, false)
    ::Settings.const_set(name, was) if had
  end
end
