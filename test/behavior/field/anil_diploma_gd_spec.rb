# Anil's diploma (games/anil/diploma.rb): the certificate's picture carries no text to read, so its transcription is
# said as the item is used, from the bag or from the ready menu. Gamedata pass, over a stubbed ItemHandlers.
module AnilDiplomaSpec
  # The game's item-handler dispatch: 1 when the item had a field handler that ran, 0 otherwise.
  module Handlers
    def self.triggerUseInField(item); item == :DIPLOMA ? 1 : 0; end
    def self.triggerUseFromBag(item); item == :DIPLOMA ? 1 : 0; end
  end
end

Suite.define("anil diploma: using the diploma says its certificate, from the bag and from the ready menu") do
  made = !Object.const_defined?(:ItemHandlers)
  begin
    Object.const_set(:ItemHandlers, AnilDiplomaSpec::Handlers) if made
    unless $pa_anil_diploma_wired
      PokeAccess::AnilDiploma.wire
      $pa_anil_diploma_wired = true
    end
    text = PokeAccess::GameLang.pick(PokeAccess::AnilDiploma::TEXT, :es)
    truthy "the transcription is the picture's own text", text.include?("Pokédex Clásica")
    SpeakCapture.clear
    eq "from the bag, the handler's own result", ItemHandlers.triggerUseFromBag(:DIPLOMA), 1
    eq "with the certificate said, interrupting", SpeakCapture.log, [[text, true]]
    SpeakCapture.clear
    eq "from the ready menu, the handler's own result too", ItemHandlers.triggerUseInField(:DIPLOMA), 1
    eq "and the same certificate", SpeakCapture.lines, [text]
    SpeakCapture.clear
    ItemHandlers.triggerUseFromBag(:POTION)
    silent "any other item says nothing"
  ensure
    Object.send(:remove_const, :ItemHandlers) if made && Object.const_defined?(:ItemHandlers)
  end
end
