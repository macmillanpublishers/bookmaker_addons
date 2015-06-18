require 'FileUtils'

require_relative '../bookmaker/core/header.rb'

# formerly in metadata.rb
# testing to see if ISBN style exists
spanisbn = File.read(Bkmkr::Paths.outputtmp_html).scan(/spanISBNisbn/)
multiple_isbns = File.read(Bkmkr::Paths.outputtmp_html).scan(/spanISBNisbn">\s*.+<\/span>\s*\(((hardcover)|(trade\s*paperback)|(e-*book))\)/)

# determining print isbn
if spanisbn.length != 0 && multiple_isbns.length != 0
	pisbn_basestring = File.read(Bkmkr::Paths.outputtmp_html).match(/spanISBNisbn">\s*.+<\/span>\s*\(((hardcover)|(trade\s*paperback))\)/).to_s.gsub(/-/,"").gsub(/\s+/,"").gsub(/\["/,"").gsub(/"\]/,"")
	pisbn = pisbn_basestring.match(/\d+<\/span>\(((hardcover)|(trade\s*paperback))\)/).to_s.gsub(/<\/span>\(.*\)/,"").gsub(/\["/,"").gsub(/"\]/,"")
elsif spanisbn.length != 0 && multiple_isbns.length == 0
	pisbn_basestring = File.read(Bkmkr::Paths.outputtmp_html).match(/spanISBNisbn">\s*.+<\/span>/).to_s.gsub(/-/,"").gsub(/\s+/,"").gsub(/\["/,"").gsub(/"\]/,"")
	pisbn = pisbn_basestring.match(/\d+<\/span>/).to_s.gsub(/<\/span>/,"").gsub(/\["/,"").gsub(/"\]/,"")
else
	pisbn_basestring = File.read(Bkmkr::Paths.outputtmp_html).match(/ISBN\s*.+\s*\(((hardcover)|(trade\s*paperback))\)/).to_s.gsub(/-/,"").gsub(/\s+/,"").gsub(/\["/,"").gsub(/"\]/,"")
	pisbn = pisbn_basestring.match(/\d+\(.*\)/).to_s.gsub(/\(.*\)/,"").gsub(/\["/,"").gsub(/"\]/,"")
end

# determining ebook isbn
if spanisbn.length != 0 && multiple_isbns.length != 0
	eisbn_basestring = File.read(Bkmkr::Paths.outputtmp_html).match(/spanISBNisbn">\s*.+<\/span>\s*\(e-*book\)/).to_s.gsub(/-/,"").gsub(/\s+/,"").gsub(/\["/,"").gsub(/"\]/,"")
	eisbn = eisbn_basestring.match(/\d+<\/span>\(ebook\)/).to_s.gsub(/<\/span>\(.*\)/,"").gsub(/\["/,"").gsub(/"\]/,"")
elsif spanisbn.length != 0 && multiple_isbns.length == 0
	eisbn_basestring = File.read(Bkmkr::Paths.outputtmp_html).match(/spanISBNisbn">\s*.+<\/span>/).to_s.gsub(/-/,"").gsub(/\s+/,"").gsub(/\["/,"").gsub(/"\]/,"")
	eisbn = pisbn_basestring.match(/\d+<\/span>/).to_s.gsub(/<\/span>/,"").gsub(/\["/,"").gsub(/"\]/,"")
else
	eisbn_basestring = File.read(Bkmkr::Paths.outputtmp_html).match(/ISBN\s*.+\s*\(e-*book\)/).to_s.gsub(/-/,"").gsub(/\s+/,"").gsub(/\["/,"").gsub(/"\]/,"")
	eisbn = eisbn_basestring.match(/\d+\(ebook\)/).to_s.gsub(/\(.*\)/,"").gsub(/\["/,"").gsub(/"\]/,"")
end

# just in case no isbn is found
if pisbn.length == 0
	pisbn = Bkmkr::Project.filename
end

if eisbn.length == 0
	eisbn = Bkmkr::Project.filename
end

# Finding imprint name
imprint = File.read(Bkmkr::Paths.outputtmp_html).scan(/<p class="TitlepageImprintLineimp">.*?</).to_s.gsub(/\["<p class=\\"TitlepageImprintLineimp\\">/,"").gsub(/"\]/,"").gsub(/</,"")

# Finding author name(s)
authorname = File.read(Bkmkr::Paths.outputtmp_html).scan(/<p class="TitlepageAuthorNameau">.*?</).join(",").gsub(/<p class="TitlepageAuthorNameau">/,"").gsub(/</,"")

# Finding book title
booktitle = File.read(Bkmkr::Paths.outputtmp_html).scan(/<title>.*?<\/title>/).to_s.gsub(/\["<title>/,"").gsub(/<\/title>"\]/,"")

# Finding book subtitle
booksubtitle = File.read(Bkmkr::Paths.outputtmp_html).scan(/<p class="TitlepageBookSubtitlestit">.*?</).to_s.gsub(/\["<p class=\\"TitlepageBookSubtitlestit\\">/,"").gsub(/<"\]/,"")

# project and stage
project_dir = Bkmkr::Project.input_file.split(Regexp.union(*[File::SEPARATOR, File::ALT_SEPARATOR].compact))[0...-2].pop.to_s.split("_").shift
stage_dir = Bkmkr::Project.input_file.split(Regexp.union(*[File::SEPARATOR, File::ALT_SEPARATOR].compact))[0...-2].pop.to_s.split("_").pop

# print and epub css files
epub_css_dir = File.join(Bkmkr::Paths.scripts_dir, "bookmaker_assets", "epubmaker", "css")
pdf_css_file = File.join(Bkmkr::Paths.scripts_dir, "bookmaker_assets", "pdfmaker", "css", project_dir, "pdf.css")

if File.file?("#{epub_css_dir}/#{project_dir}/epub.css")
	epub_css_file = "#{epub_css_dir}/#{project_dir}/epub.css"
else
 	epub_css_file = "#{epub_css_dir}/generic/epub.css"
end

pdf_js_file = File.join(Bkmkr::Paths.scripts_dir, "bookmaker_assets", "pdfmaker", "scripts", project_dir, "pdf.js")

xml_file = File.join(Bkmkr::Paths.project_tmp_dir, "#{Bkmkr::Project.filename}.xml")
check_toc = File.read(xml_file).scan(/w:pStyle w:val\="TOC/)
if check_toc.any?
	toc_value = "true"
else
	toc_value = "false"
end

configfile = File.join(Bkmkr::Paths.submitted_images, "config.json")

# Printing the project json
File.open(configfile, 'w+') do |f|
	f.puts '{'
	f.puts '"title":"' + booktitle + '",'
	f.puts '"subtitle":"' + booksubtitle + '",'
	f.puts '"author":"' + authorname + '",'
	f.puts '"productid":"' + pisbn + '",'
	f.puts '"printid":"' + pisbn + '",'
	f.puts '"ebookid":"' + eisbn + '",'
	f.puts '"imprint":"' + imprint + '",'
	f.puts '"publisher":"' + imprint + '",'
	f.puts '"project":"' + project_dir + '",'
	f.puts '"stage":"' + stage_dir + '",'
	f.puts '"printcss":"' + pdf_css_file + '",'
	f.puts '"printjs":"' + pdf_js_file + '",'
	f.puts '"ebookcss":"' + epub_css_file + '",'
	f.puts '"pod_toc":"' + toc_value + '",'
	f.puts '"frontcover":"' + pisbn + '_FC.jpg"'
	f.puts '}'
end