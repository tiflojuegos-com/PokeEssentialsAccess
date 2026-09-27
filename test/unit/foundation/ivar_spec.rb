# PokeAccess.ivar: an unset ivar reads as nil (Ruby does not raise on one), the fallback only when the read raises,
# and it never raises itself.
Suite.define("ivar: reads the value, nil when unset, fallback only on error") do
  obj = Object.new
  obj.instance_variable_set(:@here, 7)
  eq "reads an existing ivar", PokeAccess.ivar(obj, :@here), 7
  eq "an unset ivar reads as nil (as the raw idiom did)", PokeAccess.ivar(obj, :@nope), nil
  eq "an unset ivar reads as nil even with a fallback given", PokeAccess.ivar(obj, :@nope, :fb), nil
  eq "reading off nil is nil (nil takes instance_variable_get)", PokeAccess.ivar(nil, :@x), nil
  eq "a malformed ivar name (the raising case) uses the fallback", PokeAccess.ivar(obj, :bad_name, :safe), :safe
end

# ivar_i coerces to Integer, 0 or the fallback when absent.
Suite.define("ivar_i: coerces to integer with a numeric fallback") do
  obj = Object.new
  obj.instance_variable_set(:@n, "5")
  eq "coerces a string ivar to integer", PokeAccess.ivar_i(obj, :@n), 5
  eq "an absent numeric ivar is 0 by default", PokeAccess.ivar_i(obj, :@missing), 0
  eq "an absent numeric ivar honours the fallback", PokeAccess.ivar_i(obj, :@missing, -1), -1
end

# sprite: a named window from a scene's @sprites hash, nil when the hash or key is absent, never raising.
Suite.define("sprite: named sprite from @sprites, nil when absent") do
  scene = Object.new
  scene.instance_variable_set(:@sprites, { "cmd" => :the_window })
  eq "returns the named sprite", PokeAccess.sprite(scene, "cmd"), :the_window
  eq "an absent key is nil", PokeAccess.sprite(scene, "nope"), nil
  bare = Object.new
  eq "a scene with no @sprites is nil, not an error", PokeAccess.sprite(bare, "cmd"), nil
end
