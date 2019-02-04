var fs = require('fs');
var cheerio = require('cheerio');
var file = process.argv[2];
var doctemplatetype = process.argv[3];

fs.readFile(file, function editContent (err, contents) {
  $ = cheerio.load(contents, {
          xmlMode: true
        });

  //vars for target styles based on doctemplatetype
  if (doctemplatetype == 'rsuite') {
    ital_cs = "itali"
    hyperlink_cs = "Hyperlink";
    smallcaps_cs = "smallcapssc";
    smallcapsbold_cs = "smallcaps-boldscb";
    smallcapsital_cs = "smallcaps-italsci";
    smallcapsboldital_cs = "smallcaps-bold-italscbi";
    illus_source_style = "Credit-LineCrd"
    copyrightblurb_style = "Body-TextTx"
    logo_selector = '[section[data-type="titlepage"] p.Logo-PlacementLogo';
    // add extra paragraph to copyright page
    var newseparator_para = '<p class="SeparatorSep">Separator</p>';
    $('section[data-type="copyright-page"] p:last-child').append(newseparator_para);
    // replace content in spacebreak paras
    $("p.Blank-Space-BreakBsbrk, p.Ornamental-Space-BreakOsbrk").empty().append("* * *");
  } else {
    ital_cs = "spanitaliccharactersital"
    hyperlink_cs = "spanhyperlinkurl";
    smallcaps_cs = "spansmallcapscharacterssc";
    smallcapsbold_cs = "spansmcapboldscbold";
    smallcapsital_cs = "spansmcapitalscital";
    smallcapsboldital_cs = "spansmcapbolditalscbi";
    illus_source_style = "IllustrationSourceis"
    copyrightblurb_style = "CopyrightTextdoublespacecrtxd"
    logo_selector = "p.TitlepageLogologo";
    // add extra paragraph to copyright page
    $('section[data-type="copyright-page"] p:last-child').removeClass( "CopyrightTextsinglespacecrtx" ).addClass( "CopyrightTextdoublespacecrtxd" );
    // replace content in spacebreak paras
    $("p[class^='SpaceBreak']:not(.SpaceBreak-Internalint)").empty().append("* * *");
  }

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
  $(logo_selector).empty().prepend(logo);

  // remove existing bulk order notice from copyright page
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
  var new_notice = '<p class="' + copyrightblurb_style + '">Our eBooks may be purchased in bulk for promotional, educational, or business use. Please contact the Macmillan Corporate and Premium Sales Department at 1-800-221-7945, ext. 5442, or by e-mail at <a href="mailto:MacmillanSpecialMarkets@macmillan.com">MacmillanSpecialMarkets@macmillan.com</a>.</p>';

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

  // turn links into real hyperlinks
  $("span." + hyperlink_cs + ":not(:has(a))").each(function () {
    var newlink = "<a href='" + $(this).text() + "'>" + $(this).text() + "</a>";
    var mypattern1 = new RegExp( "https?://", "g");
    var result1 = mypattern1.test($(this).text());
    var mypattern2 = new RegExp( "^@", "g");
    var result2 = mypattern2.test($(this).text());
    var mypattern3 = new RegExp( ".@.", "g");
    var result3 = mypattern3.test($(this).text());
    if (result1 === false && result2 === false && result3 === false) {
      newlink = newlink.replace("href='", "href='http://");
    }
    if (result1 === false && result2 === true) {
      newlink = newlink.replace("href='@", "href='https://twitter.com/");
    }
    if (result2 === false && result3 === true) {
      newlink = newlink.replace("href='", "href='mailto:");
    }
    $(this).empty();
    $(this).prepend(newlink);
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
  $("span." + smallcaps_cs + ", span." + smallcapsbold_cs + ", span." + smallcapsital_cs + ", span." + smallcapsboldital_cs).each(function () {
    var text = $( this ).text();
    text = text.toUpperCase();
    console.log(text);
    $(this).empty();
    $(this).prepend(text);
  });

  // remove links from illustration sources
  $("p." + illus_source_style + " a.fig-link").each(function () {
    var myContents = $(this).contents();
    $(this).parent().append(myContents);
    $(this).remove();
  });

  // remove classes from span elements
  $("em." + ital_cs).removeClass().removeAttr( "class" );

  // remove forced breaks
  $("br:empty").remove();

  // remove textual toc for epub
  $('section.texttoc').remove();

  // remove print-only sections
  $('*[data-format="print"]').remove();

  // suppress toc entries for certain sections
  $('div[data-type="part"] + section[data-type="chapter"]:has(h1.ChapTitleNonprintingctnp) + *:not(section[data-type="chapter"])').prev().addClass("notoc");

  // suppress toc entries for bobad, Section-Excerpt-Chaptersec
  $('section.bobad, section.excerptchapter').addClass("notoc");

  var output = $.html();
	  fs.writeFile(file, output, function(err) {
	    if(err) {
	        return console.log(err);
	    }

	    console.log("Content has been updated!");
	});
});
