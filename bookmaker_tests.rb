require 'fileutils'

require_relative '../bookmaker/core/header.rb'
require_relative '../bookmaker/core/metadata.rb'
require_relative '../bookmaker/core/utilities/mcmlln-tools.rb'

epub_tmp_html = File.join(Bkmkr::Paths.project_tmp_dir, "epub_tmp.html")
pdf_tmp_html = File.join(Bkmkr::Paths.project_tmp_dir, "pdf_tmp.html")
tmp_xml = File.join(Bkmkr::Paths.project_tmp_dir, "#{Bkmkr::Project.filename}.xml")

new_path = Bkmkr::Project.working_dir
test_ms_dirname = File.basename(Bkmkr::Project.filename, File.extname(Bkmkr::Project.filename))
verified_path = File.join(Bkmkr::Paths.scripts_dir, "bookmaker_tests", "verified_files", test_ms_dirname)
holding_path = File.join(Bkmkr::Project.working_dir, "verified_files", test_ms_dirname)
testdir = File.join(new_path, "test_tmpdir", test_ms_dirname)

vxml = File.join(verified_path, "#{Bkmkr::Project.filename}.xml")
holding_xml = File.join(holding_path, "#{Bkmkr::Project.filename}.xml")
vpdf = File.join(verified_path, "pdf_tmp.html")
holding_pdf = File.join(holding_path, "pdf_tmp.html")
vepub = File.join(verified_path, "epub_tmp.html")
holding_epub = File.join(holding_path, "epub_tmp.html")
vhtml = File.join(verified_path, "#{Metadata.pisbn}.html")
nhtml = File.join(Metadata.final_dir, "layout", "#{Metadata.pisbn}.html")
final_html = File.join(Metadata.final_dir, "layout", "#{Metadata.pisbn}.html")
holding_html = File.join(holding_path, "#{Metadata.pisbn}.html")
vjson = File.join(verified_path, "config.json")
njson = File.join(Metadata.final_dir, "layout", "config.json")
holding_json = File.join(holding_path, "config.json")
vecss = File.join(verified_path, "epub.css")
necss = File.join(Metadata.final_dir, "layout", "epub.css")
holding_ecss = File.join(holding_path, "epub.css")
vpcss = File.join(verified_path, "pdf.css")
npcss = File.join(Metadata.final_dir, "layout", "pdf.css")
holding_pcss = File.join(holding_path, "pdf.css")
testoutput = File.join(testdir, "testoutput.txt")
final_epubfile = File.join(Metadata.final_dir, "#{Metadata.eisbn}_EPUB.epub")
holding_epubfile = File.join(holding_path, "#{Metadata.eisbn}_EPUB.epub")
final_pdffile = File.join(Metadata.final_dir, "#{Metadata.pisbn}_POD.pdf")
holding_pdffile = File.join(holding_path, "#{Metadata.pisbn}_POD.pdf")
vjsonlog = File.join(verified_path, "#{Bkmkr::Project.filename}.json")
vjsonlog_tmp = File.join(testdir, "#{Bkmkr::Project.filename}_tmp.json")
njsonlog = Bkmkr::Paths.json_log
holding_jsonlog = File.join(holding_path, "#{Bkmkr::Project.filename}.json")

def mkDirAsNeeded(dirpath)
  unless File.directory?(dirpath)
    Mcmlln::Tools.makeDir(dirpath)
  end
end

def prettyprintHTML(file, dir, prefix)
  contents = File.read(file)
  contents = contents.gsub(/(<[a-z])/, "\n\\0").gsub(/\sid="[\w-]*"/, "\s").gsub(/href="#[\w-]*"/, "")
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

#create required dirs
mkDirAsNeeded(holding_path)
mkDirAsNeeded(testdir)

# skip diffs if verified files don't exist:
if File.directory?(verified_path)
  # check xml for differences
  nxml = prettyprintHTML(tmp_xml, testdir, "N")

  diff_xml = `diff '#{vxml}' '#{nxml}'`

  #Mcmlln::Tools.copyFile(tmp_xml, verified_path)

  # check pdf html for differences
  vpdf = prettyprintHTML(vpdf, testdir, "V")
  npdf = prettyprintHTML(pdf_tmp_html, testdir, "N")

  diff_pdf = `diff '#{vpdf}' '#{npdf}'`

  # check epub html for differences
  vepub = prettyprintHTML(vepub, testdir, "V")
  nepub = prettyprintHTML(epub_tmp_html, testdir, "N")

  diff_epub = `diff '#{vepub}' '#{nepub}'`

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

  # strip the cleanup scripts outputs from jsonlog for a clean diff
  jsonlog_hash = Mcmlln::Tools.readjson(vjsonlog)
  jsonlog_hash.delete('cleanup_preprocessing.rb')
  jsonlog_hash.delete('cleanup.rb')
  Mcmlln::Tools.write_json(jsonlog_hash, vjsonlog_tmp)

  # check json log for differences - excluding timestamp lines (with "begun" or "completed" strings as specified)
  diff_jsonlog = `diff -I '"begun": "2' -I '"completed": "2' '#{vjsonlog_tmp}' '#{njsonlog}'`

  File.open(testoutput, 'w') do |output|
    output.puts "----------CHECKING XML-----------"
    output.puts diff_xml
    output.puts "----------CHECKING PDF HTML-----------"
    output.puts diff_pdf
    output.puts "----------CHECKING EPUB HTML-----------"
    output.puts diff_epub
    output.puts "----------CHECKING LAYOUT HTML-----------"
    output.puts diff_html
    output.puts "----------CHECKING JSON-----------"
    output.puts diff_json
    output.puts "----------CHECKING EPUB CSS-----------"
    output.puts diff_ecss
    output.puts "----------CHECKING PDF CSS-----------"
    output.puts diff_pcss
    output.puts "----------CHECKING JSON LOGFILE-----------"
    output.puts diff_jsonlog
  end
else
  File.open(testoutput, 'w') do |output|
    output.puts "No existing verified files for this document, skipping diffs."
    output.puts "New verified files for this doc can be found here:"
    output.puts "  #{holding_path}"
    output.puts "Commit them to bookmaker_tests repo so they are available for future use."
  end
end

# Copy all new verified files to holding folder
Mcmlln::Tools.copyFile(final_html, holding_html)
Mcmlln::Tools.copyFile(epub_tmp_html, holding_epub)
Mcmlln::Tools.copyFile(njson, holding_json)
Mcmlln::Tools.copyFile(pdf_tmp_html, holding_pdf)
Mcmlln::Tools.copyFile(final_pdffile, holding_pdffile)
Mcmlln::Tools.copyFile(final_epubfile, holding_epubfile)
Mcmlln::Tools.copyFile(npcss, holding_pcss)
Mcmlln::Tools.copyFile(necss, holding_ecss)
Mcmlln::Tools.copyFile(nxml, holding_xml)
Mcmlln::Tools.copyFile(njsonlog, holding_jsonlog)

Mcmlln::Tools.deleteFile(nxml)
Mcmlln::Tools.deleteFile(vhtml)
Mcmlln::Tools.deleteFile(nhtml)
Mcmlln::Tools.deleteFile(vepub)
Mcmlln::Tools.deleteFile(nepub)
Mcmlln::Tools.deleteFile(vjson)
Mcmlln::Tools.deleteFile(njson)
Mcmlln::Tools.deleteFile(vpdf)
Mcmlln::Tools.deleteFile(npdf)
Mcmlln::Tools.deleteFile(vjsonlog_tmp)
