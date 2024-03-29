var fs = require('fs');
var cheerio = require('cheerio');
var file = process.argv[2];
var doctemplatetype = process.argv[3];
// var booktitle = process.argv[3];
// var bookauthor = process.argv[4];
// var pisbn = process.argv[5];
// var imprint = process.argv[6];
// var publisher = process.argv[7];


fs.readFile(file, function editContent(err, contents) {
  $ = cheerio.load(contents, {
          xmlMode: true
        });

  //function to replace element, keeping innerHtml & attributes
  function replaceEl (selector, newTag) {
    selector.each(function(){
      var myAttr = $(this).attr();
      var myHtml = $(this).html();
      $(this).replaceWith(function(){
          return $(newTag).html(myHtml).attr(myAttr);
      });
    });
  }

  //vars for target styles based on doctemplatetype
  if (doctemplatetype == 'rsuite') {
    bold_cs = "boldb"
    ital_cs = "itali"
    isbn_cs = "cs-isbnisbn"
    hyperlink_cs = "Hyperlink"
    smallcaps_cs = "smallcapssc"
    designnote_style = "Design-NoteDn"
    chap_opening_selector = "section[data-type='chapter'] > p[class^='Body-Text']:first-of-type"
  } else {
    bold_cs = "spanboldfacecharactersbf"
    ital_cs = "spanitaliccharactersital"
    isbn_cs = "spanISBNisbn"
    hyperlink_cs = "spanhyperlinkurl"
    smallcaps_cs = "spansmallcapscharacterssc"
    designnote_style = "DesignNotedn"
    chap_opening_selector = "p[class^='ChapOpeningText']"
  }

  // add missing class names to inline tags that were converted from direct formatting
  $("strong:not(." + bold_cs + ")").addClass(bold_cs);
  $("em:not(." + ital_cs + ")").addClass(ital_cs);

  // merge contiguous small caps char styles
  //  this class, chapopener \/ does not appear to be in use in any active CSS, so is moot..
  //  leaving in, even though is not apropos for rsuite, as example of selecting/tagging chapopener.
  //  would need to edit this ChapOpeningText selector if we want it to work.
  $(chap_opening_selector).each(function (i) {
   $(this).children("span." + smallcaps_cs).each(function () {
        var that = this.previousSibling;
        var testing = $(that).hasClass(smallcaps_cs);
        if ((that && that.nodeType === 1 && that.tagName === this.tagName && typeof $(that).attr('class') !== 'undefined' && $(that).hasClass(smallcaps_cs) === true) || (!that)) {
          $(this).addClass("chapopener");
        }
      });
    });

  //function to merge all contiguous spans
  $("span:not(.FootnoteText,[data-type='footnote']), em, strong").each(function () {
    var that = this.previousSibling;
    var thisclass = $(this).attr('class');
    var previousclass = $(that).attr('class');
    if ((that && that.nodeType === 1 && that.tagName === this.tagName && typeof $(that).attr('class') !== 'undefined' && thisclass === previousclass)) {
      var mytag = this.tagName.toString();
      var el = $("<" + mytag + "/>").addClass("temp");
      $(this).after(el);
      var node = $(".temp");
      while (that.firstChild) {
          node.append(that.firstChild);
      }
      while (this.firstChild) {
          node.append(this.firstChild);
      }
      $(that).remove();
      $(this).remove();
    }
    $(".temp").addClass(thisclass).removeClass("temp");
  });

  //tag isbns if not tagged already
  $("p[class^='CopyrightText']:not(:has(a." + isbn_cs + "))").each(function () {
      var mypattern1 = new RegExp( "978(\\D?\\d?){10}", "g");
      var result1 = mypattern1.test($( this ).text());
      // console.log(result1);
      if ( result1 === true ) {
        var newtext = $( this ).text().replace(/(978(\D?\d?){10})/g, '<span class="' + isbn_cs + '">$1</span>');
        $(this).empty();
        $(this).prepend(newtext);
      }
    });

  // tag page placeholders as design notes
  //  ^may not really be apropos with RSuite
  $('section h1[class*="Nonprinting"] + p:last-child').each( function () {
    var mytext = $(this).text().trim();
    var mypattern = new RegExp( "^\[[i|I|v|V|x|X|0-9]+\]$", "g");
    var result = mypattern.test(mytext);
    if (result === true) {
      $(this).removeClass().addClass(designnote_style);
    }
  });

  // add any required auto-numbering (e.g. for numbered paragraphs)
  var n = 1;

  $('p.autonumber').each(function () {
    if ($(this).hasClass('liststart')) {
      n = 1;
    };
    var num = n.toString() + ". ";
    $(this).prepend(num);
    n = n+1;
  });

  // remove design notes
  $('.' + designnote_style).remove();

  // remove empty section
  $('section h1[class*="Nonprinting"]:only-child').parent().remove();

  // move non-ISBN text out of isbn spans
  $("span[class='" + isbn_cs + "']").each(function (){
    var span_txt = $(this).text();
    var myRegexp = /(\D*)(978(\D?\d){10})(.*)/;
    var match = myRegexp.exec(span_txt);
    if (match) {
      $(this).text(match[2]);
      $(this).before(match[1]);
      $(this).after(match[4]);
    }
  });

  if (doctemplatetype == 'sectionstart') {
    // remove Section-Blank-Page sections
    $("section.blankpage").remove();
    //// Strip pageBreaks preceding Section starts:
    // catch & remove any page break directly preceding Section Starts (nothing should be outside of a seciton block, but just in case)
    $(".PageBreakpb + section, .PageBreakpb + div").prev().remove();
    // and remove elements with .PageBreakpb class that are are last children of sections or divs that are followed by other sections or divs
    var SectionWithLastChildPageBreak = $("section:has(.PageBreakpb:last-child) + section, section:has(.PageBreakpb:last-child) + div, div:has(.PageBreakpb:last-child) + section, div:has(.PageBreakpb:last-child) + div").prev()
    // we have to do an 'each' loop, otherwise the .last() selector selects only the very last match in the whole document (the loop is not necessary w/ jsbin, may be a cheerio idiosyncrasy)
    SectionWithLastChildPageBreak.each(function() {
      $(this).children().last().remove();
    })

    // Strip content from all PageBreakbp
    $(".PageBreakpb").empty();
  }

  //// The below items were migrated here from bookmaker/htmlmaker/bandaid.js

  // fix fig ids in case of duplication
  $('figure').each(function(){
    var myId = $(this).attr('id');
    if ( myId !== undefined ) {
      var newId = "fig-" + myId;
      $(this).attr('id', newId);
    }
  });

  // remove leading and trailing brackets from image filenames
  $('figure img').each(function(){
    var mySrc = $(this).attr('src');
    var myAlt = $(this).attr('alt');
    var mypattern1 = new RegExp( "^images/\\[", "g");
    var mypattern2 = new RegExp( "\\]$", "g");
    var result1 = mypattern1.test(mySrc);
    var result2 = mypattern2.test(mySrc);
    if ( result1 === true && result2 === true ) {
      mySrc = mySrc.replace("[", "").replace("]", "");
    } else {
      mySrc = mySrc.replace("[", "%5B").replace("]", "%5D");
    }
    $(this).attr('src', mySrc);
    myAlt = myAlt.replace("[", "%5B").replace("]", "%5D");
    $(this).attr('alt', myAlt);
  });

  // fix brackets in urls
  $('a[href]').each(function(){
    var myHref = $(this).attr('href');
    myHref = myHref.replace("[", "%5B").replace("]", "%5D");
    $(this).attr('href', myHref);
  });

  $('span.' + hyperlink_cs + ':not(:has(a))').each(function(){
    var myText = $(this).text();
    myText = myText.replace("[", "%5B").replace("]", "%5D");
    $(this).empty();
    $(this).append(myText);
  });

  function HtmlEncode(s) {
   output = $('<div>').text(s).html();
   return output;
  };

  function replaceHyphenatedStrings() {
    // Next we'll add some special handling for
    // long strings connected by hyphens.
    // Note that if the link replacements from the function above
    // do not occur before this function, then hyphens within link
    // text WILL NOT be spaced. (However, link href attributes will
    // always be left alone.)

    // First we need to set a counter and create an empty hash to work with.
    var counter = 1;
    var hashReplacements = {};

    // Now we'll loop through every non-ISBN paragraph
    $('p:contains("-"):not(:has(span.' + isbn_cs + '))').each(function (){
      var para_txt = $(this).text();
      var myhtml = $(this).html();
      var myID = $(this).attr("id");
      // Check to see if the paragraph contains any long strings
      var testLongString = /((\S+-){4,})/g;
      var result = testLongString.test(para_txt);
      if (result === true) {
        // Make sure the paragraph has an ID
        if (myID === undefined) {
          var newID = function () {
            // Math.random should be unique because of its seeding algorithm.
            // Convert it to base 36 (numbers + letters), and grab the first 9 characters
            // after the decimal.
            return '_' + Math.random().toString(36).substr(2, 9);
          };
          $(this).attr("id", newID);
        }
        // Replace hyphens in any child elements within the para
       $(this).find("*").each(function () {
          // skip children with nested long-hyphen strings in element-tag-nodes; to avoid unintentionally handling attributes
          if ($(this).html().match(/<.*?(\S+-){4,}.*?>/)) {
            console.debug("skipping long-hyphen string element attribute/attr-value (probably an href url)")
          } else {
            $(this).html($(this).html().replace(/-/g,"<span class='longhyphenhelper' style='font-size: 2pt; vertical-align:top;'>&#160;</span>-<span class='longhyphenhelper' style='font-size: 2pt; vertical-align:top;'> </span>"));
          }
        });
        // now remove any instances of those spans that are enclosed in a hyperlinkspan. Have to do this in two steps; previously using a 'not' selector,
        //  but the 'not' was not accounting for nested spans with hyperlink spans at different depths.
        $(this).find("." + hyperlink_cs).each(function () {
           $(this).find(".longhyphenhelper").remove();
        });
        // Now we'll work with the raw top-level text.
        // We want to make sure we aren't accidentally grabbing any child element
        // attributes or other bits that shouldn't be changed.
        var rawtext = $(this).contents().filter(function(){
          return this.nodeType == 3 && this.nodeValue.match(/((\S+-){2,})/);
        });
        if (rawtext.length) {
          // Now we'll loop through the child text and filter for just the hyphenated strings
          rawtext.each(function() {
            var currentString = this.nodeValue;
            // We're matching shorter chunks this time, since a longer string
            // could potentially be split up by a nested inline tag
            var testShortString = /((\S+-\S*){2,})/g;
            var patternMatches = [];
            patternMatches = currentString.match(testShortString);
            var parentid = $(this).parent().attr("id");
            if (patternMatches) {
              for (i = 0; i < patternMatches.length; i++) {
                // For each hyphenated text string we find,
                // we'll add the parent para id, the source string text, and our new markup to a hash.
                var oldString = patternMatches[i];
                // adding the vertical-align, otherwise for some reason the 2pt space disrupts vertical line-spacing.
                var newString = patternMatches[i].replace(/-/g, "<span class='longhyphenhelper' style='font-size: 2pt; vertical-align:top;'>&#160;</span>-<span class='longhyphenhelper' style='font-size: 2pt; vertical-align:top;'> </span>");
                // Wrap the hyphanted strings in a span for future potential targetting
                newString = "<span class='longstring'>" + newString + "</span>";
                hashReplacements[counter] = [];
                hashReplacements[counter].push(parentid);
                hashReplacements[counter].push(oldString);
                hashReplacements[counter].push(newString);
                counter = counter + 1;
              }
            }
          });
        }
      }
    });

    // Now we loop through that hash and do the text replacements
    // by targeting just the paragraph in which the strings occur
    Object.keys(hashReplacements).forEach(function (key) {
      var value = hashReplacements[key];
      var selection = value[0];
      var searchString = HtmlEncode(value[1]);
      var replacementString = value[2];
      var oldHTML = $('p#' + selection).html();
      var newHTML = $('p#' + selection).html().replace(searchString, replacementString);
      $('p#' + selection).html(newHTML);
    });
  };

  replaceHyphenatedStrings();

  var output = $.html();
    fs.writeFile(file, output, function(err) {
      if(err) {
          return console.log(err);
      }

      console.log("Content has been updated!");
  });
});
