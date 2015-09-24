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
      $(this).find("span[class], em[class], strong[class]").each(function () {
        var thisClass = $(this).attr('class');
        var that = this.previousSibling;
        if (that && that.nodeType === 1 && that.tagName === this.tagName && typeof $(that).attr('class') !== 'undefined') {
              var thatClass = $(that).attr('class');
              if (thisClass === thatClass) {
              var node = createElement(this.tagName);
              while (that.firstChild) {
                  node.appendChild(that.firstChild);
              }
              while (this.firstChild) {
                  node.appendChild(this.firstChild);
              }
              this.parentNode.insertBefore(node, this.nextSibling);
              $(node).addClass(thisClass);
              that.parentNode.removeChild(that);
              this.parentNode.removeChild(this);
          }}
      });
  });

  // merge contiguous char styles
 $("p.ChapOpeningTextNo-Indentcotx1").each(function (i) {
   $(this).children("span.spansmallcapscharacterssc").each(function () {
          var that = this.previousSibling;
          if (!that) {
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