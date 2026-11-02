# Perseida's tutorial panels (pbCartelesTutorial, 0240_Tutoriales; two of them in battle, 0090_PokeBattle_Battle): a window
# of formatted text that scrolls and waits for a key. The text is said whole as it opens, with the keys it names as they are
# bound, and the info key keeps it.
module PokeAccess
  module PerseidaTutorial
    # A panel opening with this text.
    def self.open(text)
      line = PokeAccess::KeyHints.localize(PokeAccess.clean(text.to_s), nil, true)
      PokeAccess::Info.set_info(:text, line)
      PokeAccess.say_dialogue(line)
    end
  end
end

PokeAccess::Hooks.wrap_kernel("pbCartelesTutorial", "perseida_tutorial", :before) do |args, _r|
  PokeAccess::PerseidaTutorial.open(args[2])
end
