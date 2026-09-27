# Armonia photo gallery (AlbumScene): the page and how many of its 4 photos are unlocked, on each showPage.
PokeAccess::Game.define("armonia") do
  after("AlbumScene", :showPage) do |_scene, _result, args|
    page = args[0].to_i
    unlocked = 0
    4.times { |f| i = page * 4 + f; unlocked += 1 if ($game_switches[ALBUM_SWITCHES[i]] rescue false) }
    total = (ALBUM_PAGES rescue nil)
    pg = if total && PokeAccess::Verbosity.keep?(:positions, :medium)
           PokeAccess::I18n.t(:alb_page, :n => page + 1, :tot => total)
         else
           PokeAccess::I18n.t(:alb_page_bare, :n => page + 1)
         end
    PokeAccess.speak(PokeAccess::I18n.t(:alb_gallery, :page => pg, :n => unlocked), true)
  end
end
