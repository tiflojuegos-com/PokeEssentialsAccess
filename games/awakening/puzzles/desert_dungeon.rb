# The desert dungeons (maps 112 to 114): pirate guards named Trainer(3), who see three tiles ahead as a trainer does,
# catch the player and take them back to the start of their floor until Zart is beaten (variable 184 at 6 or more
# blanks them). Walks keep out of their sight while another way exists, and a capture says where it left the player.
PokeAccess::Game.define("awakening") do
  watchers([112, 113, 114])

  mechanic(:state, 112, :part => :guards) do
    auto
    sent_back :awk_guard_caught, :to => [39, 6], :events => [5, 7, 8, 10]
  end

  mechanic(:state, 113, :part => :guards) do
    auto
    sent_back :awk_guard_caught, :to => [36, 9], :events => [7, 8]
  end

  mechanic(:state, 114, :part => :guards) do
    auto
    sent_back :awk_guard_caught, :to => [26, 6], :events => (2..9).to_a
    sent_back :awk_guard_caught, :maps => [112], :to => [26, 6]
  end
end
