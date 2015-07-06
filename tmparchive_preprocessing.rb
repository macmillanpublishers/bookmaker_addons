require 'fileutils'

require_relative '../bookmaker/header.rb'

# These commands should run immediately prior to tmparchive

# Copy the input file to the assets folder
FileUtils.cp(Bkmkr::Project.input_file, Bkmkr::Paths.assets)