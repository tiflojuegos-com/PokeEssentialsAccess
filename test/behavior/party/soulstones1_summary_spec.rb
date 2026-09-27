# Soulstones' five-page summary (games/soulstones1/summary.rb): what the core reads as page 4 is its EVs/IVs page, with
# the ability it names under the rows and the description it writes below, and page 5 its moves. The profile's module
# alone is loaded: its override belongs to the Soulstones process.
unless defined?(PokeAccess::Soulstones1Summary)
  path = File.join(Harness::ROOT, "games", "soulstones1", "summary.rb")
  eval(File.read(path)[/^module PokeAccess\r?\n.*?^end\r?\n/m], TOPLEVEL_BINDING, path)
end

Suite.define("soulstones1 summary: the EVs/IVs page says each stat's EV and IV as painted, then the ability") do
  t = PokeAccess::I18n
  had_descs = MessageTypes.const_defined?(:AbilityDescs)
  MessageTypes.const_set(:AbilityDescs, 7) unless had_descs
  begin
    pk = Poke.build(:ev => [4, 252, 0, 6, 0, 248], :iv => [31, 30, 29, 28, 27, 26], :ability => 65)
    row = lambda { |key, ev, iv| t.t(:sm_eviv_row, :stat => t.t(key), :ev => ev, :iv => iv) }
    rows = [row.call(:st_hp, 4, 31), row.call(:st_atk, 252, 30), row.call(:st_def, 0, 29),
            row.call(:st_spatk, 0, 27), row.call(:st_spdef, 248, 26), row.call(:st_speed, 6, 28)]
    desc = PokeAccess::Data.ability_description(65)
    truthy "the game has a description for the ability", desc && !desc.to_s.empty?
    ab = t.t(:sum_ability_desc, :a => PokeAccess::Data.ability_name(65), :d => desc)
    eq "the ability with the description the page writes under its name, as the skills page says it",
       PokeAccess::Soulstones1Summary.ability_text(pk), ab
    eq "the title, the rows by the PBStats index each paints (speed is 3, painted last), then the ability",
       PokeAccess::Soulstones1Summary.eviv_text(pk), "#{t.t(:ss1_sum_eviv)}. #{(rows + [ab]).join('. ')}"
    eq "a Pokemon it cannot read gives nothing, not half a page", PokeAccess::Soulstones1Summary.eviv_text(nil), nil
  ensure
    MessageTypes.send(:remove_const, :AbilityDescs) unless had_descs
  end
end

Suite.define("soulstones1 summary: the core's page 4 becomes EVs/IVs, page 5 the moves, and the rest pass untouched") do
  pk = Poke.build(:ev => [1, 2, 3, 4, 5, 6])
  s = World.stub_scene
  four = [s, pk, 4, "moves as the stock page four"]
  PokeAccess::Soulstones1Summary.repage(four)
  eq "page 4 (drawPageFour) is read as the EVs/IVs page", four[3], PokeAccess::Soulstones1Summary.eviv_text(pk)
  five = [s, pk, 5, "ribbons as the stock page five"]
  PokeAccess::Soulstones1Summary.repage(five)
  eq "page 5 (drawPageFive) is read as the moves", five[3], PokeAccess::Summary.moves_text(pk)
  [1, 2, 3, :egg].each do |page|
    a = [s, pk, page, "as the core read it"]
    PokeAccess::Soulstones1Summary.repage(a)
    eq "page #{page} keeps the core's text", a[3], "as the core read it"
  end
end
