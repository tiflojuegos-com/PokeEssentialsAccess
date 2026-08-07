module PokeAccess
  # Opalo's custom trainer card (OpaloCard) that replaces the standard one. Two pages drawn in their own
  # loops with no cursor: pbStartScene shows name, money, Pokedex tally, play time and a star rank
  # ($game_variables[250]); badgeScene shows the earned badges and the Q-I keys that play each badge's
  # anthem. Each page's content is read on entry via read_on_open with :timing => :before -- the page
  # methods BLOCK in their own loop, so an after-read would only speak on close.
  module OpaloCard
    STARS_VAR = 250

    # The data page: name, money, Pokedex, play time and star rank. Or nil.
    def self.main_text
      return nil unless $Trainer
      parts = [PokeAccess::I18n.t(:tc_title), PokeAccess::I18n.t(:tc_name, :name => $Trainer.name)]
      mn = ($Trainer.money rescue nil)
      parts.push(PokeAccess::I18n.t(:tc_money, :n => mn)) if mn
      owned = ($Trainer.pokedexOwned rescue nil); seen = ($Trainer.pokedexSeen rescue nil)
      parts.push(PokeAccess::I18n.t(:tc_pokedex, :owned => owned, :seen => seen)) if owned && seen
      hm = PokeAccess::Util.playtime_parts((Graphics.frame_count / Graphics.frame_rate rescue nil))
      parts.push(PokeAccess::I18n.t(:tr_playtime, :h => hm[0], :m => hm[1])) if hm
      stars = ($game_variables[STARS_VAR] rescue nil)
      parts.push(PokeAccess::I18n.t(:tcard_stars, :n => stars.to_i)) if stars
      d = start_date(($PokemonGlobal.startTime rescue nil))
      parts.push(PokeAccess::I18n.t(:tcard_started, :date => d)) if d
      parts.join(", ")
    rescue StandardError
      nil
    end

    # The start date the way the card prints it -- day, abbreviated month, year -- through the game's own
    # month names. The fifth of the five lines it draws.
    def self.start_date(t)
      return nil unless t
      mon = (pbGetAbbrevMonthName(t.mon) rescue nil)
      mon = t.mon.to_s if mon.nil? || mon.to_s.empty?
      "#{t.day} #{mon} #{t.year}"
    rescue StandardError
      nil
    end

    # The badges page: how many badges are earned, plus the hint about the anthem keys. Or nil.
    def self.badges_text
      return nil unless $Trainer
      n = PokeAccess::Util.badge_count($Trainer) || 0
      "#{PokeAccess::I18n.t(:tr_badges, :n => n)}. #{PokeAccess::I18n.t(:tcard_anthem_keys)}"
    rescue StandardError
      nil
    end
  end
end

PokeAccess::Game.define("opalo") do
  read_on_open("OpaloCard", :pbStartScene, :timing => :before) { |_s| PokeAccess::OpaloCard.main_text }
  read_on_open("OpaloCard", :badgeScene, :timing => :before) { |_s| PokeAccess::OpaloCard.badges_text }
end
