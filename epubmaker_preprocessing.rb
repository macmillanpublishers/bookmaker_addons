require 'fileutils'

require_relative '../bookmaker/core/header.rb'
require_relative '../bookmaker/core/metadata.rb'

# These commands should run immediately prior to epubmaker

configfile = File.join(Bkmkr::Paths.project_tmp_dir, "config.json")
file = File.read(configfile)
data_hash = JSON.parse(file)

project_dir = data_hash['project']
stage_dir = data_hash['stage']

def insertAddons(filename)
  addonsfile = File.join("addons.json")
  addonsread = File.read(addonsfile)
  addons_hash = JSON.parse(addonsread)

  sectionsfile = File.join("sections.json")
  sectionsread = File.read(sectionsfile)
  sections_hash = JSON.parse(sectionsread)

  all_addons = addons_hash['files']
  all_addons.each do |a|
    if (a['project'].include? project_dir or a['project'].include? "all") and (a['stage'].include? stage_dir or a['stage'].include? "all")
      location = File.read(a).match("LOCATION:.*").gsub(/\s/,"").gsub(/LOCATION:/,"")
      order = File.read(a).match("ORDER:.*").gsub(/\s/,"").gsub(/ORDER:/,"")
      addoncontent = File.read(a).gsub(/\=\=\=\=\=\=\=\=\=\=\=\=\=\=\=\=\=\=\=\=\=\=\=\n.*\n.*\n\=\=\=\=\=\=\=\=\=\=\=\=\=\=\=\=\=\=\=\=\=\=\=/,"")
      sections_hash['sections'].each do |s|
        if s == location
          datatype = s['datatype']
        end
      end
      if order == "before"
        addoncontents = File.read(filename).gsub(/()/,"#{addoncontent}\\1")
      elsif order == "after"
        addoncontents = File.read(filename).gsub(/()/,"\\1#{addoncontent}")
      end
      File.open(filename, 'w') do |o| 
        o.write addoncontents
      end
    end
  end
end

epub_tmp_html = File.join(Bkmkr::Paths.project_tmp_dir, "epub_tmp.html")
saxonpath = File.join(Bkmkr::Paths.resource_dir, "saxon", "#{Bkmkr::Tools.xslprocessor}.jar")
assets_dir = File.join(Bkmkr::Paths.scripts_dir, "bookmaker_assets", "epubmaker")

# Adding imprint logo to title page
# Removing images subdir from src attr
# inserting imprint backad, if it exists
# remove links from illo sources
# move copyright to back
backad_file = File.join(assets_dir, "images", project_dir, "backad.jpg")

if File.file?(backad_file)
  backad = "<section data-type='colophon'><img src='backad.jpg' alt='advertising'/></section>"
else
  backad = ""
end

copyrightpage = File.read(Bkmkr::Paths.outputtmp_html).match(/(<section data-type=\"copyright-page\" .*?\">)((.|\n)*?)(<\/section>)/)

filecontents = File.read(Bkmkr::Paths.outputtmp_html).gsub(/<p class="TitlepageImprintLineimp">/,"<img src=\"logo.jpg\"/><p class=\"TitlepageImprintLineimp\">").gsub(/src="images\//,"src=\"").gsub(/<\/body>/,"#{backad}</body>").gsub(/(<p class="IllustrationSourceis">)(<a class="fig-link">)(.*?)(<\/a>)(<\/p>)/, "\\1\\3\\5").gsub(/(<section data-type=\"copyright-page\" .*?\">)((.|\n)*?)(<\/section>)/,"").gsub(/(<\/body>)/, "#{copyrightpage}\\1")

chapterheads = File.read(Bkmkr::Paths.outputtmp_html).scan(/section data-type="chapter"/)

unless chapterheads.count > 1
  filecontents = filecontents.gsub(/(<section data-type="chapter" .*?><h1 class=".*?">)(.*?)(<\/h1>)/,"\\1Begin Reading\\3")
end

# Update several copyright elements for epub
if filecontents.include?('data-type="copyright-page"')
  copyright_txt = filecontents.match(/(<section data-type=\"copyright-page\" .*?\">)((.|\n)*?)(<\/section>)/)[2]
  # Note: last gsub here presumes Printer's key is the only copyright item that might be a <p>with just a number, eg <p class="xxx">13</p>
  new_copyright = copyright_txt.to_s.gsub(/(ISBN )([0-9\-]{13,20})( \(e-book\))/, "e\\1\\2").gsub(/ Printed in the United States of America./, "").gsub(/ Copyright( |\D|&.*?;)+/, " Copyright &#169; ").gsub(/<p class="\w*?">(\d+|(\d+\s){1,9}\d)<\/p>/, "")
  # Note: this gsub block presumes that these urls do not already have <a href> tags.
  new_copyright = new_copyright.gsub(/([^\s>]+.(com|org|net)[^\s<]*)/) do |m|
    url_prefix = "http:\/\/"
    if m.match(/@/)
      url_prefix = "mailto:"
    elsif m.match(/http/)
      url_prefix = ""
    end
    "<a href=\"#{url_prefix}#{m}\">#{m}<\/a>"
  end
  filecontents = filecontents.gsub(/(^(.|\n)*?<section data-type="copyright-page" id=".*?">)((.|\n)*?)(<\/section>(.|\n)*$)/, "\\1#{new_copyright}\\5")
end

File.open(epub_tmp_html, 'w') do |output| 
  output.write filecontents
end

# Make EBK hyperlinks
strip_span_xsl = File.join(Bkmkr::Paths.scripts_dir, "bookmaker_addons", "strip-spans.xsl")

`java -jar "#{saxonpath}" -s:"#{epub_tmp_html}" -xsl:"#{strip_span_xsl}" -o:"#{epub_tmp_html}"`

filecontents = File.read(epub_tmp_html).gsub(/(<p class="EBKLinkSourceLa">)(.*?)(<\/p>)(<p class="EBKLinkDestinationLb">)(.*?)(<\/p>)/,"\\1<a href=\"\\5\">\\2</a>\\3")

File.open(epub_tmp_html, 'w') do |output| 
  output.write filecontents
end

# strip halftitlepage from html
strip_halftitle_xsl = File.join(Bkmkr::Paths.core_dir, "epubmaker", "strip-halftitle.xsl")
# insert DRM copyright notice in HTML
drm_xsl = File.join(Bkmkr::Paths.scripts_dir, "bookmaker_addons", "drm.xsl")

`java -jar "#{saxonpath}" -s:"#{epub_tmp_html}" -xsl:"#{strip_halftitle_xsl}" -o:"#{epub_tmp_html}"`

`java -jar "#{saxonpath}" -s:"#{epub_tmp_html}" -xsl:"#{drm_xsl}" -o:"#{epub_tmp_html}"`

#set logo image based on project directory
logo_img = File.join(assets_dir, "images", project_dir, "logo.jpg")
epub_img_dir = File.join(Bkmkr::Paths.project_tmp_dir, "epubimg")

unless File.exist?(epub_img_dir)
    Dir.mkdir(epub_img_dir)
end

#copy logo image file to epub folder
FileUtils.cp(logo_img, epub_img_dir)

# copy backad file to epub dir
if File.file?(backad_file)
  FileUtils.cp(backad_file, epub_img_dir)
end
