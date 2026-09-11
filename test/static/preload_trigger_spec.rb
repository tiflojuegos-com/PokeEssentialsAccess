# loader/preload_access.rb decides the ONE moment the whole toolkit is loaded, and nothing ever ran it: the
# suite only compiled it. It cannot be loaded into the harness (it wraps Graphics.update and evals boot.rb),
# so it is driven here in a child Ruby over a synthetic game folder, exactly as dump_scripts_spec drives the
# dumper.
#
# What it pins is the bug that made four games mute on the run a new player makes first. The preload used to
# give up waiting after 120 frames and load anyway. Seven gen-6 games call pbSetUpSystem at TOP LEVEL,
# partway down their script list, and on a first run that call stops there to ask which language to play in;
# two seconds later the mod loaded into that pause with most of the game's classes not yet defined, bound
# almost nothing, and stayed silent for the rest of the session. The fallback must therefore wait for the
# script list to have finished, which Main's pbCallTitle proves.
Suite.define("static: the preload waits for the game's scripts to finish before loading the toolkit") do
  require "fileutils"
  root = File.expand_path("../..", File.dirname(__FILE__))
  preload = File.join(root, "loader", "preload_access.rb")
  truthy "the preload script is where the installer copies it from", File.file?(preload)

  base = File.join(File.dirname(__FILE__), "tmp_preload")
  FileUtils.rm_rf(base)
  FileUtils.mkdir_p(File.join(base, "accessibility", "data"))
  begin
    # The toolkit, as far as the preload knows: a file that records that it was evaluated.
    File.open(File.join(base, "accessibility", "boot.rb"), "w") do |f|
      f.write("File.open('booted.txt', 'a') { |g| g.write(\"boot\\n\") }\n")
    end

    # A game that pauses mid-boot (no $scene, script list unfinished), runs far past the fallback, and only
    # then finishes its scripts -- which is the language-chooser sequence, frame for frame.
    driver = File.join(base, "driver.rb")
    File.open(driver, "w") do |f|
      f.write(<<-'RB')
module Graphics
  def self.update(*a); nil; end
end
load ARGV[0]
booted = lambda { File.exist?("booted.txt") ? "si" : "no" }
400.times { Graphics.update }
print "durante_la_pausa=", booted.call, " "
# Main runs: its pbCallTitle appears, and only then is the game whole. Declared the way a game declares it
# -- a plain top-level def, which Ruby files away as a PRIVATE method of Object -- because define_method
# makes a PUBLIC one, and that is the branch no real game exercises: with a public method the check passes
# through method_defined? and private_method_defined? could be deleted with this spec still green, leaving
# the fallback dead in all fifteen games.
eval("def pbCallTitle; nil; end", TOPLEVEL_BINDING)
print "es_privado=", (Object.private_method_defined?(:pbCallTitle) && !Object.method_defined?(:pbCallTitle)) ? "si" : "no", " "
Graphics.update
print "tras_terminar_los_scripts=", booted.call, " "
print "veces=", (File.exist?("booted.txt") ? File.read("booted.txt").split("\n").length : 0)
      RB
    end
    out = IO.popen([RbConfig.ruby, driver, preload], :chdir => base, :err => [:child, :out]) { |io| io.read }
    truthy "the mod does NOT load while the game is still evaluating its scripts", out.include?("durante_la_pausa=no")
    truthy "and loads as soon as the script list has finished", out.include?("tras_terminar_los_scripts=si")
    truthy "driven through the shape a game really declares: a top-level def, private on Object",
           out.include?("es_privado=si")
    truthy "exactly once", out.include?("veces=1")

    # The normal path: Main assigns $scene before the first scene runs, so the toolkit is up for the title
    # screen without waiting for any fallback.
    driver2 = File.join(base, "driver2.rb")
    File.open(driver2, "w") do |f|
      f.write(<<-'RB')
module Graphics
  def self.update(*a); nil; end
end
load ARGV[0]
$scene = Object.new
Graphics.update
print "con_scene_al_primer_frame=", (File.exist?("booted2.txt") ? "si" : "no")
      RB
    end
    File.open(File.join(base, "accessibility", "boot.rb"), "w") do |f|
      f.write("File.open('booted2.txt', 'a') { |g| g.write(\"boot\\n\") }\n")
    end
    out2 = IO.popen([RbConfig.ruby, driver2, preload], :chdir => base, :err => [:child, :out]) { |io| io.read }
    truthy "with the main loop running the toolkit loads on the very first frame",
           out2.include?("con_scene_al_primer_frame=si")
  ensure
    FileUtils.rm_rf(base)
  end
end
