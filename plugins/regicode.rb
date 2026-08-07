# Braille walls (the Regicode plugin, module RC): the puzzle walls of the Regi caves. RC.show paints the
# message ONE PNG PER CHARACTER onto its own viewport -- no window, no pbMessage, nothing the dialogue
# reader can see -- so without this the wall is not merely hard to read, it is unreadable by any other
# means. The text arrives as the argument, already in the game's language, so it only has to be spoken.
#
# override rather than a hook because show is a MODULE method (RC.show, not an instance method), which is
# what override's singleton branch is for. It wraps instead of replacing: the original still runs and
# paints the wall for sighted players.
#
# The plugin's own separators are markup, not speech: "\\" splits the message into successive screens and
# "/" breaks a screen into lines. Both become pauses, so the wall is read the way it is laid out. "-" is the
# word separator: the painter skips one cell and draws nothing, so on the wall it is a blank space.
module PokeAccess
  module RegiCode
    # The braille text as one spoken line: screens, line breaks and blank cells turned into their spoken form.
    def self.clean(text)
      spaced = text.to_s.gsub("\\", ". ").gsub("/", ", ").gsub("-", " ")
      PokeAccess.clean(spaced).to_s.strip
    rescue StandardError
      nil
    end
  end
end

PokeAccess::Hooks.override("RC", :show, :optional => true) do |_mod, original, args|
  t = PokeAccess::RegiCode.clean(args[0])
  PokeAccess.speak(t, true) if t && !t.empty?
  original.call
end
