var fs = require('fs');
var cheerio = require('cheerio');
var file = process.argv[2];

fs.readFile(file, function editContent (err, contents) {
  $ = cheerio.load(contents, {
          xmlMode: true
        });

// add titlepage image if applicable
  if ($('section[data-titlepage="yes"]').length) {
  	//remove content
  	$('section[data-type="titlepage"]').empty();
  	//add header back in w nonprinting class
  	header = '<h1 class="ChapTitleNonprintingctnp">Title Page</h1>';
  	$('section[data-type="titlepage"]').prepend(header);
  	//add image holder
  	image = '<img class="titlepage" src="epubtitlepage.jpg"/>';
  	$('section[data-type="titlepage"]').append(image);
  }

  // replace logo with image
  var logo = '<img src="logo.jpg"/>'
  $('p.TitlepageLogologo').empty().prepend(logo);

  // add extra paragraph to copyright page
  $('section[data-type="copyright-page"] p:last-child').removeClass( "CopyrightTextsinglespacecrtx" ).addClass( "CopyrightTextdoublespacecrtxd" );

  //remove existing bulk order notice from copyright page 
  var notice_criteria = [
  '(?=.*MacmillanSpecialMarkets@macmillan.com)',
  '(?=.*Macmillan Corporate and Premium Sales Department)',
  '(?=.*[Bb]ooks may be purchased)',
  '(?=.*promotional[^\.]*use)',
  '(?=.*educational[^\.]*use)',
  '(?=.*business[^\.]*use)',
  '(?=.*800..?221.?7945.*ext.*5442)',
  '.*'
  ];
  var regexpstring = notice_criteria.join('');
  var notice_regex = new RegExp(regexpstring);

  var notice = $('section[data-type="copyright-page"] p').filter(function () {
    return notice_regex.test($(this).text())
  });

  if (notice.length > 0) {
    notice.remove();
  };

  //Add our own bulk purchase blurb
  var new_notice = '<p class="CopyrightTextdoublespacecrtxd">Our eBooks may be purchased in bulk for promotional, educational, or business use. Please contact the Macmillan Corporate and Premium Sales Department at 1-800-221-7945, ext. 5442, or by e-mail at <a href="mailto:MacmillanSpecialMarkets@macmillan.com">MacmillanSpecialMarkets@macmillan.com</a>.</p>';

  $('section[data-type="copyright-page"]').append(new_notice);

  // remove halftitle page sections
  $('section[data-type="halftitlepage"]').remove();

  // add chap numbers to chap titles if specified
  $("h1[data-labeltext]").each(function () {
    var labeltext = $(this).attr('data-labeltext');
    if (labeltext.trim()) {
      $(this).prepend(labeltext + ": "); 
    };   
  });

  // remove any reference to printing in the copyright page
  // and insert the correct copyright symbol on copyright page
  $("section[data-type='copyright-page'] p").each(function () {
    var myHTML = $( this ).html().replace(/Printed in [a-zA-Z\s]+\./g, '').replace(/([C|c]opyright)(\s|&.*?;)+/g, '$1 &#169; ');
    $(this).empty();
    $(this).append(myHTML);
  });

  // replace heading text if there is only one chapter;
  // removing this for now, leaving it to users to add this heading text for single-chapter books
  //$("section[data-type='chapter']:only-of-type > h1.ChapTitleNonprintingctnp").contents().replaceWith("Begin Reading");

  // create hyperlinks from EBKLink paragraphs;
  // keep this before the link destinations function
  $(".EBKLinkSourceLa").each(function () {
    var mySibling = $(this).next(".EBKLinkDestinationLb");
    var myHref = mySibling.text();
    var newLink = $("<a></a>").attr("href", myHref);
    $(this).contents().wrap(newLink);
    mySibling.remove();
  });

  // fix link destinations
  $("a").each(function () {
    var linkdest = $(this).attr("href");
    var mypattern1 = new RegExp( "https?://", "g");
    var result1 = mypattern1.test(linkdest);
    var mypattern2 = new RegExp( "^mailto:", "g");
    var result2 = mypattern2.test(linkdest);
    if (result1 === false && result2 == false) {
      linkdest = "http://" + linkdest;
    }
    $(this).attr("href", linkdest);
  });

  // convert small caps text to uppercase
  $("span.spansmallcapscharacterssc, span.spansmcapboldscbold, span.spansmcapitalscital, span.spansmcapbolditalscbi").each(function () {
    var text = $( this ).text();
    text = text.toUpperCase();
    console.log(text);
    $(this).empty();
    $(this).prepend(text); 
  });

  // replace content in spacebreak paras
  $("p[class^='SpaceBreak']:not(.SpaceBreak-Internalint)").empty().append("* * *");

  // remove links from illustration sources
  $("p.IllustrationSourceis a.fig-link").each(function () {
    var myContents = $(this).contents();
    $(this).parent().append(myContents);
    $(this).remove();
  });

  // remove classes from span elements
  $("em.spanitaliccharactersital").removeClass().removeAttr( "class" );

  // remove forced breaks
  $("br:empty").remove();

  // remove textual toc for epub
  $('section.texttoc').remove();

  // remove print-only sections
  $('*[data-format="print"]').remove();

  // suppress toc entries for certain sections
  $('div[data-type="part"] + section[data-type="chapter"]:has(h1.ChapTitleNonprintingctnp) + *:not(section[data-type="chapter"])').prev().addClass("notoc");

  var output = $.html();
	  fs.writeFile(file, output, function(err) {
	    if(err) {
	        return console.log(err);
	    }

	    console.log("Content has been updated!");
	});
});