require 'fileutils'

require_relative '../bookmaker/core/header.rb'
require_relative '../bookmaker/core/metadata.rb'
require_relative '../bookmaker/core/utilities/mcmlln-tools.rb'

# first input argument must be the path to the folder where the verified files live
# second input argument must be the path to the folder where the newly converted files live
# third input argument is your testing directory

epub_tmp_html = File.join(Bkmkr::Paths.project_tmp_dir, "epub_tmp.html")
pdf_tmp_html = File.join(Bkmkr::Paths.project_tmp_dir, "pdf_tmp.html")

new_path = Bkmkr::Project.working_dir
verified_path = File.join(new_path, "verified_files")
testdir = File.join(new_path, "test_tmpdir")

vhtml = File.join(verified_path, "9780809089178.html")
nhtml = File.join(new_path, "layout", "9780809089178.html")
vepub = File.join(verified_path, "9781429945257_EPUBfirstpass.epub")
nepub = File.join(new_path, "9781429945257_EPUBfirstpass.epub")
vjson = File.join(verified_path, "config.json")
njson = File.join(new_path, "layout", "config.json")
vecss = File.join(verified_path, "epub.css")
necss = File.join(new_path, "layout", "epub.css")
vpcss = File.join(verified_path, "pdf.css")
npcss = File.join(new_path, "layout", "pdf.css")

def prettyprintHTML(file, dir, prefix)
  contents = File.read(file)
  contents = contents.gsub(/(<[a-z])/, "\n\\0").gsub(/id="\w*"/, "").gsub(/href="#\w*"/, "")
  filename = file.split(Regexp.union(*[File::SEPARATOR, File::ALT_SEPARATOR].compact)).pop
  newfile = File.join(dir, "#{prefix}_#{filename}")
  Mcmlln::Tools.overwriteFile(newfile, contents)
  return newfile
end

def prettyprintJSON(file, dir, prefix)
  contents = File.read(file)
  contents = contents.gsub(/(")(,")/, "\\1\n\\2")
  filename = file.split(Regexp.union(*[File::SEPARATOR, File::ALT_SEPARATOR].compact)).pop
  newfile = File.join(dir, "#{prefix}_#{filename}")
  Mcmlln::Tools.overwriteFile(newfile, contents)
  return newfile
end

Mcmlln::Tools.copyFile(epub_tmp_html, testdir)
Mcmlln::Tools.copyFile(pdf_tmp_html, testdir)

# check pdf html for differences

# check epub html for differences

# check layout html for differences
vhtml = prettyprintHTML(vhtml, testdir, "V")
nhtml = prettyprintHTML(nhtml, testdir, "N")

diff_html = `diff '#{vhtml}' '#{nhtml}'`

# check layout json for differences
vjson = prettyprintJSON(vjson, testdir, "V")
njson = prettyprintJSON(njson, testdir, "N")

diff_json = `diff '#{vjson}' '#{njson}'`

# check epub css for differences
diff_ecss = `diff '#{vecss}' '#{necss}'`

# check pdf css for differences
diff_pcss = `diff '#{vpcss}' '#{npcss}'`

File.open(file, 'w') do |output| 
  # output.puts "----------CHECKING PDF HTML-----------"
  # output.puts diff_pdf
  # output.puts "----------CHECKING EPUB HTML-----------"
  # output.puts diff_epub
  output.puts "----------CHECKING LAYOUT HTML-----------"
  output.puts diff_html
  puts "----------CHECKING JSON-----------"
  output.puts diff_json
  puts "----------CHECKING EPUB CSS-----------"
  output.puts diff_ecss
  puts "----------CHECKING PDF CSS-----------"
  output.puts diff_pcss
end

Mcmlln::Tools.deleteFile(vhtml)
Mcmlln::Tools.deleteFile(nhtml)
Mcmlln::Tools.deleteFile(vjson)
Mcmlln::Tools.deleteFile(njson)