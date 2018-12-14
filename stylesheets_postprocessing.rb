require 'fileutils'
require 'json'

require_relative '../bookmaker/core/header.rb'
require_relative '../bookmaker/core/metadata.rb'

# ---------------------- VARIABLES
local_log_hash, @log_hash = Bkmkr::Paths.setLocalLoghash

# Local path vars, css files
tmp_layout_dir = File.join(Bkmkr::Project.working_dir, "done", Metadata.pisbn, "layout")

pdf_css_file = File.join(tmp_layout_dir, "pdf.css")
epub_css_file = File.join(tmp_layout_dir, "epub.css")

bookmaker_assets_dir = File.join(Bkmkr::Paths.scripts_dir, "bookmaker_assets")
oneoff_45x7 = File.join(bookmaker_assets_dir, "pdfmaker", "css", "picador", "oneoff_45x7.css")
oneoff_45x7_sans = File.join(bookmaker_assets_dir, "pdfmaker", "css", "picador", "oneoff_45x7_sans.css")


# ---------------------- METHODS

def readConfigJson(logkey='')
  data_hash = Mcmlln::Tools.readjson(Metadata.configfile)
  return data_hash
rescue => logstring
  return {}
ensure
  Mcmlln::Tools.logtoJson(@log_hash, logkey, logstring)
end

# collect chapterheads
def getChapters(logkey='')
	# an array of all occurances of chapters in the manuscript
	chapterheads = File.read(Bkmkr::Paths.outputtmp_html).scan(/section data-type="chapter"/)
	return chapterheads
rescue => logstring
	return []
ensure
  Mcmlln::Tools.logtoJson(@log_hash, logkey, logstring)
end

# check for processing instructions for trim
def getTrimPIs(stage_dir, logkey='')
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

  return trimcss, trimmessage
rescue => logstring
  return '',''
ensure
  Mcmlln::Tools.logtoJson(@log_hash, logkey, logstring)
end

# check for processing instructions for toc
def getTOCpis(logkey='')
	tocpicheck = File.read(Bkmkr::Paths.outputtmp_html).scan(/<meta name="toc" content="(auto|manual|none)"\/>/)
	if tocpicheck.nil? or tocpicheck.empty? or !tocpicheck
		toc_override = false
	else
		toc_override = true
	end

	return toc_override
rescue => logstring
	return ''
ensure
  Mcmlln::Tools.logtoJson(@log_hash, logkey, logstring)
end

def evalOneoffs(file, path, logkey='')
	tmp_layout_dir = File.join(Bkmkr::Project.working_dir, "done", Metadata.pisbn, "layout")
	oneoffcss_new = File.join(Bkmkr::Paths.submitted_images, file)
	oneoffcss_pickup = File.join(tmp_layout_dir, file)

	if File.file?(oneoffcss_new)
		FileUtils.mv(oneoffcss_new, oneoffcss_pickup)
		oneoffcss = File.read(oneoffcss_pickup)
		File.open(path, 'a+') do |o|
			o.write oneoffcss
		end
		logstring = 'found a new one-off, appended to css'
	elsif File.file?(oneoffcss_pickup)
		oneoffcss = File.read(oneoffcss_pickup)
		File.open(path, 'a+') do |o|
			o.write oneoffcss
		end
		logstring = 'found one-off from prev run, appended to css'
	else
		logstring = 'n-a'
	end
rescue => logstring
ensure
  Mcmlln::Tools.logtoJson(@log_hash, logkey, logstring)
end

def appendPdfCss(pdf_css_file, chapterheads, pod_toc, toc_override, trimcss, logkey='')
	if File.file?(pdf_css_file)
		# hide chaptertitle for books with only 1 chapter
		if chapterheads.count > 1
			suppress_titles = " "
		else
			suppress_titles = "section[data-type='chapter']>h1{display:none;}"
		end
		# suppress auto-toc via CSS based on tocpicheck (above) & xml check (from metadatapreprocessing)
		if pod_toc == "true" or toc_override == true
			suppress_toc = ''
		else
			suppress_toc = 'nav[data-type="toc"]{display:none;}'
		end
		# append chaptertitle, toc and trim changes to pdf css
		File.open(pdf_css_file, 'a+') do |p|
			p.puts suppress_titles
			p.puts suppress_toc
			p.puts trimcss
		end
		evalOneoffs("oneoff_pdf.css", pdf_css_file, 'eval_one-off-css_for_pdf')
	else
		logstring = 'no pdf_css_file'
	end
rescue => logstring
ensure
  Mcmlln::Tools.logtoJson(@log_hash, logkey, logstring)
end

def appendEpubCss(epub_css_file, chapterheads, logkey='')
	if File.file?(epub_css_file)
		unless chapterheads.count > 1
			File.open(epub_css_file, 'a+') do |e|
				e.puts "h1.ChapTitlect{display:none;}"
			end
		end
		evalOneoffs("oneoff_epub.css", epub_css_file, 'eval_one-off-css_for_epub')
	else
		logstring = 'no epub_css_file'
	end
rescue => logstring
ensure
  Mcmlln::Tools.logtoJson(@log_hash, logkey, logstring)
end


# ---------------------- PROCESSES
data_hash = readConfigJson('read_config_json')
#local definition(s) based on config.json
stage_dir = data_hash['stage']
pod_toc = data_hash['pod_toc']
doctemplatetype = data_hash['doctemplatetype']
# set bookmaker_assets path based on presence of rsuite styles
if doctemplatetype == "rsuite"
  oneoff_45x7 = File.join(bookmaker_assets_dir, "rsuite_assets", "pdfmaker", "css", "picador", "oneoff_45x7.css")
  oneoff_45x7_sans = File.join(bookmaker_assets_dir, "rsuite_assets", "pdfmaker", "css", "picador", "oneoff_45x7_sans.css")
end


# an array of all occurances of chapters in the manuscript
chapterheads = getChapters('get_chapters_from_html')

# check for processing instructions for trim
trimcss, trimmessage = getTrimPIs(stage_dir, 'get_trim_pis')
@log_hash['trim_message'] = trimmessage

# check for processing instructions for toc
toc_override = getTOCpis('get_toc_pis')

# for pdf, apply processing instructions results for trim, chapter titles, toc
# also eval any one-off-css files for pdf
appendPdfCss(pdf_css_file, chapterheads, pod_toc, toc_override, trimcss, 'append_pdf_css')

# hide chaptertitle for epubs with only 1 chapter
# also eval any one-off-css files for epub
appendEpubCss(epub_css_file, chapterheads, 'append_pdf_css')

# ---------------------- LOGGING

# Write json log:
Mcmlln::Tools.logtoJson(@log_hash, 'completed', Time.now)
Mcmlln::Tools.write_json(local_log_hash, Bkmkr::Paths.json_log)
