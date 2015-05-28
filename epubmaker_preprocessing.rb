require 'FileUtils'

require_relative '../bookmaker/header.rb'
require_relative '../bookmaker/metadata.rb'

# These commands should run immediately prior to epubmaker

epub_tmp_html = File.join(Bkmkr::Paths.project_tmp_dir, "epub_tmp.html")

# Adding imprint logo to title page
# Removing images subdor from src attr
filecontents = File.read(Bkmkr::Paths.outputtmp_html).gsub(/<p class="TitlepageImprintLineimp">/,"<img src=\"logo.jpg\"/><p class=\"TitlepageImprintLineimp\">").gsub(/src="images\//,"src=\"")
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

strip_halftitle_xsl = File.join(Bkmkr::Paths.bookmaker_dir, "bookmaker_epubmaker", "strip-halftitle.xsl")

# strip halftitlepage from html
`java -jar "#{saxonpath}" -s:"#{epub_tmp_html}" -xsl:"#{strip_halftitle_xsl}" -o:"#{epub_tmp_html}"`

#set logo image based on project directory
logo_img = "#{Bkmkr::Paths.bookmaker_dir}/bookmaker_epubmaker/images/#{Bkmkr::Project.project_dir}/logo.jpg"

#copy logo image file to epub folder
FileUtils.cp(logo_img, "#{Bkmkr::Paths.done_dir}/#{Metadata.pisbn}/images")