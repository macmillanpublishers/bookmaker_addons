require 'fileutils'
require 'json'

require_relative '../bookmaker/core/header.rb'
require_relative '../bookmaker/core/metadata.rb'

configfile = File.join(Bkmkr::Paths.project_tmp_dir, "config.json")
file = File.read(configfile)
data_hash = JSON.parse(file)

project_dir = data_hash['project']
stage_dir = data_hash['stage']

tmp_layout_dir = File.join(Bkmkr::Project.working_dir, "done", Metadata.pisbn, "layout")

oneoff_45x7 = File.join(Bkmkr::Paths.scripts_dir, "bookmaker_assets", "pdfmaker", "css", "picador", "oneoff_45x7.css")
oneoff_45x7_sans = File.join(Bkmkr::Paths.scripts_dir, "bookmaker_assets", "pdfmaker", "css", "picador", "oneoff_45x7_sans.css")
oneoff_55x825 = File.join(Bkmkr::Paths.scripts_dir, "bookmaker_assets", "pdfmaker", "css", "picador", "oneoff_55x825.css")
oneoff_6x925 = File.join(Bkmkr::Paths.scripts_dir, "bookmaker_assets", "pdfmaker", "css", "picador", "oneoff_6x925.css")

oneoff_p_css = File.join(tmp_layout_dir, "oneoff_pdf.css")

if Bkmkr::Project.filename.include? "TRIM45x7" and stage_dir == "arc-sans"
	FileUtils.cp(oneoff_45x7_sans, oneoff_p_css)
elsif Bkmkr::Project.filename.include? "TRIM45x7" and stage_dir != "arc-sans"
	FileUtils.cp(oneoff_45x7, oneoff_p_css)
elsif Bkmkr::Project.filename.include? "TRIM55x825"
	FileUtils.cp(oneoff_55x825, oneoff_p_css)
elsif Bkmkr::Project.filename.include? "TRIM6x925"
	FileUtils.cp(oneoff_6x925, oneoff_p_css)
end