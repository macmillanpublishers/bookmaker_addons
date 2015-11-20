require 'fileutils'
require 'json'

require_relative '../bookmaker/core/header.rb'
require_relative '../bookmaker/core/metadata.rb'

configfile = File.join(Bkmkr::Paths.project_tmp_dir, "config.json")
file = File.read(configfile)
data_hash = JSON.parse(file)

# an array of all occurances of chapters in the manuscript
chapterheads = File.read(Bkmkr::Paths.outputtmp_html).scan(/section data-type="chapter"/)

# Local path vars, css files 
tmp_layout_dir = File.join(Bkmkr::Project.working_dir, "done", Metadata.pisbn, "layout")

pdf_css_file = File.join(tmp_layout_dir, "pdf.css")
epub_css_file = File.join(tmp_layout_dir, "epub.css")

oneoff_45x7 = File.join(Bkmkr::Paths.scripts_dir, "bookmaker_assets", "pdfmaker", "css", "picador", "oneoff_45x7.css")
oneoff_45x7_sans = File.join(Bkmkr::Paths.scripts_dir, "bookmaker_assets", "pdfmaker", "css", "picador", "oneoff_45x7_sans.css")
oneoff_55x825 = File.join(Bkmkr::Paths.scripts_dir, "bookmaker_assets", "pdfmaker", "css", "picador", "oneoff_55x825.css")
oneoff_6x925 = File.join(Bkmkr::Paths.scripts_dir, "bookmaker_assets", "pdfmaker", "css", "picador", "oneoff_6x925.css")

if Bkmkr::Project.filename.include? "TRIM45x7" and stage_dir == "arc-sans"
	trimcss = File.read(oneoff_45x7_sans)
elsif Bkmkr::Project.filename.include? "TRIM45x7" and stage_dir != "arc-sans"
	trimcss = File.read(oneoff_45x7)
elsif Bkmkr::Project.filename.include? "TRIM55x825"
	trimcss = File.read(oneoff_55x825)
elsif Bkmkr::Project.filename.include? "TRIM6x925"
	trimcss = File.read(oneoff_6x925)
else
	trimcss = ""
end

if File.file?(pdf_css_file)
	if chapterheads.count > 1
		suppress_titles = " "
	else
		suppress_titles = "section[data-type='chapter']>h1{display:none;}"
	end
	if data_hash['pod_toc'] == "true"
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
