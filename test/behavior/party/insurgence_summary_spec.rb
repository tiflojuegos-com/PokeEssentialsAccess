# Insurgence's six-page summary (games/insurgence/summary.rb): what the core reads as page 4 is its EV & IV page and
# page 5 its moves, each stat in the page's own order. The profile's module alone is loaded: its override belongs to
# the Insurgence process (insurgence_profile_spec).
unless defined?(PokeAccess::InsurgenceSummary)
  path = File.join(Harness::ROOT, "games", "insurgence", "summary.rb")
  eval(File.read(path)[/^module PokeAccess\r?\n.*?^end\r?\n/m], TOPLEVEL_BINDING, path)
end

Suite.define("insurgence summary: the EV & IV page says each stat's EV and IV, speed last as painted") do
  t = PokeAccess::I18n
  pk = Poke.build(:ev => [4, 252, 0, 6, 0, 248], :iv => [31, 30, 29, 28, 27, 26])
  row = lambda { |key, ev, iv| t.t(:sm_eviv_row, :stat => t.t(key), :ev => ev, :iv => iv) }
  rows = [row.call(:st_hp, 4, 31), row.call(:st_atk, 252, 30), row.call(:st_def, 0, 29),
          row.call(:st_spatk, 0, 27), row.call(:st_spdef, 248, 26), row.call(:st_speed, 6, 28)]
  eq "the title, then the rows by the PBStats index each paints (speed is 3, painted last)",
     PokeAccess::InsurgenceSummary.eviv_text(pk), "#{t.t(:ins_sum_eviv)}. #{rows.join('. ')}"
  eq "a Pokemon it cannot read gives nothing, not half a page", PokeAccess::InsurgenceSummary.eviv_text(nil), nil
end

Suite.define("insurgence summary: the core's page 4 becomes EV & IV, page 5 the moves, and the rest pass untouched") do
  pk = Poke.build(:ev => [1, 2, 3, 4, 5, 6])
  s = World.stub_scene
  four = [s, pk, 4, "moves as the stock page four"]
  PokeAccess::InsurgenceSummary.repage(four)
  eq "page 4 (drawPageFour) is read as the EV & IV page", four[3], PokeAccess::InsurgenceSummary.eviv_text(pk)
  five = [s, pk, 5, "ribbons as the stock page five"]
  PokeAccess::InsurgenceSummary.repage(five)
  eq "page 5 (drawPageFive) is read as the moves", five[3], PokeAccess::Summary.moves_text(pk)
  [1, 2, 3, 6, :egg].each do |page|
    a = [s, pk, page, "as the core read it"]
    PokeAccess::InsurgenceSummary.repage(a)
    eq "page #{page} keeps the core's text", a[3], "as the core read it"
  end
end
