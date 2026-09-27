# Realidea's pause menu: its speech box (usually the story objective), the talisman while it glows, and its strip
# of key boxes and money (less the clock), said once per opening after pbShowMenu, queued behind the focused entry.
module PokeAccess
  module ReaPauseOverlay
    # The switch the map sets where something is hidden (Game_Map#setup), which makes the menu's talisman glow.
    HIDDEN_SWITCH = 314

    # What the speech box says this time, or "".
    def self.speech(scene)
      PokeAccess.clean((PokeAccess.ivar(scene, :@window).text rescue "").to_s)
    end

    # The strip in reading order: the talisman in its corner while it glows, its key boxes only while key hints are
    # said, and the money less its clock. The words are the menu's own _INTL calls, so a game running in English
    # says them in English.
    def self.strip(scene)
      parts = talisman(scene)
      parts.concat(key_boxes(scene)) if PokeAccess::Verbosity.hints?
      money = ($Trainer.money rescue nil)
      parts.push((_INTL("${1}", money) rescue "$#{money}")) if money
      parts
    end

    # The talisman's glow as a one-item list: the menu animates it (with a chime) on the maps that hide something.
    def self.talisman(scene)
      icon = PokeAccess.sprite(scene, "talisman")
      lit = icon && (icon.visible rescue false) && ($game_switches[HIDDEN_SWITCH] rescue false)
      lit ? [PokeAccess::I18n.t(:rea_talisman_glow)] : []
    end

    # The strip's key boxes: save on Z and, where it is shown, teleport on Q.
    def self.key_boxes(scene)
      parts = ["Z: #{(_INTL('Guardar') rescue 'Guardar')}"]
      q = PokeAccess.sprite(scene, "Q")
      parts.push("Q: #{(_INTL('Teletr.') rescue 'Teletr.')}") if q && (q.bitmap rescue nil)
      parts
    end

    def self.say(scene)
      said = speech(scene)
      PokeAccess.speak(said, false) unless said.empty?
      PokeAccess::PausePanel.say(strip(scene))
    end
  end
end

PokeAccess::Game.define("realidea") do
  before("PokemonMenu_Scene", :pbStartScene, :optional => true) { |s, _a| PokeAccess::Cursor.reset(s, :rea_overlay) }
  after("PokemonMenu_Scene", :pbShowMenu, :optional => true) do |scene, _r, _a|
    PokeAccess::ReaPauseOverlay.say(scene) if PokeAccess::Cursor.changed?(scene, :rea_overlay, true)
  end
end
