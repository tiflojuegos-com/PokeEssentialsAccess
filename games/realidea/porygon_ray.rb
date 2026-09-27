# Route 17's Porygon-Z beam (map 306): every few seconds anadircomb paints three of the letters A, S and D at the
# top for the player to type in 100 frames; a wrong letter or the time running out paralyses a party member.
module PokeAccess
  module ReaPorygonRay
    # The status paralizarpoke writes (paralysis).
    PARALYSIS = 4
    @statuses = nil

    # The letters to type, as painted, as soon as they appear.
    def self.combo(keys)
      return unless keys.is_a?(Array) && !keys.empty?
      PokeAccess.speak(PokeAccess::I18n.t(:rea_ray_keys, :keys => keys.map { |k| k.to_s }.join(", ")), true)
    end

    # A typed letter that matches its place (checkporygon, the letter already pushed), said back as it is taken.
    def self.typed
      got = ($Trainer.arraycomb rescue nil)
      want = ($game_variables[145] rescue nil)
      return unless got.is_a?(Array) && want.is_a?(Array) && !got.empty?
      i = got.length - 1
      PokeAccess.speak(got[i].to_s, true) if got[i] == want[i]
    rescue StandardError
      nil
    end

    # The party's statuses as paralizarpoke starts, to find the member it paralyses.
    def self.snapshot
      @statuses = party.map { |pk| (pk.status rescue nil) }
    end

    # After a miss: the member paralysed now; one already paralysed changes nothing, and the miss alone is said.
    def self.paralysed
      before = @statuses || []
      @statuses = nil
      list = party
      i = (0...list.length).find { |k| (list[k].status rescue nil) == PARALYSIS && before[k] != PARALYSIS }
      line = i ? PokeAccess::I18n.t(:rea_ray_hit, :name => (list[i].name rescue "")) : PokeAccess::I18n.t(:rea_ray_miss)
      PokeAccess.speak(line, true)
    rescue StandardError
      nil
    end

    # The player's party, or an empty list.
    def self.party
      p = ($Trainer.party rescue nil)
      p.is_a?(Array) ? p : []
    end
  end
end

PokeAccess::Game.define("realidea") do
  kernel("anadircomb", :after) { |_a, _r| PokeAccess::ReaPorygonRay.combo(($game_variables[145] rescue nil)) }
  kernel("checkporygon", :before) { |_a, _r| PokeAccess::ReaPorygonRay.typed }
  kernel("paralizarpoke", :before) { |_a, _r| PokeAccess::ReaPorygonRay.snapshot }
  kernel("paralizarpoke", :after) { |_a, _r| PokeAccess::ReaPorygonRay.paralysed }
end
