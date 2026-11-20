# Suna Beach (map 94): the metal plate that shuts Fini Cavern has five sockets with no graphic. Each takes any gem and a gem
# can be taken off, but only the gem of its own colour counts towards var 42; five open the gate. The sockets are named, and
# the assist adds which gem each one takes and the count, which the game's own message hides.
PokeAccess::Game.define("keishou") do
  gems = { 5 => :ks_gem_blue, 6 => :ks_gem_red, 7 => :ks_gem_purple, 8 => :ks_gem_yellow, 9 => :ks_gem_green }
  mechanic(:state, 94) do
    auto
    name gems.keys, lambda { |ev|
      PokeAccess::Puzzles.assist? ? [:ks_socket_gem, { :gem => PokeAccess::I18n.t(gems[ev.id]) }] : :ks_socket
    }
    count :ks_sockets_set, :var => 42, :of => 5, :assist => true
    solved { $game_variables[42] >= 5 }
    arrival_hint :ks_sockets_rule
  end
end
