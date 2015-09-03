var fs = require('fs');
var cheerio = require('cheerio');
var file = process.argv[2];

fs.readFile(file, function editContent (err, contents) {
  $ = cheerio.load(contents, {
          xmlMode: true
        });

// add titlepage image if applicable
  if ($('section[data-titlepage="yes"]').length) {
  	//remove content
  	$('section[data-type="titlepage"]').empty();
  	//add header back in w nonprinting class
  	header = '<h1 class="Nonprinting">Title Page</h1>';
  	$('section[data-type="titlepage"]').prepend(header);
  	//add image holder
  	image = '<img src="ebooktitlepage.jpg"/>';
  	$('section[data-type="titlepage"]').append(image);
  }

  var output = $.html();
	  fs.writeFile(file, output, function(err) {
	    if(err) {
	        return console.log(err);
	    }

	    console.log("Content has been updated!");
	});
});