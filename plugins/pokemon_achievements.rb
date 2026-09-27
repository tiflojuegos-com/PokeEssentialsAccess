# Painkiller97's achievements screen (Pokemon_Achievements_Scene): page 0's icon strip shows earned only as opacity
# (255 earned, 50 not), the titles in @nombrelogro by index (each Logro holds a placeholder name); page 1's name and
# description are captured.
module PokeAccess
  module PokemonAchievements
    def self.poll(scene)
      page = PokeAccess.ivar(scene, :@page)
      sel = PokeAccess.ivar(scene, :@select)
      PokeAccess::Cursor.reset(scene, :pach_detail) if page.to_i == 0
      return unless page.to_i == 0 && sel.is_a?(Integer)
      logros = PokeAccess.ivar(scene, :@logros)
      return unless logros.is_a?(Array) && sel >= 0 && sel < logros.length
      l = logros[sel]
      earned = ((l.icono.opacity rescue 0).to_i >= 255)
      PokeAccess::Cursor.announce(scene, :pach, [sel, earned], true) do
        names = PokeAccess.ivar(scene, :@nombrelogro)
        name = names.is_a?(Array) ? names[sel] : nil
        name = PokeAccess.ivar(l, :@nombre) if name.nil? || name.to_s.empty?
        name = PokeAccess.clean(name.to_s)
        head = PokeAccess::Verbosity.list_entry(name, sel + 1, logros.length)
        state = PokeAccess::I18n.t(earned ? :pach_earned : :pach_unearned)
        "#{head}, #{state}"
      end
    rescue StandardError
      nil
    end

    # The detail page's paint, once per achievement: textoLogro runs twice per page turn and once more on the
    # way back, so page 0 is skipped and the read is keyed on the selection (which poll forgets).
    def self.detail(scene, rows)
      return unless PokeAccess.ivar(scene, :@page).to_i == 1
      sel = PokeAccess.ivar(scene, :@select)
      PokeAccess::Cursor.announce(scene, :pach_detail, sel, true) { PokeAccess::PaintCapture.text(rows) }
    rescue StandardError
      nil
    end
  end
end

PokeAccess::Hooks.after_hook("Pokemon_Achievements_Scene", :update, :optional => true) do |scene, _r, _a|
  PokeAccess::PokemonAchievements.poll(scene)
end
PokeAccess::Hooks.around_hook("Pokemon_Achievements_Scene", :textoLogro, :optional => true) do |s, nxt, _a|
  PokeAccess::PaintCapture.arm(:pach_detail)
  begin
    nxt.call
  ensure
    PokeAccess::PokemonAchievements.detail(s, PokeAccess::PaintCapture.take(:pach_detail))
  end
end
