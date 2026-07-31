# PokeNav app framework (PokeNavAppScene, 053_PIF_Hoenn/PokeNav/.../PokeNavAppScene.rb). Hoenn replaces the
# Pokegear with a grid of app buttons driven by the game's own loop: no Essentials window is involved, the
# focus is just @index over @buttons and each PokeNavButton paints its own label. One hook on the scene's
# hover -- which the loop calls whenever the focus moves -- covers the launcher and every app built on it
# (Contacts, PokeRadar, Challenges), because they all inherit this scene.
module PokeAccess
  module IF2PokeNav
    # The label of a button: its own text when it carries one, else its id, which is a readable symbol.
    def self.button_text(btn)
      t = PokeAccess.ivar(btn, :@text)
      t = (btn.id rescue nil) if t.nil? || t.to_s.strip.empty?
      PokeAccess.clean(t.to_s).to_s.strip
    rescue StandardError
      nil
    end

    # Speaks the focused app button once per change, with its position in the grid.
    def self.focus(scene)
      idx = PokeAccess.ivar(scene, :@index)
      btns = PokeAccess.ivar(scene, :@buttons)
      return unless idx.is_a?(Integer) && btns.is_a?(Array) && idx >= 0 && idx < btns.length
      label = button_text(btns[idx])
      return if label.nil? || label.empty?
      PokeAccess::Cursor.announce(scene, :if2_pokenav, idx, true) do
        PokeAccess::I18n.t(:if2_pokenav, :name => label, :n => idx + 1, :tot => btns.length)
      end
    rescue StandardError
      nil
    end
  end
end

PokeAccess::Game.define("infinitefusion_hoenn") do
  after("PokeNavAppScene", :hover) { |s, _r, _a| PokeAccess::IF2PokeNav.focus(s) }
end
