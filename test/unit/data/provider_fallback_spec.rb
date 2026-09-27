require "tempfile"

# With no engine provider registered, DataFallback (priority 0) answers with the raw id; the harness always has a
# real one, so this runs in a child Ruby that loads only the data layer and the fallback.
Suite.define("data: emergency fallback speaks the raw id") do
  root = File.expand_path("../../..", File.dirname(__FILE__))
  script = <<-RUBY
    module PokeAccess; def self.write_marker(*); end; end
    load File.expand_path("core/data/data.rb", #{root.inspect})
    load File.expand_path("core/data/data_fallback.rb", #{root.inspect})
    d = PokeAccess::Data
    bad = []
    chk = lambda { |n, c| bad << n unless c }
    chk.call("fallback is the active provider", d.active == PokeAccess::DataFallback)
    chk.call("active_priority is 0 (emergency)", d.active_priority == 0)
    chk.call("move_name raw id", d.move_name(:TACKLE) == "TACKLE")
    chk.call("item_name raw id", d.item_name(:POTION) == "POTION")
    chk.call("species_name raw id", d.species_name(7) == "7")
    chk.call("move_power nil", d.move_power(:TACKLE).nil?)
    chk.call("pokemon_types empty", d.pokemon_types(nil) == [])
    chk.call("species_entry id only", d.species_entry(:X) == ["X", nil, nil])
    chk.call("species_types empty", d.species_types(:X) == [])
    chk.call("trainer_type_name nil", d.trainer_type_name(:X).nil?)
    print(bad.empty? ? "OK" : "FAIL: " + bad.join(", "))
  RUBY
  file = Tempfile.new(["pa_fallback", ".rb"])
  begin
    file.write(script); file.close
    out = `ruby "#{file.path}" 2>&1`
  ensure
    file.unlink
  end
  eq "isolated fallback load reports OK", out.strip, "OK"
end
