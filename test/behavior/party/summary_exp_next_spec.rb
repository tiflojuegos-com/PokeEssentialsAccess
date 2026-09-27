# Page one's experience to the next level on the gen-6 era (core/party/summary.rb exp_to_next): the page asks
# PBExperience for the start of the level above, which the table holds at its top level (MAXLEVEL, which a level cap
# such as Soulstones' sets), so a Pokemon at the top has 0 left, painted as such, not left out.
module ExpNextSpec
  Pk = Struct.new(:level, :exp, :growthrate, :ot, :publicID)

  # Runs the block with a PBExperience table of cubes that holds every level past top at top, taken away afterwards.
  def self.table(top)
    made = !Object.const_defined?(:PBExperience)
    if made
      tbl = Module.new
      tbl.const_set(:MAXLEVEL, top)
      tbl.define_singleton_method(:pbGetStartExperience) { |level, _growth| [level, tbl::MAXLEVEL].min ** 3 }
      Object.const_set(:PBExperience, tbl)
    end
    yield
  ensure
    Object.send(:remove_const, :PBExperience) if made
  end
end

Suite.define("summary, gen 6: at the top level the experience to the next one is 0, as the page paints it") do
  s = PokeAccess::Summary
  ExpNextSpec.table(25) do
    eq "below the top, what the next level still needs", s.exp_to_next(ExpNextSpec::Pk.new(24, 24 ** 3 + 10, 0)),
       25 ** 3 - (24 ** 3 + 10)
    eq "at the top, 0", s.exp_to_next(ExpNextSpec::Pk.new(25, 25 ** 3, 0)), 0
    facts = s.trainer_facts(ExpNextSpec::Pk.new(25, 25 ** 3, 0, "Red", 12345))
    eq "page one's lines end with it", facts.last(2),
       [PokeAccess::I18n.t(:sum_exp, :n => 25 ** 3), PokeAccess::I18n.t(:sum_exp_next, :n => 0)]
  end
end
