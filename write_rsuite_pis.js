var fs = require('fs');
var cheerio = require('cheerio');
var file = process.argv[2];
var pi_name = process.argv[3];
var pi_value = process.argv[4];

fs.readFile(file, function processTemplates (err, contents) {
  $ = cheerio.load(contents, {
          xmlMode: true
        });

  // remove any pre-existing meta-tags with this name attribute
  $("meta[name='"+ pi_name + "']").each(function () {
    $(this).remove()
  })

  // append new meta-tag to head with attribute-name
  var meta_pi = '<meta name="' + pi_name + '" content="' + pi_value + '"/>';
  $('head').append(meta_pi);


  var output = $.html();
    fs.writeFile(file, output, function(err) {
	    if(err) {
	        return console.log(err);
	    }

	    console.log("Processing instructions have been evaluated!");
	});
});
