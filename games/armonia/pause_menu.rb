# Armonia's sprite-button pause menu (PokemonMenu_Scene) on the shared sprite-button reader, and the panel beside it.

module PokeAccess
  # The panel pbMenuTexts paints beside the buttons, said once after the opening button: each member with its HP bar,
  # status icon and level, the trainer lines as painted but the play clock, and the DexNav key while it is up.
  module ArmoniaPanel
    # The trainer block is painted at the panel's left edge, the levels further in, at x 65.
    TRAINER_X = 20
    CLOCK = /\d+:\d\d\s*\z/

    # Brackets a repaint of the panel and keeps its trainer lines on the scene.
    def self.capture(scene)
      PokeAccess::PaintCapture.arm(:armonia_panel)
      yield
    ensure
      pairs = PokeAccess::PaintCapture.take_pairs(:armonia_panel) || []
      rows = pairs.select { |p| p[2].to_i < TRAINER_X }.map { |p| PokeAccess.clean(p[0].to_s) }
      scene.instance_variable_set(:@access_panel_rows, rows.reject { |r| r.empty? || r =~ CLOCK })
    end

    # One member as the panel paints it beside its icon: "Lvl. N" from the party reading's medium level, the HP bar as
    # a share (at least 1 while any is left) and the status icon, fainted in its place.
    def self.member(pk)
      return PokeAccess::I18n.t(:pty_egg) if PokeAccess::Summary.egg?(pk)
      hp = pk.hp.to_i
      tot = pk.totalhp.to_i
      parts = [[pk.name.to_s, :brief], [PokeAccess::I18n.t(:arm_level, :n => pk.level), :medium]]
      parts.push([PokeAccess::I18n.t(:bt_hp_pct, :n => [hp * 100 / tot, 1].max), :brief]) if hp > 0 && tot > 0
      parts.push([PokeAccess::Party.status_slot(pk), :brief])
      PokeAccess::Verbosity.line(:party, parts)
    end

    # The panel's lines in reading order: the members above, the trainer block under them, the DexNav key last
    # while key hints are said.
    def self.lines(scene)
      parts = (($Trainer.party rescue nil) || []).map { |pk| member(pk) }
      parts.concat(Array(PokeAccess.ivar(scene, :@access_panel_rows)))
      dexnav = PokeAccess.ivar(scene, :@btDexNav)
      parts.push(PokeAccess::I18n.t(:arm_dexnav_key)) if dexnav && (dexnav.visible rescue false) && PokeAccess::Verbosity.hints?
      parts
    end

    # Once per opening: selectButton runs again on every move.
    def self.opened(scene)
      return if PokeAccess.ivar(scene, :@access_panel_said)
      scene.instance_variable_set(:@access_panel_said, true)
      PokeAccess::PausePanel.say(lines(scene))
    rescue StandardError
      nil
    end
  end
end

# The panel, queued after the focused button: registered before the shared reader below, since the first-registered
# after-hook's body runs last.
PokeAccess::Game.define("armonia") do
  before("PokemonMenu_Scene", :pbStartScene) { |s, _a| s.instance_variable_set(:@access_panel_said, nil) }
  around("PokemonMenu_Scene", :pbMenuTexts) do |scene, nxt, _a|
    PokeAccess::ArmoniaPanel.capture(scene) { nxt.call }
  end
  after("PokemonMenu_Scene", :selectButton) { |scene, _r, _a| PokeAccess::ArmoniaPanel.opened(scene) }
end

# The subscreens opened without pbFadeOutIn (PC, pokeDex, the DexNav), declared so the return still announces once;
# save too, which the menu always closes after, so its questions do not count as returns.
PokeAccess::SpriteButtonMenu.define("armonia",
                                    [["PokemonMenu_Scene", :pc],
                                     ["PokemonMenu_Scene", :pokeDex],
                                     ["DexNav", :startUI],
                                     ["PokemonMenu_Scene", :save, { :closes => true }]])
