require 'fileutils'

require_relative '../header.rb'
require_relative '../metadata.rb'

# an array of all occurances of chapters in the manuscript
chapterheads = File.read(Bkmkr::Paths.outputtmp_html).scan(/section data-type="chapter"/)

# Local path vars, css files 
tmp_layout_dir = File.join(Bkmkr::Project.working_dir, "done", Metadata.pisbn, "layout")

pdf_css_file = File.join(tmp_layout_dir, "pdf.css")
epub_css_file = File.join(tmp_layout_dir, "epub.css")

if File.file?(pdf_css_file)
	pdf_css = File.read(pdf_css_file)
	unless chapterheads.count > 1
		File.open(pdf_css_file, 'w') do |p|
			p.write "#{pdf_css}section[data-type='chapter']>h1{display:none;}"
		end
	end
end

if File.file?(epub_css_file)
	epub_css = File.read(epub_css_file)
	unless chapterheads.count > 1
		File.open(epub_css_file, 'w') do |e|
			e.write "#{epub_css}h1.ChapTitlect{display:none;}"
		end
	end
end
