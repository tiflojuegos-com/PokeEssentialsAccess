# Three more Fates screens reached from the CMoon hub.
#
# FatesCartas (0260) is the character relationship cards: a vertical list of panels with @posi as the focus,
# each panel a ListaPersonaje carrying the character's @nombre and their rank. The cards themselves are art,
# so the name and rank are the whole content for a blind player.
#
# GachaScene (0245) rolls for rewards: @banner_sel picks the banner (left/right) and @sel the action within
# it. Banners and rewards are drawn as pictures, so neither which banner you are on nor what you won reached
# the reader.
#
# Scene_HoraDelTe (0261) is the tea-time social minigame: @tes lists the teas to offer, @puntos is the
# affinity earned and @personaje_nombre who you invited. The dialogue goes through pbMessage (already read);
# what was missing is the choice itself and the score.
module PokeAccess
  module AwakeningFatesExtra
    # Voices the focused relationship card: the character and their rank.
    def self.cards(_scene)
      idx = PokeAccess::AwakeningFatesExtra.mod_ivar(:@posi)
      panels = PokeAccess::AwakeningFatesExtra.mod_ivar(:@paneles)
      return unless idx.is_a?(Integer) && panels.is_a?(Hash)
      order = PokeAccess::AwakeningFatesExtra.mod_ivar(:@master_index)
      key = (order.is_a?(Array) && order[idx]) ? order[idx].to_s : nil
      panel = key ? panels[key] : nil
      return unless panel
      PokeAccess::Cursor.announce(nil, :awk_cards, idx, true) do
        name = PokeAccess.clean((panel.instance_variable_get(:@nombre) rescue "").to_s).to_s.strip
        rank = (panel.instance_variable_get(:@rango_letras) rescue nil)
        rank ? "#{name}, #{rank}" : name
      end
    rescue StandardError
      nil
    end

    # FatesCartas keeps its state on the class itself (its entry point is self.main), so the ivars are read
    # from the class object rather than from an instance.
    def self.mod_ivar(sym)
      k = PokeAccess.const_at("FatesCartas")
      k ? (k.instance_variable_get(sym) rescue nil) : nil
    rescue StandardError
      nil
    end

    # Voices the focused gacha banner and action.
    def self.gacha(scene)
      b = PokeAccess.ivar(scene, :@banner_sel)
      s = PokeAccess.ivar(scene, :@sel)
      banners = PokeAccess.ivar(scene, :@banners)
      return unless b.is_a?(Integer) && banners.is_a?(Array) && b >= 0 && b < banners.length
      PokeAccess::Cursor.announce(scene, :awk_gacha, [b, s], true) do
        PokeAccess::I18n.t(:awk_gacha, :n => b + 1, :tot => banners.length, :opt => s.to_i)
      end
    rescue StandardError
      nil
    end

    # Voices the affinity score whenever it moves, so the player can tell a gift landed well.
    def self.tea(scene)
      pts = PokeAccess.ivar(scene, :@puntos)
      return if pts.nil? || PokeAccess.ivar(scene, :@pa_tea) == pts
      scene.instance_variable_set(:@pa_tea, pts)
      who = PokeAccess.clean(PokeAccess.ivar(scene, :@personaje_nombre).to_s).to_s.strip
      PokeAccess.speak(PokeAccess::I18n.t(:awk_tea, :who => who, :n => pts.to_i), false)
    rescue StandardError
      nil
    end
  end
end

PokeAccess::Game.define("awakening") do
  after("GachaScene", :update) { |s, _r, _a| PokeAccess::AwakeningFatesExtra.gacha(s) }
  after("Scene_HoraDelTe", :main) { |s, _r, _a| PokeAccess::AwakeningFatesExtra.tea(s) }
  poll_each_frame { PokeAccess::AwakeningFatesExtra.cards(nil) }
end
