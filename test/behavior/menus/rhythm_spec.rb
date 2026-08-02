# Royal's curry rhythm minigame. SongNote#note is a STRING, so the old DIRS[v.to_i] resolved every note to
# index 0 and the reader said "arriba" for all of them. Picking the pending note is the other half: notes
# are never removed from @notes and a note the player let through is never marked hit, so anything simpler
# than "un-hit AND still short of the selector" sticks on one note for the rest of the song.
require File.expand_path("../../../games/royal/rhythm", File.dirname(__FILE__))

class FakeSongNote
  attr_accessor :note, :x, :hit, :id
  def initialize(note, x, hit, id); @note = note; @x = x; @hit = hit; @id = id; end
end

Suite.define("royal rhythm: the next note to press, by its own direction") do
  rr = PokeAccess::RoyalRhythm
  sel = rr.selector_x(Object.new)

  eq "directions come from the note's string", rr::DIRS["left"], :dir_left
  eq "a rest beat is not a direction", rr::DIRS[""], nil

  scene = Object.new
  scene.instance_variable_set(:@notes, [
    FakeSongNote.new("up",    sel - 40, false, 0),
    FakeSongNote.new("right", sel - 10, true,  1),
    FakeSongNote.new("",      sel + 20, false, 2),
    FakeSongNote.new("left",  sel + 60, false, 3),
    FakeSongNote.new("down",  sel + 95, false, 4)
  ])
  n = rr.pending(scene)
  eq "a note the player missed does not block the rest of the song", n.id, 3
  eq "and it is the one still approaching", n.note, "left"

  scene.instance_variable_get(:@notes)[3].hit = true
  eq "once hit, the next real note takes over", rr.pending(scene).id, 4

  scene.instance_variable_get(:@notes)[4].hit = true
  eq "with nothing left ahead there is nothing to say", rr.pending(scene), nil

  scene.instance_variable_set(:@notes, nil)
  eq "a scene with no notes yet is not an error", rr.pending(scene), nil
end
