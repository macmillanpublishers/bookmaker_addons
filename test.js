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

  // remove design notes
  $('.DesignNotedn').remove();

  var output = $.html();
    fs.writeFile(file, output, function(err) {
      if(err) {
          return console.log(err);
      }

console.log("HEEELLLLOOOOO")

      console.log("Content has been updated!");
  });
});
