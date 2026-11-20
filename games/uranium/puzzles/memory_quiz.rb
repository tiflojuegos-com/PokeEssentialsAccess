# The professor's test in Lucille's memory (map 265): the professor (event 1) asks three questions in menus, and a wrong
# answer jumps to the end of the page until the test starts over. Only the last right answer does something of its own
# (it moves the memory on), so that is the one the assist can tell.
PokeAccess::Game.define("uranium") do
  mechanic(:state, 265) do
    auto
    right_choice 1, :takes => :transfer
  end
end
