var fs = require('fs');
var cheerio = require('cheerio');
var file = process.argv[2];
var doctemplatetype = process.argv[3];

fs.readFile(file, function editContent (err, contents) {
  $ = cheerio.load(contents, {
          xmlMode: true
        });

function appendHeadingTxt (newlink, newtext) {
  var newlinknode = $(newlink);
  //  if the preceding text was in an <a> toc link too, append this one to it
  if ((newlinknode.last() && newlinknode.last() != '' && newlinknode.last().filter("a[href='toc01.xhtml']")).length > 0) {
    newlinknode.last().append(newtext);
    newlink = newlinknode;
  } else {
    newlink += "<a href='toc01.xhtml'>" + newtext + "</a>";
  }
  return newlink;
}

if (doctemplatetype == 'pre-sectionstart') {
    // Add links back to TOC to chapter heads
    $("section[data-type='chapter'] h1").each(function () {
      var newlink = "<a href='toc01.xhtml'>" + $( this ).text() + "</a>";
      $(this).empty();
      $(this).prepend(newlink);
    });
    // Add links back to TOC to appendix heads
    $("section[data-type='appendix'] h1").each(function () {
      var newlink = "<a href='toc01.xhtml'>" + $( this ).text() + "</a>";
      $(this).empty();
      $(this).prepend(newlink);
    });
   // add link back to TOC to preface heads
    $("section[data-type='preface'] h1").each(function () {
      var newlink = "<a href='toc01.xhtml'>" + $( this ).text() + "</a>";
      $(this).empty();
      $(this).prepend(newlink);
    });
   // Add links back to TOC to part heads
    $("div[data-type='part'] h1").each(function () {
      var newlink = "<a href='toc01.xhtml'>" + $( this ).text() + "</a>";
      $(this).empty();
      $(this).prepend(newlink);
    });
} else {
  // Add links back to TOC to all section heads and part heads
  $("body>section>div>h1, div[data-type='part']>section>h1, div[data-type='part']>h1").each(function () {
    var newlink = "<a href='toc01.xhtml'>" + $( this ).text() + "</a>";

    // handling for noterefs in section heads
    var noterefs = $(this).find("sup>a[data-type='noteref']");
    if (noterefs.length > 0) {
      newlink = "";
      // iterate through heading contents, conditionally append children with note, vs text or children w.out note
      $(this).contents().each(function() {
        var noteref = $(this).find("sup>a[data-type='noteref']");
        if (noteref.length > 0) {
          if (noteref.length == 1 && $(this).html() == noteref.parent().html()) {
            newlink += noteref.parent();
          } else { // this means we have a nested element with note or notes as well as possible other text.
            // we split the htmlstring on the note html and add text only (with TOC links) for surrounding text
            var this_str = $(this).html();
            for (i=0; i<noteref.length; i++) {
              var split_str = this_str.split(noteref.eq(i).parent());
              // add content left of the note
              if (!this_str.startsWith(noteref.eq(i).parent())) {
                newlink = appendHeadingTxt(newlink, split_str[0]);
              }
              // add note html
              newlink += noteref.eq(i).parent();
              // truncate str
              this_str = split_str.pop();
            }
            // add content right of (all) the note(s)
            if (!this_str=="") {
              newlink = appendHeadingTxt(newlink, this_str);
            }
          }
        } else {
          newlink = appendHeadingTxt(newlink, $(this).text());
        }
      })
    }
    // console.log("newlink:  " + newlink )
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
