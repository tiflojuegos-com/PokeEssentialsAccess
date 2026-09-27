# Tectonic's Party Showcase: the whole team on one painted page, said once per state; the constructor runs the
# screen's loop, so the opening page comes from the frame poll, and updateShowcaseInfo repaints on each toggle.
module PokeAccess
  module PartyShowcase
    def self.hold(scene); @scene = scene; end

    # Forgets the screen and drops a capture nobody took (a page closed before its first frame).
    def self.release
      @scene = nil
      PokeAccess::PaintCapture.take(:showcase)
    end

    # Speaks the page as painted, once per state, repeated rows kept (members share levels, items and moves).
    def self.say(scene)
      t = PokeAccess::PaintCapture.text(PokeAccess::PaintCapture.take(:showcase), false)
      return if t.to_s.strip.empty?
      return unless PokeAccess::Cursor.changed?(scene, :showcase, t.to_s)
      PokeAccess.speak_clean(t, false)
    rescue StandardError
      nil
    end

    # The opening page, on the first frame of the constructor's loop.
    def self.poll
      say(@scene) if @scene
    end

    # Puts one member's painted rows back into the page capture with what its icons and colours show: the shiny
    # star, the held item and the ball after its name and sex sign, the nature's stats after the rest.
    # param rows the member's rows as PaintCapture.sample gives them
    def self.note_member(rows, pk)
      head = (rows.length > 1 && PokeAccess::Party::SIGNS.include?(rows[1][0].to_s.strip)) ? 2 : 1
      rows[0, head].each { |r| PokeAccess::PaintCapture.note(*r) }
      icon_parts(pk).each { |t| PokeAccess::PaintCapture.note(t, :icons) }
      (rows[head..-1] || []).each { |r| PokeAccess::PaintCapture.note(*r) }
      nature = nature_part(pk)
      PokeAccess::PaintCapture.note(nature, :icons) if nature
    end

    # The member's icons: the shiny star, the held item and the ball it was caught in.
    def self.icon_parts(pk)
      out = []
      out.push(PokeAccess::I18n.t(:pk_shiny)) if PokeAccess::Party.shiny?(pk)
      it = PokeAccess::Party.item_shown(pk)
      out.push(PokeAccess::I18n.t(:pk_holds, :item => it)) if it
      ball = PokeAccess::Summary.ball_name(pk)
      out.push(PokeAccess::I18n.t(:sum_ball, :b => ball)) if ball
      out
    end

    # The stats the nature raises and lowers, which the page shades red and blue, or nil for a neutral one.
    def self.nature_part(pk)
      changes = (pk.nature_for_stats.stat_changes rescue nil)
      return nil unless changes.is_a?(Array)
      up = changes.find { |c| c[1].to_i > 0 }
      down = changes.find { |c| c[1].to_i < 0 }
      return nil unless up && down
      t = PokeAccess::I18n.t(:sm_nature_effect, :up => PokeAccess::Data.stat_name(up[0]),
                             :down => PokeAccess::Data.stat_name(down[0]))
      t.sub(/\.\s*\z/, "")
    rescue StandardError
      nil
    end
  end
end

PokeAccess::Hooks.around_hook("PokemonPartyShowcase_Scene", :initialize, :optional => true) do |scene, nxt, _a|
  PokeAccess::PaintCapture.arm(:showcase)
  PokeAccess::PartyShowcase.hold(scene)
  begin
    nxt.call
  ensure
    PokeAccess::PartyShowcase.release
  end
end

PokeAccess::Keys.on_frame { PokeAccess::PartyShowcase.poll }

PokeAccess::Hooks.around_hook("PokemonPartyShowcase_Scene", :updateShowcaseInfo, :optional => true) do |scene, nxt, _a|
  PokeAccess::PaintCapture.arm(:showcase)
  begin
    nxt.call
  ensure
    PokeAccess::PartyShowcase.say(scene)
  end
end

# One member's block: its rows are taken aside and laid back with what its icons show.
PokeAccess::Hooks.around_hook("PokemonPartyShowcase_Scene", :renderShowcaseInfo, :optional => true) do |_s, nxt, args|
  if PokeAccess::PaintCapture.armed?(:showcase)
    r = nil
    rows = PokeAccess::PaintCapture.sample { r = nxt.call }
    PokeAccess::PartyShowcase.note_member(rows, args[1])
    r
  else
    nxt.call
  end
end
