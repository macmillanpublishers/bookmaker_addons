# formerly in epubmaker
imprint = File.read(Bkmkr::Paths.outputtmp_html).scan(/<p class="TitlepageImprintLineimp">.*?</).to_s.gsub(/\["<p class=\\"TitlepageImprintLineimp\\">/,"").gsub(/"\]/,"").gsub(/</,"")

# Finding author name(s)
authorname1 = File.read(Bkmkr::Paths.outputtmp_html).scan(/<p class="TitlepageAuthorNameau">.*?</).join(",")
authorname2 = authorname1.gsub(/<p class="TitlepageAuthorNameau">/,"").gsub(/</,"")