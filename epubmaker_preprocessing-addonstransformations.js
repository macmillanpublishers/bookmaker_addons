var fs = require('fs');
var cheerio = require('cheerio');
var file = process.argv[2];

fs.readFile(file, function editContent (err, contents) {
  $ = cheerio.load(contents, {
          xmlMode: true
        });

  // find h1 elements with data-displayheader="no" and add class=ChapTitleNonprintingctnp
  $("h1[data-displayheader='no']").addClass("ChapTitleNonprintingctnp");

  var output = $.html();
    fs.writeFile(file, output, function(err) {
      if(err) {
          return console.log(err);
      }

      console.log("Content has been updated!");
  });
});
