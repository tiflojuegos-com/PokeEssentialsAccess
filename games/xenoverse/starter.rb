module PokeAccess
  # The starter choice (0151_SceltaStarter; the older PokemonStarterSelection in 0152 is never called): three Pokemon
  # chosen by @select, then a painted question with Si/No chosen by @confirm. Its Right goes one past the third Pokemon
  # (@select 3), where the screen still shows the third and confirming makes the game fail: that place is said as such.
  module XenoverseStarter
    # The detail sprite shown for each of the three Pokemon, by @select.
    DETAILS = ['shyleonDet', 'trishoutDet', 'shulongDet']

    # Starts listening to a new screen's paint.
    def self.prepare(scene)
      @scene, @active, @phase = scene, false, nil
      @labels, @question, @parts_key, @parts = {}, '', nil, nil
    end

    # Starts reading once the screen takes input.
    def self.open(scene)
      return unless @scene.equal?(scene)
      @active = true
      poll(scene)
    end

    # Keeps the question painted on the confirm sprite and the Si/No labels painted on their buttons.
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

    # Says the selected Pokemon, or the answer under the cursor after the question.
    def self.poll(scene)
      return unless @active && @scene.equal?(scene)
      selected = !!PokeAccess.ivar(scene, :@selected)
      phase = selected ? :confirm : :choose
      if phase != @phase
        @phase = phase
        @first = true
        PokeAccess::Cursor.reset(scene, :xenoverse_starter)
      end
      selected ? confirm(scene, phase) : choose(scene, phase)
    end

    # The Si/No answer under @confirm, after the painted question the first time.
    def self.confirm(scene, phase)
      index = PokeAccess.ivar(scene, :@confirm)
      return unless index == 0 || index == 1
      label = @labels[index]
      return unless label && !label.empty?
      PokeAccess::Cursor.announce(scene, :xenoverse_starter, [phase, index, @question], true, false) do
        PokeAccess::Info.set_info(:text, label, label)
        text = @first && !@question.empty? ? PokeAccess.sentences([@question, label]) : label
        @first = false
        text
      end
    end

    # The Pokemon under @select, by its name and types, or the place past the third.
    def self.choose(scene, phase)
      index = PokeAccess.ivar(scene, :@select)
      return edge(scene, phase) if index == DETAILS.length
      return unless index.is_a?(Integer) && index >= 0 && index < DETAILS.length
      detail = PokeAccess.sprite(scene, DETAILS[index])
      return unless detail && detail.visible && detail.opacity > 0
      data = PokeAccess.ivar(scene, :@data)
      pokemon = data.is_a?(Hash) ? data["pkmn_#{index}"] : nil
      return unless pokemon
      key = [phase, index, pokemon.object_id]
      return if PokeAccess::Cursor.current(scene, :xenoverse_starter) == key
      unless @parts_key == key
        name = pokemon.name.to_s
        return if name.strip.empty?
        @parts = [[name, :brief], [PokeAccess::Data.pokemon_types(pokemon).join('/'), :medium]]
        @parts_key = key
      end
      PokeAccess::Info.set_info(:pokemon, pokemon, PokeAccess::Verbosity.full_line(@parts))
      PokeAccess::Cursor.announce(scene, :xenoverse_starter, key, true, false) do
        PokeAccess::Verbosity.line(:pokemon_choice, @parts)
      end
    end

    # Says that the cursor stands past the third Pokemon.
    def self.edge(scene, phase)
      PokeAccess::Cursor.announce(scene, :xenoverse_starter, [phase, DETAILS.length], true, false) do
        text = PokeAccess::I18n.t(:xenoverse_starter_edge)
        PokeAccess::Info.set_info(:text, text, text)
        text
      end
    end

    # Forgets the screen as it closes.
    def self.close(scene)
      @active, @scene = false, nil if @scene.equal?(scene)
    end
  end
end

PokeAccess::Game.define("xenoverse") do
  before("SceltaStarter", :initialize) { |scene, _args| PokeAccess::XenoverseStarter.prepare(scene) }
  before("SceltaStarter", :input_action) { |scene, _args| PokeAccess::XenoverseStarter.open(scene) }
  after("SceltaStarter", :gettinginput, :hook_container => true) { |scene, _result, _args| PokeAccess::XenoverseStarter.poll(scene) }
  before("SceltaStarter", :closescene) { |scene, _args| PokeAccess::XenoverseStarter.close(scene) }
  kernel("pbDrawTextPositions", :before) { |args, _result| PokeAccess::XenoverseStarter.paint(args) }
  clear_info_on("SceltaStarter", :closescene)
end
