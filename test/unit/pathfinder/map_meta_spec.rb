# A map's metadata as gen-6 keeps it, in pbGetMetadata rows read by field index: outdoors (1), the bike kept
# on (4, Cycling Road) and the map under the sea (8).
Suite.define("map meta (gen-6): outdoors, the bike kept on and the map under the sea, from pbGetMetadata") do
  mm = PokeAccess::MapMeta
  had = Object.private_method_defined?(:pbGetMetadata)
  rows = { 20 => { 1 => true, 4 => false, 8 => 51 }, 21 => { 1 => false, 4 => true } }
  $map_meta_spec_rows = rows
  Object.class_eval do
    alias_method :spec_pbGetMetadata, :pbGetMetadata if had
    def pbGetMetadata(mid, field); ($map_meta_spec_rows[mid] || {})[field]; end
    private :pbGetMetadata
  end
  begin
    truthy "an outdoor map", mm.outdoor?(20)
    eq "with a sea above map 51", mm.dive_map(20), 51
    falsy "the bike comes off as usual", mm.always_bicycle?(20)
    truthy "a cycling road keeps it on", mm.always_bicycle?(21)
    falsy "a map with no row keeps nobody on the bike", mm.always_bicycle?(22)
  ensure
    Object.class_eval do
      if had
        alias_method :pbGetMetadata, :spec_pbGetMetadata
        remove_method :spec_pbGetMetadata
      else
        remove_method :pbGetMetadata
      end
    end
  end
end
