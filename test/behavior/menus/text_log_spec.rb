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

Suite.define("text log: the visible page ends at @pos - 1 and spans @lines entries") do
  saved = ($PokemonGlobal.log rescue nil)
  begin
    def $PokemonGlobal.log; @pa_log; end
    def $PokemonGlobal.log=(v); @pa_log = v; end
    $PokemonGlobal.log = [["primera linea"], ["segunda", "con dos"], ["tercera"]]
    tl = PokeAccess::TextLog
    scene = Object.new

    # The paint loop advances @pos past what it drew, so the newest entry on screen is @pos-1, and @lines
    # is how many it drew. Reading one index instead of the page left the rest of the screen unheard.
    scene.instance_variable_set(:@pos, 2)
    scene.instance_variable_set(:@lines, 2)
    eq "the page is the two entries the paint drew", tl.page_range(scene), [0, 1]
    eq "and they come out as one spoken line", tl.page_text(scene), "primera linea. segunda con dos"

    scene.instance_variable_set(:@lines, 1)
    eq "one drawn entry is one entry read", tl.page_range(scene), [1]

    scene.instance_variable_set(:@pos, 0)
    eq "at the top there is nothing before the first entry", tl.page_range(scene), nil

    scene.instance_variable_set(:@pos, 99)
    scene.instance_variable_set(:@lines, 2)
    eq "past the end it clamps to the last entries", tl.page_range(scene), [1, 2]

    scene.instance_variable_set(:@lines, 0)
    eq "an unset line count still reads the newest entry", tl.page_range(scene), [2]

    $PokemonGlobal.log = []
    eq "an empty history shows no page", tl.page_range(scene), nil
    eq "and asking for its text is a clean nil", tl.entry_text(nil), nil
    eq "an index outside the log is nil, never a crash", tl.entry_text(7), nil
  ensure
    $PokemonGlobal.log = saved if saved
  end
end
