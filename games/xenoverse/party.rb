module PokeAccess
  # NewParty's command list is a set of sprites, not a command window.
  module XenoverseParty
    def self.commands(scene, args)
      previous = @modal
      @modal = { :scene => scene, :commands => args[1], :pokemon => args[4] }
      yield
    ensure
      current = @modal
      @modal = previous
      PokeAccess::Cursor.reset(current, :xenoverse_party_command) if current
      if current && !previous
        PokeAccess::Info.clear_text
        pokemon = current[:pokemon]
        PokeAccess::Info.set_info(:pokemon, pokemon) if pokemon
      end
    end

    def self.poll(scene)
      modal = @modal
      return unless modal && modal[:scene].equal?(scene)
      commands = modal[:commands]
      index = PokeAccess.ivar(scene, :@index)
      sprites = PokeAccess.ivar(scene, :@cmds)
      return unless commands.is_a?(Array) && index.is_a?(Integer) && index >= 0 && index < commands.length
      sprite = sprites.is_a?(Hash) ? sprites["cmd#{index}"] : nil
      return unless sprite && !(sprite.disposed? rescue false)
      text = PokeAccess.clean(commands[index].to_s)
      return if text.empty?
      PokeAccess::Cursor.announce(modal, :xenoverse_party_command, [index, text], true, false) do
        PokeAccess::Info.set_info(:text, text, text)
        text
      end
    end
  end
end

PokeAccess::Game.define("xenoverse") do
  around("PokemonScreen_Scene", :pbShowCommands) do |scene, original, args|
    PokeAccess::XenoverseParty.commands(scene, args) { original.call }
  end
  after("PokemonScreen_Scene", :updateCmds, :hook_container => true) do |scene, _result, _args|
    PokeAccess::XenoverseParty.poll(scene)
  end
end
