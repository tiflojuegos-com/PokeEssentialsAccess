module PokeAccess
  module XenoverseGender
    def self.open(scene, rows)
      @scene = scene
      @title = PokeAccess::PaintCapture.text(PokeAccess::PaintCapture.laid_out(rows))
      @first = true
      PokeAccess::Cursor.reset(scene, :xenoverse_gender)
      poll(scene)
    end

    def self.poll(scene)
      return unless @scene.equal?(scene)
      index = PokeAccess.ivar(scene, :@select)
      return unless index == 0 || index == 1
      label = PokeAccess::I18n.t(index == 0 ? :gsel_boy : :gsel_girl)
      PokeAccess::Cursor.announce(scene, :xenoverse_gender, index, true, false) do
        text = @first && !@title.empty? ? @title + ' ' + label : label
        @first = false
        text
      end
    end

    def self.close(scene)
      @scene, @title = nil, nil if @scene.equal?(scene)
    end
  end
end

PokeAccess::Game.define("xenoverse") do
  on_paint("PokemonGenderSelectScene", :pbStartScene) { |scene, rows, _args| PokeAccess::XenoverseGender.open(scene, rows) }
  after("PokemonGenderSelectScene", :update, :hook_container => true) { |scene, _result, _args| PokeAccess::XenoverseGender.poll(scene) }
  before("PokemonGenderSelectScene", :pbEndScene) { |scene, _args| PokeAccess::XenoverseGender.close(scene) }
end
