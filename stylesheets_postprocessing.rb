require 'fileutils'
require 'json'

require_relative '../bookmaker/core/header.rb'
require_relative '../bookmaker/core/metadata.rb'

configfile = File.join(Bkmkr::Paths.project_tmp_dir, "config.json")
file = File.read(configfile)
data_hash = JSON.parse(file)

stage_dir = data_hash['stage']

# an array of all occurances of chapters in the manuscript
chapterheads = File.read(Bkmkr::Paths.outputtmp_html).scan(/section data-type="chapter"/)

# Local path vars, css files 
tmp_layout_dir = File.join(Bkmkr::Project.working_dir, "done", Metadata.pisbn, "layout")

pdf_css_file = File.join(tmp_layout_dir, "pdf.css")
epub_css_file = File.join(tmp_layout_dir, "epub.css")

oneoff_45x7 = File.join(Bkmkr::Paths.scripts_dir, "bookmaker_assets", "pdfmaker", "css", "picador", "oneoff_45x7.css")
oneoff_45x7_sans = File.join(Bkmkr::Paths.scripts_dir, "bookmaker_assets", "pdfmaker", "css", "picador", "oneoff_45x7_sans.css")

size = File.read(Bkmkr::Paths.outputtmp_html).scan(/<meta name="size"/)
unless size.nil? or size.empty? or !size
	size = File.read(Bkmkr::Paths.outputtmp_html).match(/(<meta name="size" content=")(\d*\.*\d*in \d*\.*\d*in)("\/>)/)[2].gsub(/\s/,"")
end

if size == "4.5in7.125in" and stage_dir == "arc-sans"
	trimcss = File.read(oneoff_45x7_sans)
	trimmessage = "Adding further css customizations: #{oneoff_45x7_sans}"
elsif size == "4.5in7.125in" and stage_dir != "arc-sans"
	trimcss = File.read(oneoff_45x7)
	trimmessage = "Adding further css customizations: #{oneoff_45x7}"
else
	trimcss = ""
	trimmessage = "No further css customizations"
end

tocpicheck = File.read(Bkmkr::Paths.outputtmp_html).scan(/<meta name="toc" content="(auto|manual|none)"\/>/)

if tocpicheck.nil? or tocpicheck.empty? or !tocpicheck
	toc_override = false
else
	toc_override = true
end

if File.file?(pdf_css_file)
	if chapterheads.count > 1
		suppress_titles = " "
	else
		suppress_titles = "section[data-type='chapter']>h1{display:none;}"
	end
	if data_hash['pod_toc'] == "true" or toc_override == true
		suppress_toc = ''
	else
		suppress_toc = 'nav[data-type="toc"]{display:none;}'
	end
	File.open(pdf_css_file, 'a+') do |p|
		p.puts suppress_titles
		p.puts suppress_toc
		p.puts trimcss
	end
end

if File.file?(epub_css_file)
	unless chapterheads.count > 1
		File.open(epub_css_file, 'a+') do |e|
			e.puts "h1.ChapTitlect{display:none;}"
		end
	end
end

# ---------------------- LOGGING

# Printing the test results to the log file
File.open(Bkmkr::Paths.log_file, 'a+') do |f|
	f.puts "----- STYLESHEETS_POSTPROCESSING PROCESSES"
	f.puts trimmessage
end
