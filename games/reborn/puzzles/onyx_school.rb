# Onyx Trainers' School 2F (map 121): the double door at (7 to 8, 7) is locked until the nervous student (event 13) is
# talked to; the teacher then fetches the janitor and, with variable 278 at 3, the door leads to the move tutors.
PokeAccess::Game.define("reborn") do
  mechanic(:state, 121) do
    auto
    watch :var => 278, :from => 3, :say => :rbf_onyx_door_open
    name 13, :rbf_onyx_student, :assist => true
    hint :rbf_onyx_hint
    solved(nil, :quiet => true) { $game_variables[278].to_i >= 3 }
  end
end
