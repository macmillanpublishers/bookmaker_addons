require 'fileutils'
require 'net/smtp'

require_relative '../bookmaker/core/header.rb'
require_relative '../bookmaker/core/metadata.rb'

# ---------------------- VARIABLES

local_log_hash, @log_hash = Bkmkr::Paths.setLocalLoghash

oebps_dir = File.join(Bkmkr::Paths.project_tmp_dir, "OEBPS")

zipepub_py = File.join(Bkmkr::Paths.core_dir, "epubmaker", "zipepub.py")

# path to fallback font file
font = File.join(Bkmkr::Paths.scripts_dir, "bookmaker_assets", "epubmaker", "fonts", "NotoSansSymbols-Regular.ttf")

# path to epubcheck
epubcheck = File.join(Bkmkr::Paths.core_dir, "epubmaker", "epubcheck", "epubcheck.jar")

epubmakerpostprocessingjs = File.join(Bkmkr::Paths.scripts_dir, "bookmaker_addons", "epubmaker_postprocessing.js")

testing_value_file = File.join(Bkmkr::Paths.resource_dir, "staging.txt")

# full path of epubcheck error file
epubcheck_errfile = File.join(Bkmkr::Paths.done_dir, Metadata.pisbn, "EPUBCHECK_ERROR.txt")

@smtp_address = Mcmlln::Tools.readFile("#{$scripts_dir}/bookmaker_authkeys/smtp.txt")

# ---------------------- METHODS

def readConfigJson(logkey='')
  data_hash = Mcmlln::Tools.readjson(Metadata.configfile)
  return data_hash
rescue => logstring
  return {}
ensure
  Mcmlln::Tools.logtoJson(@log_hash, logkey, logstring)
end

def deleteFileIfPresent(file, logkey='')
  if File.file?(file)
    Mcmlln::Tools.deleteFile(file)
  else
    logstring = 'n-a'
  end
rescue => logstring
ensure
  Mcmlln::Tools.logtoJson(@log_hash, logkey, logstring)
end

def addLinkstoTOC(oebps_dir, file_select_string, epubmakerpostprocessingjs, logkey='')
  searchdir = File.join(oebps_dir, file_select_string)
  chapfiles = Dir.glob(searchdir)
  chapfiles.each do |c|
    Bkmkr::Tools.runnode(epubmakerpostprocessingjs, c)
  end
rescue => logstring
ensure
  Mcmlln::Tools.logtoJson(@log_hash, logkey, logstring)
end

def readFile(file, logkey='')
	filecontents = File.read(file)
	return filecontents
rescue => logstring
  return ''
ensure
  Mcmlln::Tools.logtoJson(@log_hash, logkey, logstring)
end

## wrapping a Mcmlln::Tools method in a new method for this script; to return a result for json_logfile
def overwriteFile(path, filecontents, logkey='')
	Mcmlln::Tools.overwriteFile(path, filecontents)
rescue => logstring
ensure
  Mcmlln::Tools.logtoJson(@log_hash, logkey, logstring)
end

def fixTOCandTPtextinNCX(ncxcontents, logkey='')
  replace = ncxcontents.gsub(/<navLabel><text\/><\/navLabel><content src="toc/,"<navLabel><text>Contents</text><\/navLabel><content src=\"toc").gsub(/(<navLabel><text>)([a-zA-Z\s]*?)(<\/text><\/navLabel><content src="titlepage)/,"\\1Title Page\\3")
  return replace
rescue => logstring
  return ''
ensure
  Mcmlln::Tools.logtoJson(@log_hash, logkey, logstring)
end

def hideTOC_fixTPtext(htmlcontents, logkey='')
  copyright_li = htmlcontents.match(/<li data-type="copyright-page".*?<\/li>/)
  replace = htmlcontents.gsub(/(titlepage01.html#.*?">)(.*?)(<\/a>)/,"\\1Title Page\\3").gsub(/(<li data-type="copyright-page">)/,"<li data-type=\"toc\" class=\"Nonprinting\"><a href=\"toc01.html\">Contents</a></li>\\1").gsub(/(<li data-type="preface")(><a href=".*">Newsletter Sign-up)/,"\\1 class=\"Nonprinting\"\\2").gsub(/<li data-type="cover"><a href="\#bookcover01"\/>/,"<li data-type=\"cover\" class=\"Nonprinting\"><a href=\"cover.html\">Cover</a>")
  return replace
rescue => logstring
  return ''
ensure
  Mcmlln::Tools.logtoJson(@log_hash, logkey, logstring)
end

def addTOCtoTextFlow(opfcontents, logkey='')
  copyright_tag = opfcontents.scan(/<itemref idref="copyright-page/)
  tocid = opfcontents.match(/(id=")(toc-.*?)(")/)[2]
  toc_tag = opfcontents.match(/<itemref idref="toc-.*?"\/>/)
  if copyright_tag.any?
  	replace = opfcontents.gsub(/#{toc_tag}/,"").gsub(/(<itemref idref="copyright-page)/,"#{toc_tag}\\1")
  else
  	replace = opfcontents.gsub(/#{toc_tag}/,"").gsub(/(<\/spine)/,"#{toc_tag}\\1")
  end
  return replace
rescue => logstring
  return ''
ensure
  Mcmlln::Tools.logtoJson(@log_hash, logkey, logstring)
end

def listSpacebreakImages(file, logkey='')
  # An array of all the image files referenced in the source html file
  imgarr = File.read(file).scan(/(figure class="Illustrationholderill customimage"><img src="images\/)(\S*)(")/)
  imgnames = []
  imgarr.each do |o|
    imgnames << o[1]
  end
  # remove duplicate image names from source array
  imgnames = imgnames.uniq
  imgnames
rescue => logstring
  return []
ensure
  Mcmlln::Tools.logtoJson(@log_hash, logkey, logstring)
end

def convertSpacebreakImg(dir, file)
  path_to_i = File.join(dir, file)
  myres = `identify -format "%y" "#{path_to_i}"`
  myres = myres.to_f
  if File.file?(path_to_i)
    puts "RESIZING #{path_to_i} for EPUB"
    `convert "#{path_to_i}" -colorspace RGB -density #{myres} -resize "200x200>" -quality 100 "#{path_to_i}"`
  end
  return 'ok'
rescue => e
  return e
end

def convertSpacebreakImgs(imgarr, oebps_dir, logkey='')
  if imgarr.any?
    imgarr.each do |i|
      errcheck = convertSpacebreakImg(oebps_dir, i)
      # this errcheck is to trap & log (to json) error(s) from the child method
      if errcheck != "ok"
        logstring = "error: convertSpacebreakImg() with #{i}: #{errcheck}\n#{logstring}"
      end
    end
  else
    logstring = 'n-a'
  end
rescue => logstring
ensure
  Mcmlln::Tools.logtoJson(@log_hash, logkey, logstring)
end

## wrapping a Mcmlln::Tools method in a new method for this script; to return a result for json_logfile
def copyFile(src, dest, logkey='')
	Mcmlln::Tools.copyFile(src, dest)
rescue => logstring
ensure
  Mcmlln::Tools.logtoJson(@log_hash, logkey, logstring)
end

## wrapping Bkmkr::Tools.runpython in a new method for this script; to return a result for json_logfile
def localRunPython(py_script, args, logkey='')
	Bkmkr::Tools.runpython(py_script, args)
rescue => logstring
ensure
  Mcmlln::Tools.logtoJson(@log_hash, logkey, logstring)
end

def renameFinalEpub(csfilename, stage_dir, logkey='')
  if stage_dir.include? "egalley" or stage_dir.include? "galley" or stage_dir.include? "firstpass"
    Mcmlln::Tools.moveFile("#{Bkmkr::Paths.done_dir}/#{Metadata.pisbn}/#{Metadata.eisbn}_EPUB.epub", "#{Bkmkr::Paths.done_dir}/#{Metadata.pisbn}/#{Metadata.eisbn}_EPUBfirstpass.epub")
    csfilename = "#{Metadata.eisbn}_EPUBfirstpass"
  end
  return csfilename
rescue => logstring
  return csfilename
ensure
  Mcmlln::Tools.logtoJson(@log_hash, logkey, logstring)
end

## wrapping Bkmkr::Tools.runJar in a new method for this script; to return a result for json_logfile
def localRunJar(jar_script, input_file, logkey='')
	Bkmkr::Tools.runjar(jar_script, input_file)
rescue => logstring
ensure
  Mcmlln::Tools.logtoJson(@log_hash, logkey, logstring)
end

def writeErrfile(epubcheck_output, epubcheck_errfile, logkey='')
  if epubcheck_output =~ /ERROR/ || epubcheck_output =~ /Check finished with errors/
  	File.open(epubcheck_errfile, 'w') do |output|
  		output.puts "Epub validation via epubcheck encountered errors."
  		output.puts "\n \n(Epubcheck detailed output:)\n "
  		output.puts epubcheck_output
  	end
  else
    logstring = 'n-a'
  end
rescue => logstring
ensure
  Mcmlln::Tools.logtoJson(@log_hash, logkey, logstring)
end

def sendAlertMail(epubcheck_output, testing_value_file, message, logkey='')
  if epubcheck_output =~ /ERROR/ || epubcheck_output =~ /Check finished with errors/
    unless File.file?(testing_value_file)
      Net::SMTP.start(@smtp_address) do |smtp|
        smtp.send_message message, 'workflows@macmillan.com',
                                   'workflows@macmillan.com'
      end
    else
      logstring = 'on testing server, no mail sent'
    end
  else
    logstring = 'n-a'
  end
rescue => logstring
ensure
  Mcmlln::Tools.logtoJson(@log_hash, logkey, logstring)
end


# ---------------------- PROCESSES

data_hash = readConfigJson('read_config_json')
#local definition(s) based on config.json
stage_dir = data_hash['stage']

# If an epubcheck_errfile exists, delete it
deleteFileIfPresent(epubcheck_errfile, 'delete_epubcheck_errfile')

# Add links back to TOC to chapter heads
addLinkstoTOC(oebps_dir, "ch[0-9][0-9]*.html", epubmakerpostprocessingjs, 'add_links_to_TOC_to_chap_heads')

# Add links back to TOC to appendix heads
addLinkstoTOC(oebps_dir, "app[0-9][0-9]*.html", epubmakerpostprocessingjs, 'add_links_to_TOC_to_appendix_heads')

# Add links back to TOC to preface heads
addLinkstoTOC(oebps_dir, "preface[0-9][0-9]*.html", epubmakerpostprocessingjs, 'add_links_to_TOC_to_preface_heads')

# Add links back to TOC to part heads
addLinkstoTOC(oebps_dir, "part[0-9][0-9]*.html", epubmakerpostprocessingjs, 'add_links_to_TOC_to_part_heads')

# fix toc entry in ncx
# fix title page text in ncx
ncxcontents = readFile("#{oebps_dir}/toc.ncx", 'read_ncxcontents')
replace = fixTOCandTPtextinNCX(ncxcontents, 'fix_toc_and_tptext_in_NCX')
overwriteFile("#{oebps_dir}/toc.ncx", replace, 'write_new_ncxcontents')

# hide toc entry in html toc
# fix title page text in html toc
htmlcontents = readFile("#{oebps_dir}/toc01.html", 'read_htmlcontents')
replace = hideTOC_fixTPtext(htmlcontents, 'hide_toc-entry_in_toc__fix_tptext_in_toc')
overwriteFile("#{oebps_dir}/toc01.html", replace, 'write_new_htmlcontents')

# add toc to text flow
opfcontents = readFile("#{oebps_dir}/content.opf", 'read_opfcontents')
replace = addTOCtoTextFlow(opfcontents, 'add_toc_to_text_flow')
overwriteFile("#{oebps_dir}/content.opf", replace, 'write_new_opfcontents')

# remove titlepage.jpg if exists
podtitlepagetmp = File.join(oebps_dir, "titlepage.jpg")
deleteFileIfPresent(podtitlepagetmp, 'delete_podtitlepagetmp')

# run method: listImages
imgarr = listSpacebreakImages(Bkmkr::Paths.outputtmp_html, 'list_spacebreak_images')
# adjust size of custom space break images
convertSpacebreakImgs(imgarr, oebps_dir, 'convert_spacebreak_imgs')

csfilename = "#{Metadata.eisbn}_EPUB"

# copy fallback font to package
copyFile(font, oebps_dir, 'copy_fallback_font_to_pkg')

# zip epub
localRunPython(zipepub_py, "#{csfilename}.epub #{Bkmkr::Paths.project_tmp_dir}", 'zip_epub_pyscript')

# copy epub to archival dir
copyFile("#{Bkmkr::Paths.project_tmp_dir}/#{csfilename}.epub", "#{Bkmkr::Paths.done_dir}/#{Metadata.pisbn}", 'copy_epub_to_Done_dir')

# Renames final epub for firstpass
csfilename = renameFinalEpub(csfilename, stage_dir, 'rename_final_epub_for_firstpass')

# validate epub file
epubcheck_output = localRunJar(epubcheck, "#{Bkmkr::Paths.done_dir}/#{Metadata.pisbn}/#{csfilename}.epub")
@log_hash['epubcheck_output'] = epubcheck_output
puts epubcheck_output  #for log (so warnings are still visible)

#if error in epubcheck, write file for user, and email workflows
writeErrfile(epubcheck_output, epubcheck_errfile, 'write_errfile_as_needed')
message = <<MESSAGE_END
From: Workflows <workflows@macmillan.com>
To: Workflows <workflows@macmillan.com>
Subject: ERROR: epubcheck errors for #{csfilename}.epub

Epubcheck validation found errors for file:
#{Bkmkr::Paths.done_dir}/#{Metadata.pisbn}/#{csfilename}.epub

Epubcheck output:
#{epubcheck_output}
MESSAGE_END
sendAlertMail(epubcheck_output, testing_value_file, message, 'send_alert_mail')


# Write json log:
Mcmlln::Tools.logtoJson(@log_hash, 'completed', Time.now)
Mcmlln::Tools.write_json(local_log_hash, Bkmkr::Paths.json_log)
