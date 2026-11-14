module PokeAccess
  # This game uses SceltaStarter, not the older PokemonStarterSelection which
  # also ships in its source pack. Reuse its actual Pokemon objects and paint.
  module XenoverseStarter
    # The original Right branch permits index 3 for a three-item array. At its
    # right edge, seed the predecessor so that branch increments back to 2.
    # This also keeps a simultaneous Right+Confirm on a valid existing Pokemon.
    def self.protect_right_edge(scene)
      return if PokeAccess.ivar(scene, :@selected)
      return unless PokeAccess.ivar(scene, :@select) == 2
      scene.instance_variable_set(:@select, 1) if Input.trigger?(Input::RIGHT)
    end

    def self.prepare(scene)
      @scene, @active, @phase = scene, false, nil
      @labels, @question, @parts_key, @parts = {}, '', nil, nil
    end

    def self.open(scene)
      return unless @scene.equal?(scene)
      @active = true
      poll(scene)
    end

    def self.paint(args)
      return unless @scene
      sprites = PokeAccess.ivar(@scene, :@sprites)
      return unless sprites.is_a?(Hash) && args[1].is_a?(Array)
      text = PokeAccess.clean(args[1].map { |row| row.is_a?(Array) ? row[0].to_s : '' }.join(' '))
      return if text.empty?
      bitmap = args[0]
      if sprites['confirm'] && bitmap.equal?(sprites['confirm'].bitmap)
        @question = text
      else
        [['si', 0], ['siSel', 0], ['no', 1], ['noSel', 1]].each do |key, value|
          sprite = sprites[key]
          @labels[value] = text if sprite && bitmap.equal?(sprite.bitmap)
        end
      end
    end

    def self.poll(scene)
      return unless @active && @scene.equal?(scene)
      selected = !!PokeAccess.ivar(scene, :@selected)
      phase = selected ? :confirm : :choose
      if phase != @phase
        @phase = phase
        @first = true
        PokeAccess::Cursor.reset(scene, :xenoverse_starter)
      end
      if selected
        index = PokeAccess.ivar(scene, :@confirm)
        return unless index == 0 || index == 1
        label = @labels[index]
        return unless label && !label.empty?
        PokeAccess::Cursor.announce(scene, :xenoverse_starter, [phase, index, @question], true, false) do
          text = @first && !@question.empty? ? @question + ' ' + label : label
          @first = false
          text
        end
      else
        index = PokeAccess.ivar(scene, :@select)
        return unless index.is_a?(Integer) && index >= 0 && index <= 2
        sprites = PokeAccess.ivar(scene, :@sprites)
        detail = sprites.is_a?(Hash) ? sprites[['shyleonDet', 'trishoutDet', 'shulongDet'][index]] : nil
        return unless detail && detail.visible && detail.opacity > 0
        data = PokeAccess.ivar(scene, :@data)
        pokemon = data.is_a?(Hash) ? data["pkmn_#{index}"] : nil
        return unless pokemon
        key = [phase, index, pokemon.object_id]
        return if PokeAccess::Cursor.current(scene, :xenoverse_starter) == key
        unless @parts_key == key
          name = pokemon.name.to_s
          return if name.strip.empty?
          types = PokeAccess::Data.pokemon_types(pokemon).join('/')
          @parts = [[name, :brief], [types, :medium]]
          @parts_key = key
        end
        PokeAccess::Info.set_info(:pokemon, pokemon, PokeAccess::Verbosity.full_line(@parts))
        PokeAccess::Cursor.announce(scene, :xenoverse_starter, key, true, false) do
          PokeAccess::Verbosity.line(:pokemon_choice, @parts)
        end
      end
    end

    def self.close(scene)
      @active, @scene = false, nil if @scene.equal?(scene)
    end
  end
end

PokeAccess::Game.define("xenoverse") do
  before("SceltaStarter", :initialize) { |scene, _args| PokeAccess::XenoverseStarter.prepare(scene) }
  before("SceltaStarter", :input_action) { |scene, _args| PokeAccess::XenoverseStarter.open(scene) }
  before("SceltaStarter", :gettinginput) { |scene, _args| PokeAccess::XenoverseStarter.protect_right_edge(scene) }
  after("SceltaStarter", :gettinginput, :hook_container => true) { |scene, _result, _args| PokeAccess::XenoverseStarter.poll(scene) }
  before("SceltaStarter", :closescene) { |scene, _args| PokeAccess::XenoverseStarter.close(scene) }
  kernel("pbDrawTextPositions", :before) { |args, _result| PokeAccess::XenoverseStarter.paint(args) }
end
