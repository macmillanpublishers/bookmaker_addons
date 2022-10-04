#encoding: UTF-8
require 'fileutils'
require 'net/smtp'
require 'nokogiri'
require 'json'

unless (ENV['TRAVIS_TEST']) == 'true'
  require_relative '../bookmaker/core/header.rb'
  require_relative '../bookmaker/core/metadata.rb'
else
  puts " --- testing mode:  running travis build"
  require_relative './unit_testing/for_travis-bookmaker_submodule/bookmaker/core/header.rb'
  require_relative './unit_testing/for_travis-bookmaker_submodule/bookmaker/core/metadata.rb'
end


# ---------------------- VARIABLES

local_log_hash, @log_hash = Bkmkr::Paths.setLocalLoghash

styleconfig_json = File.join(Bkmkr::Paths.scripts_dir, "htmlmaker_js_rsuite", "style_config.json")

chunk_xsl = File.join(Bkmkr::Paths.scripts_dir, "HTMLBook", "htmlbook-xsl", "chunk.xsl")

oebps_dir = File.join(Bkmkr::Paths.project_tmp_dir, "OEBPS")

toc01_html = File.join(oebps_dir, "toc01.xhtml")

zipepub_py = File.join(Bkmkr::Paths.core_dir, "epubmaker", "zipepub.py")

# path to fallback font file
font = File.join(Bkmkr::Paths.scripts_dir, "bookmaker_assets", "epubmaker", "fonts", "NotoSansSymbols-Regular.ttf")

# path to epubcheck
epubcheck = File.join(Bkmkr::Paths.core_dir, "epubmaker", "epubcheck", "epubcheck.jar")

epubmakerpostprocessingjs = File.join(Bkmkr::Paths.scripts_dir, "bookmaker_addons", "epubmaker_postprocessing.js")

epubmakerpostprocessingTOCjs = File.join(Bkmkr::Paths.scripts_dir, "bookmaker_addons", "epubmaker_postprocessing-TOC.js")

endnote_link_js = File.join(Bkmkr::Paths.scripts_dir, "bookmaker_addons", "epubmaker_postprocessing-endnote_link.js")

testing_value_file = File.join(Bkmkr::Paths.resource_dir, "staging.txt")

# full path of epubcheck error file
epubcheck_errfile = File.join(Metadata.final_dir, "EPUBCHECK_ERROR.txt")

unless (ENV['TRAVIS_TEST']) == 'true'
  @smtp_address = Mcmlln::Tools.readFile("#{$scripts_dir}/bookmaker_authkeys/smtp.txt").strip()
end

# ---------------------- METHODS

## wrapping a Mcmlln::Tools method in a new method for this script; to return a result for json_logfile
def readJson(jsonfile, logkey='')
  data_hash = Mcmlln::Tools.readjson(jsonfile)
  return data_hash
rescue => logstring
  return {}
ensure
  Mcmlln::Tools.logtoJson(@log_hash, logkey, logstring)
end

def getHTMLfilenameTypes(styleconfig_hash, logkey='')
  types = []
  styleconfig_hash['toplevelheads'].each do |key, hash|
	   types << hash['type']
  end
  return types
rescue => logstring
  return []
ensure
  Mcmlln::Tools.logtoJson(@log_hash, logkey, logstring)
end

def getHTMLfileShortNames(chunk_xsl, logkey='')
  shortnames = []
  doc = File.open(chunk_xsl) { |f| Nokogiri::XML(f) }
  node = doc.xpath('//xsl:param[@name="output.filename.prefix.by.data-type"]').first.content
  node.each_line { |line|
  	unless line.strip().empty?
  		shortnames << line.split(':')[1].strip()
  	end
  }
  return shortnames
rescue => logstring
  return []
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

def getXHTMLfiles(oebps_dir, htmlfilenames, logkey='')
  allXhtmlFiles = []
  htmlfilenames.uniq.each { |prefix|
    file_select_string = "#{prefix}[0-9][0-9]*.xhtml"
    searchdir = File.join(oebps_dir, file_select_string)
    xhtmlFiles = Dir.glob(searchdir)
    allXhtmlFiles += xhtmlFiles
  }
  return allXhtmlFiles
rescue => logstring
  return []
ensure
  Mcmlln::Tools.logtoJson(@log_hash, logkey, logstring)
end

def addLinkstoTOC(allXhtmlFiles, epubmakerpostprocessingjs, doctemplatetype, logkey='')
  allXhtmlFiles.each do |c|
    Bkmkr::Tools.runnode(epubmakerpostprocessingjs, "#{c} #{doctemplatetype}")
  end
rescue => logstring
ensure
  Mcmlln::Tools.logtoJson(@log_hash, logkey, logstring)
end

def prepareArrayForJS(myarray, logkey='')
  dqarray = myarray.map {|x| "\"#{x}\""}.compact
  json_array = JSON.generate(dqarray)
  return json_array
rescue => logstring
ensure
  Mcmlln::Tools.logtoJson(@log_hash, logkey, logstring)
end

def linkAnyEndnotes(bmfiles, htmlfiles, endnote_link_js, endnotetext_class, enoteref_id_prefix, logkey='')
  jsready_bmfilelist = prepareArrayForJS(bmfiles, 'prep_bmfiles_array_forJS')
  jsready_allfilelist = prepareArrayForJS(htmlfiles, 'prep_allfiles_array_forJS')
  endnote_link_results = Bkmkr::Tools.runnode(endnote_link_js, "#{endnotetext_class} #{enoteref_id_prefix} #{jsready_bmfilelist} #{jsready_allfilelist}")
  logstring = endnote_link_results
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

## wrapping Bkmkr::Tools.runnode in a new method for this script; to return a result for json_logfile
def localRunNode(jsfile, args, logkey='')
  Bkmkr::Tools.runnode(jsfile, args)
rescue => logstring
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

def rmOpfMetatag(opfcontents, logkey='')
  new_opf = Nokogiri::XML(opfcontents)
  new_opf.xpath('//xmlns:meta[@id="meta-identifier" and @property="dcterms:identifier"]').remove
  nonpretty_newopf = new_opf.to_xml(:indent => 0)
  return nonpretty_newopf
rescue => logstring
  return ''
ensure
  Mcmlln::Tools.logtoJson(@log_hash, logkey, logstring)
end

def listSpacebreakImages(file, imageclassname, logkey='')
  # An array of all the image files referenced in the source html file
  imgarr = File.read(file).scan(/(figure class="#{imageclassname} customimage"><img src="images\/)(\S*)(")/)
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

## wrapping Bkmkr::Tools.runJar in a new method for this script; to return a result for json_logfile
def localRunJar(java_opts, jar_script, input_file, logkey='')
	Bkmkr::Tools.runjar(java_opts, jar_script, input_file)
rescue => logstring
ensure
  Mcmlln::Tools.logtoJson(@log_hash, logkey, logstring)
end

def writeErrfile(epubcheck_status, epubcheck_output, epubcheck_errfile, logkey='')
  if epubcheck_status.exitstatus != 0 || epubcheck_output =~ /ERROR/ || epubcheck_output =~ /Check finished with errors/
  	File.open(epubcheck_errfile, 'w') do |output|
  		output.puts "Epub validation via epubcheck encountered errors."
      output.puts "\n \nEpubcheck status: #{epubcheck_status}"
      output.puts "\n(Epubcheck detailed output:)\n "
      output.puts epubcheck_output
  	end
  else
    logstring = 'n-a'
  end
rescue => logstring
ensure
  Mcmlln::Tools.logtoJson(@log_hash, logkey, logstring)
end

def sendAlertMail(epubcheck_status, epubcheck_output, testing_value_file, message, logkey='')
  if epubcheck_status.exitstatus != 0 || epubcheck_output =~ /ERROR/ || epubcheck_output =~ /Check finished with errors/
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

# If an epubcheck_errfile exists, delete it
deleteFileIfPresent(epubcheck_errfile, 'delete_epubcheck_errfile')

data_hash = readJson(Metadata.configfile, 'read_config_json')
#local definition(s) based on config.json
stage_dir = data_hash['stage']
project_name = data_hash['project']
doctemplatetype = data_hash['doctemplatetype']
# set bookmaker_assets path based on presence of rsuite styles
if doctemplatetype == "rsuite"
  imageclassname = "Image-PlacementImg"
else
  imageclassname = "Illustrationholderill"
end

endnotetxt_class = "endnotetext"

enoteref_id_prefix = "endnoteref"

styleconfig_hash = readJson(styleconfig_json, 'read_styleconfig_json')

htmlfilenames = getHTMLfilenameTypes(styleconfig_hash, 'get_html_filename-types')

htmlfileshortnames = getHTMLfileShortNames(chunk_xsl, 'get_html_file_short_names')

# # combine the 2 arrays of html filename prefix-possiblities
htmlfilenames.concat htmlfileshortnames

all_htmlfiles = getXHTMLfiles(oebps_dir, htmlfilenames, 'getXHTMLfiles_All')

# for every html file in OEBPS with one of these filename prefixes, create links to TOC for every heading.
addLinkstoTOC(all_htmlfiles, epubmakerpostprocessingjs, doctemplatetype, "add_TOC_links_to_heads_in_html_files")

appendix_htmlfiles = getXHTMLfiles(oebps_dir, ['app', 'appendix'], 'getXHTMLfiles_appendix')

# finds endnote text in bm html, scans all html for matching refs and links, goes back to Notes section to create reverse links
# also adds corresponding note numbers to backmatter
linkAnyEndnotes(appendix_htmlfiles, all_htmlfiles, endnote_link_js, endnotetxt_class, enoteref_id_prefix, 'epubmaker_postprocessing-endnote_find_js')

# # fix toc entry in ncx
# # fix title page text in ncx
ncxcontents = readFile("#{oebps_dir}/toc.ncx", 'read_ncxcontents')
replace = fixTOCandTPtextinNCX(ncxcontents, 'fix_toc_and_tptext_in_NCX')
overwriteFile("#{oebps_dir}/toc.ncx", replace, 'write_new_ncxcontents')

# hide toc entry in html toc
# fix title page text in html toc
localRunNode(epubmakerpostprocessingTOCjs, toc01_html, 'epubmaker_postprocessing_TOC_js')

# make edits to contents.opf:
opfcontents = readFile("#{oebps_dir}/content.opf", 'read_opfcontents')
#   add toc to text flow
opfcontents_b = addTOCtoTextFlow(opfcontents, 'add_toc_to_text_flow')
#   rm <meta id="meta-identifier"> element from content.opf (wdv-416, as per netgalley)
opfcontents_c = rmOpfMetatag(opfcontents_b, 'rm_vestigial_meta_tag')
# write edited donctents.opf content back out to file
overwriteFile("#{oebps_dir}/content.opf", opfcontents_c, 'write_new_opfcontents')

# remove titlepage.jpg if exists
podtitlepagetmp = File.join(oebps_dir, "titlepage.jpg")
deleteFileIfPresent(podtitlepagetmp, 'delete_podtitlepagetmp')

# run method: listImages
imgarr = listSpacebreakImages(Bkmkr::Paths.outputtmp_html, imageclassname, 'list_spacebreak_images')
# adjust size of custom space break images
convertSpacebreakImgs(imgarr, oebps_dir, 'convert_spacebreak_imgs')

# copy fallback font to package
copyFile(font, oebps_dir, 'copy_fallback_font_to_pkg')

# determine name of epub we're zipping based on project
if stage_dir.include?("egalley") || stage_dir.include?("galley") || stage_dir.include?("firstpass") || \
  (project_name == 'validator' && stage_dir == 'direct')
  csfilename = "#{Metadata.pisbn}_EPUBfirstpass"
  # rm non-firstpass epub from final_dir (dropped there from epubmaker.rb)
  nonfirstpass_epubfile = File.join(Metadata.final_dir ,"#{Metadata.eisbn}_EPUB.epub")
  deleteFileIfPresent(nonfirstpass_epubfile, 'rm_non-firstpass_epub')
else
  csfilename = "#{Metadata.eisbn}_EPUB"
end

# zip epub
localRunPython(zipepub_py, "#{csfilename}.epub #{Bkmkr::Paths.project_tmp_dir}", 'zip_epub_pyscript')

# copy epub to archival dir
copyFile("#{Bkmkr::Paths.project_tmp_dir}/#{csfilename}.epub", Metadata.final_dir, 'copy_epub_to_Done_dir')

# validate epub file, include flag to prevent stackoverflow error with epubcheck 4
epubcheck_output, epubcheck_status = localRunJar("-Xss1024k", epubcheck, "#{Metadata.final_dir}/#{csfilename}.epub")
@log_hash['epubcheck_status'] = epubcheck_status
puts "epubcheck_status: #{epubcheck_status}"
# handle utf-8 unfriendly chars
epubcheck_output = epubcheck_output.force_encoding("ISO-8859-1").encode("utf-8", replace: nil)
@log_hash['epubcheck_output'] = epubcheck_output
puts epubcheck_output  #for log (so warnings are still visible)

#if error in epubcheck, write file for user, and email workflows
writeErrfile(epubcheck_status, epubcheck_output, epubcheck_errfile, 'write_errfile_as_needed')
message = <<MESSAGE_END
From: Workflows <workflows@macmillan.com>
To: Workflows <workflows@macmillan.com>
Subject: ERROR: epubcheck errors for #{csfilename}.epub

Epubcheck validation found errors for file:
#{Metadata.final_dir}/#{csfilename}.epub

Epubcheck status:  #{epubcheck_status}
Epubcheck output:
#{epubcheck_output}
MESSAGE_END
sendAlertMail(epubcheck_status, epubcheck_output, testing_value_file, message, 'send_alert_mail')


# Write json log:
Mcmlln::Tools.logtoJson(@log_hash, 'completed', Time.now)
Mcmlln::Tools.write_json(local_log_hash, Bkmkr::Paths.json_log)
