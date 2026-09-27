# Braille walls (the Regicode plugin, module RC): RC.show paints its text argument one picture per character; the
# override says it and still paints.
module PokeAccess
  module RegiCode
    # The braille text as one line: "\\" (new screen) and "/" (line break) become pauses, "-" a space.
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
