require 'FileUtils'

require_relative '../bookmaker/header.rb'
require_relative '../bookmaker/metadata.rb'

# formerly in metadata.rb
# testing to see if ISBN style exists
spanisbn = File.read(html_file).scan(/spanISBNisbn/)
multiple_isbns = File.read(html_file).scan(/spanISBNisbn">\s*.+<\/span>\s*\(((hardcover)|(trade\s*paperback)|(e-*book))\)/)

# determining print isbn
if spanisbn.length != 0 && multiple_isbns.length != 0
	pisbn_basestring = File.read(html_file).match(/spanISBNisbn">\s*.+<\/span>\s*\(((hardcover)|(trade\s*paperback))\)/).to_s.gsub(/-/,"").gsub(/\s+/,"").gsub(/\["/,"").gsub(/"\]/,"")
	pisbn = pisbn_basestring.match(/\d+<\/span>\(((hardcover)|(trade\s*paperback))\)/).to_s.gsub(/<\/span>\(.*\)/,"").gsub(/\["/,"").gsub(/"\]/,"")
elsif spanisbn.length != 0 && multiple_isbns.length == 0
	pisbn_basestring = File.read(html_file).match(/spanISBNisbn">\s*.+<\/span>/).to_s.gsub(/-/,"").gsub(/\s+/,"").gsub(/\["/,"").gsub(/"\]/,"")
	pisbn = pisbn_basestring.match(/\d+<\/span>/).to_s.gsub(/<\/span>/,"").gsub(/\["/,"").gsub(/"\]/,"")
else
	pisbn_basestring = File.read(html_file).match(/ISBN\s*.+\s*\(((hardcover)|(trade\s*paperback))\)/).to_s.gsub(/-/,"").gsub(/\s+/,"").gsub(/\["/,"").gsub(/"\]/,"")
	pisbn = pisbn_basestring.match(/\d+\(.*\)/).to_s.gsub(/\(.*\)/,"").gsub(/\["/,"").gsub(/"\]/,"")
end

# determining ebook isbn
if spanisbn.length != 0 && multiple_isbns.length != 0
	eisbn_basestring = File.read(html_file).match(/spanISBNisbn">\s*.+<\/span>\s*\(e-*book\)/).to_s.gsub(/-/,"").gsub(/\s+/,"").gsub(/\["/,"").gsub(/"\]/,"")
	eisbn = eisbn_basestring.match(/\d+<\/span>\(ebook\)/).to_s.gsub(/<\/span>\(.*\)/,"").gsub(/\["/,"").gsub(/"\]/,"")
elsif spanisbn.length != 0 && multiple_isbns.length == 0
	eisbn_basestring = File.read(html_file).match(/spanISBNisbn">\s*.+<\/span>/).to_s.gsub(/-/,"").gsub(/\s+/,"").gsub(/\["/,"").gsub(/"\]/,"")
	eisbn = pisbn_basestring.match(/\d+<\/span>/).to_s.gsub(/<\/span>/,"").gsub(/\["/,"").gsub(/"\]/,"")
else
	eisbn_basestring = File.read(html_file).match(/ISBN\s*.+\s*\(e-*book\)/).to_s.gsub(/-/,"").gsub(/\s+/,"").gsub(/\["/,"").gsub(/"\]/,"")
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
booktitle = File.read(Bkmkr::Paths.outputtmp_html).scan(/<title>.*?<\/title>/).gsub(/<title>/,"").gsub(/<\/title>/,"")

# Finding book subtitle
booksubtitle = File.read(Bkmkr::Paths.outputtmp_html).scan(/<p class="TitlepageBookSubtitlestit">.*?</).gsub(/<p class="TitlepageBookSubtitlestit">/,"").gsub(/</,"")

configfile = File.join(Bkmkr::Paths.project_tmp_dir, "config.json")

# Printing the project json
File.open(configfile, 'a+') do |f|
	f.puts '"{'
	f.puts '"title":"#{booktitle}",'
	f.puts '"subtitle":"#{booksubtitle}",'
	f.puts '"author":"#{authorname}",'
	f.puts '"productid":"#{pisbn}",'
	f.puts '"printid":"#{pisbn}",'
	f.puts '"ebookid":"#{eisbn}",'
	f.puts '"imprint":"#{imprint}",'
	f.puts '"publisher":"#{imprint}",'
	f.puts '"frontcover":"#{pisbn}_FC.jpg"'
	f.puts '}'
end