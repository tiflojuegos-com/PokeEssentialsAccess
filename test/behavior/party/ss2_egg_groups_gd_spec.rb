# Soulstones 2's memo page egg groups, by the plugin's rule: Undiscovered for one that cannot breed, Unknown for a
# genderless Pokemon other than Ditto, else its groups once each.
class SS2EggPoke < TestPoke
  attr_accessor :groups, :noegg, :sexless, :ditto
  def species_data; Struct.new(:egg_groups).new(@groups); end
  def shadowPokemon?; @noegg ? true : false; end
  def genderless?; @sexless ? true : false; end
  def isSpecies?(s); @ditto && s == :DITTO; end
end

Suite.define("ss2 summary: the memo page says the egg groups its icons show") do
  t = PokeAccess::I18n
  sgd = PokeAccess::SummaryGameData
  meta = (class << sgd; self; end)
  meta.send(:alias_method, :ss2_spec_memo_extras, :memo_extras)
  made = !GameData.const_defined?(:EggGroup)
  GameData.const_set(:EggGroup, Class.new) if made
  GameData::EggGroup.define_singleton_method(:get) { |g| Struct.new(:name).new("Group#{g}") }
  begin
    eq "the stock page draws none", sgd.memo_extras(SS2EggPoke.build), []
    load File.expand_path("../../../games/soulstones2/egg_groups.rb", File.dirname(__FILE__))
    pk = SS2EggPoke.build(:name => "Charmander")
    pk.groups = [:Monster, :Dragon]
    eq "two groups, as the two icons", sgd.memo_extras(pk), [t.t(:sum_egg_groups, :g => "GroupMonster, GroupDragon")]
    pk.groups = [:Field, :Field]
    eq "the same group twice is one icon", sgd.memo_extras(pk), [t.t(:sum_egg_groups, :g => "GroupField")]
    pk.sexless = true
    eq "a genderless one gets the Unknown icon", sgd.memo_extras(pk),
       [t.t(:sum_egg_groups, :g => t.t(:egg_group_unknown))]
    pk.ditto = true
    eq "except Ditto, which shows its own group", sgd.memo_extras(pk), [t.t(:sum_egg_groups, :g => "GroupField")]
    pk.noegg = true
    eq "and one that cannot breed shows Undiscovered", sgd.memo_extras(pk),
       [t.t(:sum_egg_groups, :g => "GroupUndiscovered")]
    truthy "the memo page ends with them", sgd.memo_page_text(pk, nil).to_s.end_with?(t.t(:sum_egg_groups, :g => "GroupUndiscovered"))
  ensure
    meta.send(:alias_method, :memo_extras, :ss2_spec_memo_extras)
    meta.send(:remove_method, :ss2_spec_memo_extras)
    class << GameData::EggGroup; remove_method :get; end
    GameData.send(:remove_const, :EggGroup) if made
  end
end
