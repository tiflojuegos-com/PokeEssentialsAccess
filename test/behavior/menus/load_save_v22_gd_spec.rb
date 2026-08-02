# The v22 title screen (Essentials v22 UI::LoadVisuals) and in-game save screen (UI::SaveVisuals). The
# title screen is the FIRST thing a blind player meets, and it hides a destructive choice: with several
# saves, LEFT/RIGHT on Continue cycle the slot through set_slot_index, which never touches @index -- so a
# reader hooked only on the command cursor lets the player load, or overwrite, a save it never named. Both
# hooks were unasserted. Runs only in the gamedata pass.

# A [filename, hash] save entry shaped like the real one: hash[:player] (name + pokedex) and hash[:stats]
# (play_time in seconds).
def load_v22_save(file, name, seen, seconds)
  dex = Object.new
  dex.instance_variable_set(:@seen, seen)
  def dex.seen_count; @seen; end
  player = Object.new
  player.instance_variable_set(:@name, name)
  player.instance_variable_set(:@dex, dex)
  def player.name; @name; end
  def player.pokedex; @dex; end
  stats = Object.new
  stats.instance_variable_set(:@secs, seconds)
  def stats.play_time; @secs; end
  [file, { :player => player, :stats => stats }]
end

def load_v22_saves
  [load_v22_save("Game.rxdata", "Ayoub", 80, 7320),
   load_v22_save("Game2.rxdata", "Marta", 12, 600)]
end

Suite.define("v22 title: the focused command is read, and Continue also summarises its save") do
  saves = load_v22_saves
  vis = UI::LoadVisuals.new({ :continue => "Continuar", :new_game => "Partida nueva" }, saves)

  vis.set_index(:continue)
  spoke "Continue names the command", /Continuar/
  spoke "and the trainer of the save it would load", /Ayoub/
  spoke "with the play time", /#{Regexp.escape(PokeAccess::I18n.t(:load_play, :h => 2, :m => 2))}/
  spoke "and the pokedex tally", /#{Regexp.escape(PokeAccess::I18n.t(:load_dex, :n => 80))}/

  SpeakCapture.clear
  vis.set_index(:new_game)
  spoke_once "another command is read by name", /Partida nueva/
  not_spoke "and a command that loads nothing does not summarise a save", /Ayoub/
end

# The destructive one: cycling the slot on Continue must name WHICH save is now selected. The number is
# what the player navigates by, so slot and total are both required, and the summary must follow the slot
# rather than staying on the one the screen opened with.
Suite.define("v22 title: cycling the save slot names the slot and re-summarises it") do
  saves = load_v22_saves
  vis = UI::LoadVisuals.new({ :continue => "Continuar" }, saves)
  vis.set_index(:continue)

  SpeakCapture.clear
  vis.set_slot_index(1)
  spoke "the new slot is numbered out of the total",
        /#{Regexp.escape(PokeAccess::I18n.t(:load_slot, :n => 2, :tot => 2))}/
  spoke "and summarised with its own trainer", /Marta/
  not_spoke "not with the trainer of the slot left behind", /Ayoub/

  SpeakCapture.clear
  vis.set_slot_index(0)
  spoke "cycling back names the first slot again",
        /#{Regexp.escape(PokeAccess::I18n.t(:load_slot, :n => 1, :tot => 2))}/
  spoke "with its trainer", /Ayoub/
end

# The in-game save screen walks the slots by number, and the entry one past the last save is the free slot:
# it must read as empty rather than repeating the previous save's summary.
Suite.define("v22 save: each slot is summarised and the free slot reads empty") do
  vis = UI::SaveVisuals.new(load_v22_saves)

  vis.set_index(1)
  spoke_once "the focused slot is summarised by its trainer", /Marta/
  not_spoke "and not by the trainer of another slot", /Ayoub/

  SpeakCapture.clear
  vis.set_index(2)
  eq "the slot past the last save reads as empty", SpeakCapture.lines,
     [PokeAccess::I18n.t(:pc_empty)]
end
