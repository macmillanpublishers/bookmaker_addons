require 'fileutils'

require_relative '../bookmaker/core/header.rb'
require_relative '../bookmaker/core/metadata.rb'

# These commands should run immediately prior to filearchive

# Find supplemental titlepages
images = Dir.entries(Bkmkr::Paths.submitted_images)
finalimagedir = File.join(Bkmkr::Paths.done_dir, Metadata.pisbn, "images")
allimg = File.join(Bkmkr::Paths.submitted_images, "*")
etparr = Dir[allimg].select { |f| f.include?('epubtitlepage.')}
ptparr = Dir[allimg].select { |f| f.include?('titlepage.')}
if etparr.any?
  epubtitlepage = etparr.find { |e| /[\/|\\]epubtitlepage\./ =~ e }
end

if ptparr.any?
  podtitlepage = ptparr.find { |e| /[\/|\\]titlepage\./ =~ e }
end

if File.file?(epubtitlepage)
	etpfilename = epubtitlepage.split(Regexp.union(*[File::SEPARATOR, File::ALT_SEPARATOR].compact)).pop
	epubtitlepagearc = File.join(finalimagedir, etpfilename)
	FileUtils.mv(epubtitlepage, epubtitlepagearc)
end

if File.file?(podtitlepage)
	ptpfilename = podtitlepage.split(Regexp.union(*[File::SEPARATOR, File::ALT_SEPARATOR].compact)).pop
	podtitlepagearc = File.join(finalimagedir, ptpfilename)
	FileUtils.mv(podtitlepage, podtitlepagearc)
end