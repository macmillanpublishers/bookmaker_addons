var fs = require('fs');
var cheerio = require('cheerio');
var file = process.argv[2];
var linkauthornameall = process.argv[3];
var linkauthornametxt = process.argv[4];
var thisauthorid = process.argv[5];

fs.readFile(file, function editContent (err, contents) {
  $ = cheerio.load(contents, {
          xmlMode: true
        });

  var aulink = "<p class='BMTextbmtx'>You can sign up for email updates <a href='http://us.macmillan.com/authoralerts?authorName=" + linkauthornametxt + "&amp;authorRefId=" + thisauthorid + "&amp;utm_source=ebook&amp;utm_medium=adcard&amp;utm_term=ebookreaders&amp;utm_content=" + linkauthornameall + "_authoralertsignup_macdotcom&amp;utm_campaign={{EISBN}}'>here</a>.</p>";
  $("section.abouttheauthor").append(aulink);

var output = $.html();
    fs.writeFile(file, output, function(err) {
      if(err) {
          return console.log(err);
      }

      console.log("Content has been updated!");
  });
});