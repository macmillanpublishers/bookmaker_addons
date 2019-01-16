var fs = require('fs');
var cheerio = require('cheerio');
var file = process.argv[2];
var doctemplatetype = process.argv[3];

fs.readFile(file, function editContent (err, contents) {
  $ = cheerio.load(contents, {
          xmlMode: true
        });

if (doctemplatetype == 'pre-sectionstart') {
    // Add links back to TOC to chapter heads
    $("section[data-type='chapter'] h1").each(function () {
      var newlink = "<a href='toc01.html'>" + $( this ).text() + "</a>";
      $(this).empty();
      $(this).prepend(newlink);
    });
    // Add links back to TOC to appendix heads
    $("section[data-type='appendix'] h1").each(function () {
      var newlink = "<a href='toc01.html'>" + $( this ).text() + "</a>";
      $(this).empty();
      $(this).prepend(newlink);
    });
   // add link back to TOC to preface heads
    $("section[data-type='preface'] h1").each(function () {
      var newlink = "<a href='toc01.html'>" + $( this ).text() + "</a>";
      $(this).empty();
      $(this).prepend(newlink);
    });
   // Add links back to TOC to part heads
    $("div[data-type='part'] h1").each(function () {
      var newlink = "<a href='toc01.html'>" + $( this ).text() + "</a>";
      $(this).empty();
      $(this).prepend(newlink);
    });
} else {
  // Add links back to TOC to all section heads and part heads
  $("body>section>div>h1, div[data-type='part']>section>h1, div[data-type='part']>h1").each(function () {
    var newlink = "<a href='toc01.html'>" + $( this ).text() + "</a>";
    $(this).empty();
    $(this).prepend(newlink);
  });
}

// Strip out the header elements
  $("header").remove();

  var output = $.html();
	  fs.writeFile(file, output, function(err) {
	    if(err) {
	        return console.log(err);
	    }

	    console.log("Content has been updated!");
	});
});
