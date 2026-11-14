module PokeAccess
  # Fullbox.makeSprite receives the resolved rows after commands, variables and
  # page splitting, immediately before the game's own message window shows them.
  module XenoverseFullbox
    def self.speaker
      return '' unless $fullbox_mugshots.is_a?(Hash)
      names = []
      $fullbox_mugshots.values.flatten.each do |wrapper|
        box = PokeAccess.ivar(wrapper, :@mugname)
        next unless box && box.respond_to?(:visible) && box.respond_to?(:active) && box.respond_to?(:name)
        next unless box.visible && box.active
        name = box.name.to_s.strip
        next if name.empty?
        name = name =~ /\A\?+\z/ ? PokeAccess::I18n.t(:msg_speaker_unknown) : PokeAccess.clean(name)
        names.push(name) unless name.empty?
      end
      names.uniq!
      names.length == 1 ? names[0] : ''
    end

    def self.read(args)
      rows = args[0, 2].select { |text| text.is_a?(String) && !text.strip.empty? }
      text = PokeAccess.clean(rows.join(' '))
      return if text.empty?
      name = speaker
      PokeAccess.say_dialogue(name.empty? ? text : name + ': ' + text)
    end
  end

  # The choice constructor keeps only rendered sprites, so retain its resolved
  # option text before it enters the loop. Read the game's own wrapped cursor.
  module XenoverseFullboxChoice
    def self.prepare(scene, args)
      @scene = scene
      entries = args[0]
      @labels = entries.is_a?(Array) ? entries.map do |entry|
        text = entry.respond_to?(:text) ? entry.text : nil
        text.is_a?(String) ? PokeAccess.clean(text) : nil
      end : []
      PokeAccess::Cursor.reset(scene, :xenoverse_fullbox_choice)
    end

    def self.read(scene)
      return unless @scene.equal?(scene)
      index = PokeAccess.ivar(scene, :@cursor)
      return unless index.is_a?(Integer) && index >= 0 && index < @labels.length
      label = @labels[index]
      return if label.nil? || label.empty?
      PokeAccess::Cursor.announce(scene, :xenoverse_fullbox_choice, [index, label], true, false) do
        PokeAccess::Info.set_info(:text, label, label)
        label
      end
    end

    def self.close(scene)
      return unless @scene.equal?(scene)
      @scene, @labels = nil, []
      PokeAccess::Info.clear_text
    end
  end
end

PokeAccess::Hooks.wrap_singleton("Fullbox", :makeSprite, 'xenoverse_fullbox', :before) do |args, _result|
  PokeAccess::XenoverseFullbox.read(args)
end

PokeAccess::Game.define("xenoverse") do
  before("Fullbox_Choice", :initialize) { |scene, args| PokeAccess::XenoverseFullboxChoice.prepare(scene, args) }
  before("Fullbox_Choice", :loop) { |scene, _args| PokeAccess::XenoverseFullboxChoice.read(scene) }
  after("Fullbox_Choice", :setSelection) { |scene, _result, _args| PokeAccess::XenoverseFullboxChoice.read(scene) }
  before("Fullbox_Choice", :select) { |scene, _args| PokeAccess::XenoverseFullboxChoice.close(scene) }
  before("Fullbox_Choice", :dispose) { |scene, _args| PokeAccess::XenoverseFullboxChoice.close(scene) }
end
