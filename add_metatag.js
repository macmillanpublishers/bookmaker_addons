var fs = require('fs');
var cheerio = require('cheerio');
var file = process.argv[2];
var name = process.argv[3];
var content = process.argv[4];

fs.readFile(file, function processTemplates (err, contents) {
  $ = cheerio.load(contents, {
          xmlMode: true
        });

  // add meta info for item if it doesn't already exist
  metacheck = $("meta[name='" + name + "']")
  if (metacheck.length == 0) {
    var metatemplateversion = '<meta name="' + name + '" content="' + content + '"/>';
    $('head').append(metatemplateversion);
  }

  var output = $.html();
    fs.writeFile(file, output, function(err) {
	    if(err) {
	        return console.log(err);
	    }

	    console.log("Processing instructions have been evaluated!");
	});
});
