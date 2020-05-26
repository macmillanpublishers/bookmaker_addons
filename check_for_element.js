var fs = require('fs');
var cheerio = require('cheerio');
var file = process.argv[2];
var element_tag = process.argv[3];
var element_class = process.argv[4];


fs.readFile(file, function editContent(err, contents) {
  $ = cheerio.load(contents, {
          xmlMode: true
        });

  var target_element = $(element_tag + "[class='" + element_class + "']")
  if (target_element.length > 0) {
    console.log('true');
  } else {
    console.log('false');
  }
});
