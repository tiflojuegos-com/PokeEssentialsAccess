# MapMeta reads GameData::MapMetadata: outdoors, the map under the sea, and whether the bike is kept on (a cycling
# road, where the route finder offers neither Surf nor getting off).
Suite.define("map meta (modern): outdoors, the map under the sea and the bike kept on, from GameData") do
  mm = PokeAccess::MapMeta
  md = GameData::MapMetadata
  row = Struct.new(:outdoor_map, :dive_map_id, :always_bicycle)
  table = { 10 => row.new(true, 44, false), 11 => row.new(false, nil, true) }
  class << md
    alias_method :spec_try_get, :try_get
  end
  md.instance_variable_set(:@spec_table, table)
  def md.try_get(i); @spec_table[i]; end
  begin
    truthy "an outdoor map", mm.outdoor?(10)
    eq "and the map under its sea", mm.dive_map(10), 44
    falsy "where the bike comes off as usual", mm.always_bicycle?(10)
    truthy "a cycling road keeps it on", mm.always_bicycle?(11)
    falsy "and is indoors", mm.outdoor?(11)
    falsy "a map with no metadata keeps nobody on the bike", mm.always_bicycle?(12)
  ensure
    class << md
      alias_method :try_get, :spec_try_get
      remove_method :spec_try_get
    end
  end
end
