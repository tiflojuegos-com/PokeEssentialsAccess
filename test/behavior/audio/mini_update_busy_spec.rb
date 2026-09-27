# The mini update (a menu over the map that sets no in_menu, such as Insurgence's pause menu) holds the player and
# locks the locator keys, unless a message is up.
Suite.define("spatial: the mini update holds the player, and the keys unless a message is up") do
  sp = PokeAccess::Spatial
  temp = Object.new
  class << temp; attr_accessor :miniupdate; end
  was = $PokemonTemp
  $PokemonTemp = temp
  begin
    temp.miniupdate = false
    eq "at rest nothing holds the player", sp.busy_reason, nil
    falsy "and the keys are free", sp.keys_locked?
    temp.miniupdate = true
    eq "a menu over the map is its mini update", sp.busy_reason, :mini_update
    truthy "and the locator keys are the menu's", sp.keys_locked?
    $game_temp.message_window_showing = true
    falsy "a message during it leaves them free", sp.keys_locked?
  ensure
    $game_temp.message_window_showing = false
    $PokemonTemp = was
  end
end

# From v21 the flag is Game_Temp's own.
Suite.define("spatial: v21's in_mini_update is the same hold") do
  sp = PokeAccess::Spatial
  class << $game_temp; attr_accessor :in_mini_update; end
  $game_temp.in_mini_update = true
  begin
    eq "the mini update holds the player", sp.busy_reason, :mini_update
    truthy "and locks the keys", sp.keys_locked?
  ensure
    $game_temp.in_mini_update = false
  end
end
