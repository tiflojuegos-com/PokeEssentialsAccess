# Summary.eviv_rows, the EV and IV rows the five-page summaries (Insurgence, Soulstones 1, the Reborn engine) list:
# the stock gen-6 order with speed last by default, or the order an engine numbers its stats in.
Suite.define("summary: an EV and IV page's rows, in the stock order or the one given") do
  t = PokeAccess::I18n
  pk = Poke.build(:name => "Chispa")
  pk.define_singleton_method(:ev) { [10, 20, 30, 40, 50, 60] }
  pk.define_singleton_method(:iv) { [1, 2, 3, 4, 5, 6] }
  row = lambda { |key, ev, iv| t.t(:sm_eviv_row, :stat => t.t(key), :ev => ev, :iv => iv) }
  eq "speed, stat 3, last", PokeAccess::Summary.eviv_rows(pk),
     [row.call(:st_hp, 10, 1), row.call(:st_atk, 20, 2), row.call(:st_def, 30, 3), row.call(:st_spatk, 50, 5),
      row.call(:st_spdef, 60, 6), row.call(:st_speed, 40, 4)]
  eq "or the engine's own order", PokeAccess::Summary.eviv_rows(pk, [[3, :st_speed], [0, :st_hp]]),
     [row.call(:st_speed, 40, 4), row.call(:st_hp, 10, 1)]
end
