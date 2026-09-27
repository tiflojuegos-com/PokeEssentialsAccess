# Infinite Fusion's Poke Radar banner: the route's species by icon, an unseen one as a silhouette, the radar's rare
# ones ringed; then the light, green when a rare one can appear. The game's two functions, reduced to what they
# leave behind, are defined before the profile file binds to them.
class IFSpecRadarUI
  def initialize(seen, unseen, rare)
    @seen_pokemon = seen
    @unseen_pokemon = unseen
    @rare_pokemon = rare
  end
end

def displayPokeradarBanner(seen = [], unseen = [], include_rare = false)
  return if $PokemonTemp.pokeradar_ui
  $PokemonTemp.pokeradar_ui = IFSpecRadarUI.new(seen, unseen, include_rare ? [:PIKACHU, :MEW] : [])
end

def playPokeradarLightAnimation(rare_allowed = false); rare_allowed; end

Suite.define("infinite fusion: the radar banner names what it shows, and the light whether a rare one can appear") do
  t = PokeAccess::I18n
  old_temp = $PokemonTemp
  old_trainer = $Trainer
  begin
    load File.expand_path("../../../games/infinitefusion_common/radar_banner.rb", File.dirname(__FILE__))
    $PokemonTemp = Struct.new(:pokeradar_ui).new(nil)
    trainer = Object.new
    def trainer.seen?(sp); sp != :MEW; end
    $Trainer = trainer

    SpeakCapture.clear
    displayPokeradarBanner([:PIDGEY, :RATTATA], [:ODDISH, :ABRA], true)
    playPokeradarLightAnimation(true)
    eq "the seen species by name, the silhouettes and the rare ones counted apart, then the green light",
       SpeakCapture.lines,
       [PokeAccess.sentences([t.t(:if_radar_seen, :list => "SpeciesPIDGEY, SpeciesRATTATA"),
                              t.t(:if_radar_unseen, :n => 2), t.t(:if_radar_rare, :list => "SpeciesPIKACHU"),
                              t.t(:if_radar_rare_unseen, :n => 1)]),
        t.t(:if_radar_rare_on)]

    SpeakCapture.clear
    displayPokeradarBanner([:PIDGEY], [], false)
    silent "a banner already up, as the chain goes on, is not said again"

    $PokemonTemp.pokeradar_ui = nil
    SpeakCapture.clear
    displayPokeradarBanner([:PIDGEY], [], false)
    playPokeradarLightAnimation(false)
    eq "a route all seen, with no rare ones allowed, and the red light", SpeakCapture.lines,
       [t.t(:if_radar_seen, :list => "SpeciesPIDGEY"), t.t(:if_radar_rare_off)]
  ensure
    $PokemonTemp = old_temp
    $Trainer = old_trainer
  end
end
