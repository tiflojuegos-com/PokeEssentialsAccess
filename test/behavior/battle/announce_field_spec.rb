# announce_field: each section (weather, terrain, per-side effects) is guarded; one that raises drops only itself.
Suite.define("battle: announce_field survives a failing section") do
  weather_only = Object.new
  def weather_only.pbWeather; 1; end
  def weather_only.weather; 1; end
  def weather_only.instance_variable_get(sym); raise "boom" if sym == :@sides; nil; end
  PokeAccess::Battle.set_battle(weather_only)
  PokeAccess::Battle.announce_field
  spoke "weather still reported despite a section raising", /./
  not_spoke "did not fall back to the blanket field-error", /No se pudo leer el campo/i
end

Suite.define("battle: announce_field with nothing active says no-field") do
  empty = Object.new
  def empty.pbWeather; 0; end
  def empty.weather; 0; end
  def empty.instance_variable_get(sym); nil; end
  PokeAccess::Battle.set_battle(empty)
  PokeAccess::Battle.announce_field
  spoke "reports no field conditions", /Sin condiciones de campo/i
end
