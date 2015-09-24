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

  // merge contiguous char styles
  $("p").each(function (i) {
   $(this).children("span.smallcaps").each(function () {
        var that = this.previousSibling;
        var thisClass = $(this).attr('class');
        console.log(thisClass);
        var thatClass = $(that).attr('class');
        console.log(thatClass);
        var testing = $(that).hasClass('smallcaps');
        console.log(testing);
        if ((that && that.nodeType === 1 && that.tagName === this.tagName && typeof $(that).attr('class') !== 'undefined' && $(that).hasClass('smallcaps') === true) || (!that)) {
          $(this).addClass("chapopener");
        }
      });
    });

  var output = $.html();
    fs.writeFile(file, output, function(err) {
      if(err) {
          return console.log(err);
      }

      console.log("Content has been updated!");
  });
});