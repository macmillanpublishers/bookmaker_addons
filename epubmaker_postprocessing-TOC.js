var fs = require('fs');
var cheerio = require('cheerio');
var file = process.argv[2];

fs.readFile(file, function editContent (err, contents) {
  $ = cheerio.load(contents, {
          xmlMode: true
        });


// edit Text for Title Page link
$("li[data-type='titlepage'] a[href*='titlepage']")[0]
  .text = "Title Page";

// add a non-printing <li> and link for TOC before copyright-page <li>
$("li[data-type='copyright-page']").before(
  $('<li>')
  .attr("data-type","toc")
  .addClass("Nonprinting")
  .append(
    $('<a>')
      .attr("href","toc01.xhtml")
      .append("Contents")
    ));

// add class "Nonprinting" to Newsletter Signup
$("li[data-type='preface'] a").each(function () {
  if (this.innerHTML == "Newsletter Sign-up") {
     $(this).parent().addClass("Nonprinting")
  }
});

// edit <a> for Cover: add text 'Cover', edit href, addClass Nonprinting
$("li[data-type='cover'] a[href='#bookcover01']")
  .text("Cover")
  .attr('href', "cover.xhtml")
  .parent().addClass("Nonprinting");


  var output = $.html();
    fs.writeFile(file, output, function(err) {
      if(err) {
          return console.log(err);
      }

      console.log("Content has been updated!");
  });
});
