module PokeAccess
  # Awakening's diary glossary (Scene_Glosario in "Diario de Liam Lana"): a sprite tab menu with @commands
  # (Historia, Personajes) and an @index cursor moved by up/down in a blocking loop INSIDE main -- so it is
  # never $scene. SceneWatcher.reader holds the live instance and speaks the focused tab name (deduped).
  AwakeningGlossary = SceneWatcher.reader("Scene_Glosario", :main, :aw_glossary) do |s|
    idx = PokeAccess.ivar(s, :@index)
    cmds = PokeAccess.ivar(s, :@commands)
    ok = idx && cmds.is_a?(Array) && idx >= 0 && idx < cmds.length
    ok ? [idx, cmds[idx].to_s] : nil
  end
end
