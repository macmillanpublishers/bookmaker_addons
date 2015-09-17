var fs = require('fs');
var cheerio = require('cheerio');
var file = process.argv[2];
var booktitle = process.argv[3]; 
var bookauthor = process.argv[4];
var pisbn = process.argv[5];
var imprint = process.argv[6];
var publisher = process.argv[7];

fs.readFile(file, function editContent (err, contents) {
  $ = cheerio.load(contents, {
          xmlMode: true
        });

// add titlepage image if applicable
  if ($('section[data-titlepage="yes"]').length) {
  	//remove content
  	$('section[data-type="titlepage"]').empty();
  	//add image holder
  	image = '<figure class="fullpage"><img src="images/titlepage_fullpage.jpg"/></figure>';
  	$('section[data-type="titlepage"]').append(image);
  }

  var metabooktitle = '<meta name="title" content="' + booktitle + '"/>';
  var metabookauthor = '<meta name="author" content="' + bookauthor + '"/>';
  var metapisbn = '<meta name="isbn-13" content="' + pisbn + '"/>';
  var metaimprint = '<meta name="imprint" content="' + imprint + '"/>';
  var metapublisher = '<meta name="publisher" content="' + publisher + '"/>';

  $('head').append(metabooktitle);
  $('head').append(metabookauthor);
  $('head').append(metapisbn);
  $('head').append(metaimprint);
  $('head').append(metapublisher);

  var output = $.html();
	  fs.writeFile(file, output, function(err) {
	    if(err) {
	        return console.log(err);
	    }

	    console.log("Content has been updated!");
	});
});