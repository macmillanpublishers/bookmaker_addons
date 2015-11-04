require 'fileutils'

require_relative '../bookmaker/core/header.rb'

# These commands should run immediately prior to htmlmaker
doctodocx = "S:\\resources\\bookmaker_scripts\\bookmaker_addons\\htmlmaker_preprocessing.ps1"
`PowerShell -NoProfile -ExecutionPolicy Bypass -Command "#{doctodocx} '#{Bkmkr::Paths.project_tmp_file}'"`