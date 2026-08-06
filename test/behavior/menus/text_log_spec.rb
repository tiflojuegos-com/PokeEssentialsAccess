# The message history (Kyu's TextLog, class Log), a third-party plugin three of the games ship.
#
# The reader is a scene WATCHER and not an after-hook, and that is the whole finding: in both copies
# `update` is a `loop do` that returns only when the player closes the log, so an after-hook on it fires
# once, on the way out. One copy also has drawLines (called per scroll) and the other inlines that painting
# into the loop, so no shared method fires per scroll. Both loops do call Input.update every iteration,
# which is what makes the per-frame poll work in either.
# The harness loads every plugin reader, so this spec does not pull it in itself. It used to, back
# when only the running profile's declared plugins were loaded -- and once the harness started
# loading them all, that require became a SECOND load of the same file: require does not know
# about a file already brought in with eval, so every constant in it was reassigned.

Suite.define("text log: the focused history entry is the one BEFORE @pos, and it is read on change") do
  saved = ($PokemonGlobal.log rescue nil)
  begin
    def $PokemonGlobal.log; @pa_log; end
    def $PokemonGlobal.log=(v); @pa_log = v; end
    $PokemonGlobal.log = [["primera linea"], ["segunda", "con dos"], ["tercera"]]
    tl = PokeAccess::TextLog
    scene = Object.new

    # The paint loop advances @pos past what it drew, so the entry that just became current is @pos-1.
    # Reading @pos instead would announce the NEXT entry -- one ahead of what the player is looking at.
    scene.instance_variable_set(:@pos, 2)
    eq "the focused entry is the one before @pos", tl.focus_index(scene), 1
    eq "and it is joined into one spoken line", tl.entry_text(1), "segunda con dos"

    scene.instance_variable_set(:@pos, 0)
    eq "at the top it clamps instead of going negative", tl.focus_index(scene), 0

    scene.instance_variable_set(:@pos, 99)
    eq "and past the end it clamps to the last entry", tl.focus_index(scene), 2

    $PokemonGlobal.log = []
    eq "an empty history focuses nothing", tl.focus_index(scene), nil
    eq "and asking for its text is a clean nil", tl.entry_text(nil), nil
    eq "an index outside the log is nil, never a crash", tl.entry_text(7), nil
  ensure
    $PokemonGlobal.log = saved if saved
  end
end
