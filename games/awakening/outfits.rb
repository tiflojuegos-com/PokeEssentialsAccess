module PokeAccess
  # Awakening's class/outfit picker (Fates_Menu_Personajes in "Menu Outfits"): left/right move @select over
  # @classArray (readable class names) for character @name, in a blocking loop INSIDE initialize -- so it is
  # never $scene. SceneWatcher.reader holds the live instance and speaks the focused class, plus its locked
  # state, when @select changes (deduped).
  AwakeningOutfits = SceneWatcher.reader("Fates_Menu_Personajes", :initialize, :aw_outfit) do |s|
    sel = PokeAccess.ivar(s, :@select)
    arr = PokeAccess.ivar(s, :@classArray)
    name = PokeAccess.ivar(s, :@name)
    ok = sel && arr.is_a?(Array) && sel >= 0 && sel < arr.length && !arr[sel].to_s.empty?
    next nil unless ok
    cls = arr[sel].to_s
    [sel, lambda {
      unlocked = (::Fates_Utilities.checkIfHasClass(name, arr[sel]) rescue true)
      unlocked ? cls : "#{cls}, #{PokeAccess::I18n.t(:aw_outfit_locked)}"
    }]
  end
end
