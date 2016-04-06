var fs = require('fs');
var cheerio = require('cheerio');
var file = process.argv[2];

fs.readFile(file, function editContent (err, contents) {
  $ = cheerio.load(contents, {
          xmlMode: true
        });

// add link to adcard head
  $('section.adcard h1').each(function () {
    var newlink = "<a href='toc01.html'>" + $( this ).text() + "</a>";
    $(this).empty();
    $(this).prepend(newlink); 
  });

  var output = $.html();
	  fs.writeFile(file, output, function(err) {
	    if(err) {
	        return console.log(err);
	    }

	    console.log("Content has been updated!");
	});
});