# A reader two games share lives once, in a common (games/<name>_common) both import: every import names a common with
# a manifest, a common is never a game (no catalog entry, no imports of its own, someone imports it), and no file is
# left copied between two playable profiles (compared with each file's own profile name blanked out, so a copy that
# differs only in its Game.define still counts).
require File.expand_path("imports", File.dirname(__FILE__))

Suite.define("static: profiles import commons, and no reader is copied between two games") do
  require "json"
  folders = Imports.folders
  commons = folders.select { |f| Imports.common?(f) }
  profiles = folders - commons

  bad = []
  profiles.each do |p|
    Imports.of(p).each do |c|
      bad.push("#{p} importa #{c}, que no acaba en _common") unless Imports.common?(c)
      bad.push("#{p} importa #{c}, sin games/#{c}/manifest.rb") unless folders.include?(c)
    end
  end
  eq "cada import nombra un comun existente con su manifest.rb", bad, []

  eq "ningun comun importa a otro: un solo nivel", commons.reject { |c| Imports.of(c).empty? }, []
  keys = JSON.parse(File.read(File.join(Imports::ROOT, "games", "catalog.json")))["profiles"].map { |e| e["key"] }
  eq "ningun comun tiene entrada en el catalogo: nunca se detecta como juego", commons & keys, []
  eq "y todo comun lo importa algun perfil", commons - Imports.importers.keys, []

  copies = {}
  profiles.each do |p|
    Dir.glob(File.join(Imports::ROOT, "games", p, "**", "*.rb")).sort.each do |f|
      next if File.basename(f) == "manifest.rb"
      rel = f[(Imports::ROOT.length + 1)..-1].tr("\\", "/")
      (copies[File.read(f).gsub(p, "<PROFILE>")] ||= []).push(rel)
    end
  end
  twins = copies.values.select { |rels| rels.map { |r| r.split("/")[1] }.uniq.length > 1 }
  eq "ningun fichero se repite entre dos perfiles jugables (lo compartido va a un comun)", twins.sort, []
end
