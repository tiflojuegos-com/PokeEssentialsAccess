# Enhanced Pokemon UI's second face of the stats page (@statToggle): each stat's effort and individual values, their
# totals, the effort points left and Hidden Power's type, read while it is up.
Suite.define("summary (modern): the stats page's effort/individual face is read while it is up") do
  t = PokeAccess::I18n
  stat = Struct.new(:id, :name)
  stats = [stat.new(:HP, "PS"), stat.new(:ATTACK, "Ataque"), stat.new(:SPEED, "Velocidad")]
  had_each = GameData::Stat.respond_to?(:each_main)
  GameData::Stat.define_singleton_method(:each_main) { |&b| stats.each(&b) } unless had_each
  made_pokemon = !Object.const_defined?(:Pokemon)
  Object.const_set(:Pokemon, Class.new) if made_pokemon
  made_limit = !::Pokemon.const_defined?(:EV_LIMIT)
  ::Pokemon.const_set(:EV_LIMIT, 510) if made_limit
  Object.send(:define_method, :pbHiddenPower) { |_pk| [:FIRE, 60] }
  begin
    pk = Poke.build(:name => "Chispa", :ev => { :HP => 4, :ATTACK => 252, :SPEED => 252 },
                    :iv => { :HP => 31, :ATTACK => 20, :SPEED => 31 })
    scene = Object.new
    scene.instance_variable_set(:@pokemon, pk)
    scene.instance_variable_set(:@page_id, :page_skills)
    stats_face = PokeAccess::SummaryGameData.page_text(scene, 3)
    scene.instance_variable_set(:@statToggle, true)
    eq "flipped: each stat's effort and individual values, their totals, the points left and Hidden Power's type",
       PokeAccess::SummaryGameData.page_text(scene, 3),
       [t.t(:sm_stats), t.t(:sm_eviv_row, :stat => "PS", :ev => 4, :iv => 31),
        t.t(:sm_eviv_row, :stat => "Ataque", :ev => 252, :iv => 20),
        t.t(:sm_eviv_row, :stat => "Velocidad", :ev => 252, :iv => 31),
        t.t(:sm_eviv_total, :ev => 508, :iv => 82), t.t(:sm_ev_left, :n => 2, :max => 510),
        t.t(:sm_hidden_power, :t => "TypeFIRE")].join(". ")
    truthy "which is not the stats face, so the flip is heard", stats_face != PokeAccess::SummaryGameData.page_text(scene, 3)
    scene.instance_variable_set(:@page_id, nil)
    eq "the classic numbering's page three flips the same way", PokeAccess::SummaryGameData.page_text(scene, 3),
       PokeAccess::SummaryGameData.eviv_text(pk)
    scene.instance_variable_set(:@statToggle, false)
    eq "and flipped back it is the stats page again", PokeAccess::SummaryGameData.page_text(scene, 3), stats_face
  ensure
    class << GameData::Stat; remove_method :each_main; end unless had_each
    ::Pokemon.send(:remove_const, :EV_LIMIT) if made_limit && !made_pokemon
    Object.send(:remove_const, :Pokemon) if made_pokemon
    Object.send(:remove_method, :pbHiddenPower)
  end
end
