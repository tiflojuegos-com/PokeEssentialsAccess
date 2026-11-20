module PokeAccess
  # The Classic/Modern choice (0238_GameModeScreen): its two labels and the paragraph of the selected one are outline
  # text on two sprites. What drawInfo paints is said as painted.
  module XenoverseGameModes
    # Starts listening to a new screen's paint.
    def self.open(scene)
      @scene, @labels, @rows, @drawing = scene, {}, [], false
      PokeAccess::Cursor.reset(scene, :xenoverse_game_mode)
    end

    # Starts collecting the paragraph drawInfo paints for the mode at args[0].
    def self.begin_info(scene, args)
      return unless @scene.equal?(scene)
      @index = args.empty? ? 0 : args[0]
      @rows, @drawing = [], true
    end

    # Keeps an outline text painted on the labels sprite, or on the info sprite while drawInfo runs.
    def self.paint(args)
      return unless @scene
      sprites = PokeAccess.ivar(@scene, :@sprites)
      return unless sprites.is_a?(Hash)
      bitmap, x, y, text = args[0], args[1], args[2], args[5]
      return unless text.is_a?(String) && !text.strip.empty?
      return unless x.is_a?(Numeric) && y.is_a?(Numeric)
      labels = sprites['classicinfo']
      info = sprites['info']
      if labels && bitmap.equal?(labels.bitmap)
        @labels[[y, x]] = text.dup
      elsif @drawing && info && bitmap.equal?(info.bitmap)
        @rows.push([text.dup, :outline, x, y])
      end
    end

    # Says the selected mode's label and its paragraph, once per change.
    def self.finish_info(scene)
      return unless @scene.equal?(scene)
      @drawing = false
      labels = @labels.keys.sort.map { |position| @labels[position] }
      return unless labels.length == 2 && @index.is_a?(Integer) && @index >= 0 && @index < labels.length
      label = PokeAccess.clean(labels[@index])
      description = PokeAccess.clean(PokeAccess::PaintCapture.laid_out(@rows).map { |row| row.to_s }.join(' '))
      return if label.empty?
      text = description.empty? ? label : PokeAccess.sentences([label, description])
      PokeAccess::Cursor.announce(scene, :xenoverse_game_mode, [@index, label, description], true, false) do
        PokeAccess::Info.set_info(:text, text, text)
        text
      end
    end

    # Forgets the screen as it closes.
    def self.close(scene)
      @scene, @labels, @rows, @drawing = nil, {}, [], false if @scene.equal?(scene)
    end
  end
end

PokeAccess::Game.define("xenoverse") do
  before("GameModeScreen", :initialize) { |scene, _args| PokeAccess::XenoverseGameModes.open(scene) }
  before("GameModeScreen", :drawInfo) { |scene, args| PokeAccess::XenoverseGameModes.begin_info(scene, args) }
  after("GameModeScreen", :drawInfo, :hook_container => true) { |scene, _result, _args| PokeAccess::XenoverseGameModes.finish_info(scene) }
  before("GameModeScreen", :endscene) { |scene, _args| PokeAccess::XenoverseGameModes.close(scene) }
  kernel("pbDrawOutlineText", :before) { |args, _result| PokeAccess::XenoverseGameModes.paint(args) }
  clear_info_on("GameModeScreen", :endscene)
end
