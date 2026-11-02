# KleinStudio's BW Gender Selector (GenderSelectorScene; Vitro, and Dark Horizon's edited copy): two portraits, the boy and the
# girl, under a title in the copies that paint one, and a selection loop (pbUpdate) that lights one by @select (0 the boy, 1 the
# girl, -1 before the first). The title is said with the controls as the scene opens, then the lit portrait, the first one queued
# behind the title. The copies in Royal and Uranium are read by their profiles.
module PokeAccess
  module BWGenderSelector
    # The word for each lit portrait, by @select.
    LABELS = { 0 => :gsel_boy, 1 => :gsel_girl }

    # Says the title the scene painted (the mod's own where a copy paints none) and, while key hints are said, the
    # controls; queued, behind whatever brought the scene up.
    def self.opened(pairs)
      title = PokeAccess.sentences(PokeAccess::PaintCapture.laid_out(pairs).map { |t| PokeAccess.clean(t) })
      title = PokeAccess::I18n.t(:gsel_help) if title.empty?
      PokeAccess.speak(PokeAccess::Verbosity.with_hint(title, PokeAccess::I18n.t(:gsel_help_hint)), false)
    rescue StandardError => e
      PokeAccess.swallowed(e)
      nil
    end

    # The lit portrait as [@select, its word], the word set on the info key as it is said; nil while none is lit.
    def self.lit(scene)
      sel = PokeAccess.ivar(scene, :@select)
      key = LABELS[sel]
      return nil unless key
      word = PokeAccess::I18n.t(key)
      [sel, lambda { PokeAccess::Info.set_info(:text, word); word }]
    end
  end
end

PokeAccess::SceneWatcher.reader("GenderSelectorScene", :pbUpdate, :bw_gender, :optional => true) do |scene|
  PokeAccess::BWGenderSelector.lit(scene)
end

# pbStartScene paints the title, then fades the scene in.
PokeAccess::Hooks.on_paint("GenderSelectorScene", :pbStartScene, :optional => true) do |_scene, pairs, _a|
  PokeAccess::BWGenderSelector.opened(pairs)
end

PokeAccess::Hooks.clear_info_on("GenderSelectorScene", :pbEndScene)
