# Anil's diploma (games/anil/diploma.rb): its certificate is a picture with no text to read, so its transcription is
# said as the item is used, from the bag or from the ready menu. Gamedata pass, over a stand-in of ItemHandlers.
module AnilDiplomaSpec
  # The game's item-handler dispatch: 1 when the item had a field handler that ran, 0 otherwise.
  module Handlers
    def self.triggerUseInField(item); item == :DIPLOMA ? 1 : 0; end
    def self.triggerUseFromBag(item); item == :DIPLOMA ? 1 : 0; end
  end

  class << self
    # Whether the profile has wired the stand-in, which it does once per process.
    attr_accessor :wired
  end
end

class AnilDiplomaGdTest < PokeAccessTest
  CERTIFICATE = "Este diploma certifica que has completado la Pokédex Clásica. ¡Enhorabuena! EricLostie " \
                "(El diseño gráfico es mi pasión...)"
  Item = Struct.new(:id)

  test "using the diploma from the bag says its certificate, cutting in" do
    with_handlers { ItemHandlers.triggerUseFromBag(:DIPLOMA) }
    assert_equal [[CERTIFICATE, true]], SpeakCapture.log
  end

  test "using it from the ready menu says the same certificate" do
    with_handlers { ItemHandlers.triggerUseInField(:DIPLOMA) }
    assert_equal [[CERTIFICATE, true]], SpeakCapture.log
  end

  test "the game's handlers still answer what they answered" do
    with_handlers do
      { :DIPLOMA => 1, :POTION => 0 }.each do |item, result|
        assert_equal result, ItemHandlers.triggerUseFromBag(item), "from the bag, #{item}"
        assert_equal result, ItemHandlers.triggerUseInField(item), "from the ready menu, #{item}"
      end
    end
  end

  test "an item handed over as its data is told by its id" do
    with_handlers { ItemHandlers.triggerUseFromBag(Item.new(:DIPLOMA)) }
    assert_equal [CERTIFICATE], SpeakCapture.lines
  end

  test "any other item passes in silence" do
    with_handlers do
      [:POTION, Item.new(:POTION), nil].each do |item|
        ItemHandlers.triggerUseFromBag(item)
        ItemHandlers.triggerUseInField(item)
        assert_nothing_spoken item.inspect
      end
    end
  end

  private

  # Runs the block with the stand-in as the game's ItemHandlers, wired by the profile the first time; taken away after.
  def with_handlers
    made = !Object.const_defined?(:ItemHandlers)
    Object.const_set(:ItemHandlers, AnilDiplomaSpec::Handlers) if made
    unless AnilDiplomaSpec.wired
      PokeAccess::AnilDiploma.wire
      AnilDiplomaSpec.wired = true
    end
    yield
  ensure
    Object.send(:remove_const, :ItemHandlers) if made && Object.const_defined?(:ItemHandlers)
  end
end
