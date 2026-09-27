# Anil's diploma (the DIPLOMA key item): a full-screen picture with the certificate's text, held until a key is
# pressed. Its transcription, by build language (GameLang) and never the mod's, is said as the item is used, from the
# bag (triggerUseFromBag, which falls back to the field handler) or from the ready menu (triggerUseInField).
module PokeAccess
  module AnilDiploma
    TEXT = {
      :es => "Este diploma certifica que has completado la Pokédex Clásica. ¡Enhorabuena! EricLostie " \
             "(El diseño gráfico es mi pasión...)"
    }

    # Says the diploma when the item being used is it; any other item passes silently.
    def self.on_use(item)
      id = item.respond_to?(:id) ? item.id : item
      return unless id.to_s == "DIPLOMA"
      PokeAccess.speak(PokeAccess::GameLang.pick(TEXT, :es), true)
    end

    # Hooks both ways the game runs an item's field handler.
    def self.wire
      %w[triggerUseInField triggerUseFromBag].each do |fn|
        PokeAccess::Hooks.wrap_singleton("ItemHandlers", fn, "anil_diploma", :before) do |args, _r|
          PokeAccess::AnilDiploma.on_use(args[0])
        end
      end
    end
  end
end

PokeAccess::AnilDiploma.wire
