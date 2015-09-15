require 'fileutils'

require_relative '../bookmaker/core/header.rb'
require_relative '../bookmaker/core/metadata.rb'

# These commands should run immediately prior to filearchive

# Find supplemental titlepages
finalimagedir = File.join(Bkmkr::Paths.done_dir, Metadata.pisbn, "images")

if File.file?(Metadata.podtitlepage)
	ptpfilename = Metadata.podtitlepage.split(Regexp.union(*[File::SEPARATOR, File::ALT_SEPARATOR].compact)).pop
	podtitlepagearc = File.join(finalimagedir, ptpfilename)
	FileUtils.mv(Metadata.podtitlepage, podtitlepagearc)
end

if File.file?(Metadata.epubtitlepage)
	etpfilename = Metadata.epubtitlepage.split(Regexp.union(*[File::SEPARATOR, File::ALT_SEPARATOR].compact)).pop
	epubtitlepagearc = File.join(finalimagedir, etpfilename)
	FileUtils.mv(Metadata.epubtitlepage, epubtitlepagearc)
end