// epubmaker_preprocessing-newsletterlinks.js

// If more than one author
// Pluralize about the authors link in newsletter
// a.spanhyperlink.abouttheauthor

// section.abouttheauthor:contains(firstname):contains(lastname);
// For each author, run node to: 
// find the correct ATA section (author first/last will be args)
// replace placeholders with auhtor info

var fs = require('fs');
var cheerio = require('cheerio');
var file = process.argv[2];
var linkauthorname = process.argv[3];
var linkauthorfirst = process.argv[4];
var linkauthorlast = process.argv[5];
var linkauthornameall = process.argv[6];
var linkauthornametxt = process.argv[7];
var thisauthorid = process.argv[8];

fs.readFile(file, function editContent (err, contents) {
  $ = cheerio.load(contents, {
          xmlMode: true
        });

  var newString = "About the Authors";
  $("a#abouttheauthor").empty().append(newString);

  var aulink = "<p class='BMTextbmtx'>You can sign up for email updates <a href='http://us.macmillan.com/authoralerts?authorName=" + linkauthornametxt + "&amp;authorRefId=" + thisauthorid + "&amp;utm_source=ebook&amp;utm_medium=adcard&amp;utm_term=ebookreaders&amp;utm_content=" + linkauthornameall + "_authoralertsignup_macdotcom&amp;utm_campaign={{EISBN}}'>here</a>.</p>";
  $("section.abouttheauthor:contains(" + linkauthorfirst + "):contains(" + linkauthorlast + ")").append(aulink);

  var newslink = "<p style='text-align: center; text-indent: 0;'>For email updates on " + linkauthorname + ", click <a href='http://us.macmillan.com/authoralerts?authorName=" + linkauthornametxt + "&amp;authorRefId=" + thisauthorid + "&amp;utm_source=ebook&amp;utm_medium=adcard&amp;utm_term=ebookreaders&amp;utm_content=" + linkauthornameall + "_authoralertsignup_macdotcom&amp;utm_campaign={{EISBN}}'>here.</a></p>"
  $("div.newsletterlink").append(newslink);
  $("p.originallink").remove();

var output = $.html();
    fs.writeFile(file, output, function(err) {
      if(err) {
          return console.log(err);
      }

      console.log("Content has been updated!");
  });
});