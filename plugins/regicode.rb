# Braille walls (the Regicode plugin, module RC): RC.show paints the message ONE PNG PER CHARACTER onto its
# own viewport, so nothing else can read it; the text arrives as the argument, in the game's language.
# override rather than a hook because show is a MODULE method, and it wraps instead of replacing so the wall
# is still painted. The plugin's separators are markup: "\\" splits screens and "/" breaks lines, both
# become pauses; "-" is the word separator and becomes a space.
module PokeAccess
  module RegiCode
    # The braille text as one spoken line: screens, line breaks and blank cells turned into their spoken form.
    def self.clean(text)
      spaced = text.to_s.gsub("\\", ". ").gsub("/", ", ").gsub("-", " ")
      PokeAccess.clean(spaced)
    rescue StandardError
      nil
    end
  end
end

PokeAccess::Hooks.override("RC", :show, :optional => true) do |_mod, original, args|
  t = PokeAccess::RegiCode.clean(args[0])
  PokeAccess.speak(t, true)
  original.call
end
