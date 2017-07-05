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

  // add missing class names to inline tags that were converted from direct formatting
  $("strong:not(.spanboldfacecharactersbf)").addClass("spanboldfacecharactersbf");
  $("em:not(.spanitaliccharactersital)").addClass("spanitaliccharactersital");

  // merge contiguous small caps char styles
  $("p[class^='ChapOpeningText']").each(function (i) {
   $(this).children("span.spansmallcapscharacterssc").each(function () {
        var that = this.previousSibling;
        var testing = $(that).hasClass('spansmallcapscharacterssc');
        if ((that && that.nodeType === 1 && that.tagName === this.tagName && typeof $(that).attr('class') !== 'undefined' && $(that).hasClass('spansmallcapscharacterssc') === true) || (!that)) {
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
  $("p[class^='CopyrightText']:not(:has(a.spanISBNisbn))").each(function () {
      var mypattern1 = new RegExp( "978(\\D?\\d?){10}", "g");
      var result1 = mypattern1.test($( this ).text());
  console.log(result1);
      if ( result1 === true ) {
        var newtext = $( this ).text().replace(/(978(\D?\d?){10})/g, '<span class="spanISBNisbn">$1</span>');
        $(this).empty();
        $(this).prepend(newtext);
      }
    });

  // tag page placeholders as design notes
  $('section h1[class*="Nonprinting"] + p:last-child').each( function () {
    var mytext = $(this).text().trim();
    var mypattern = new RegExp( "^\[[i|I|v|V|x|X|0-9]+\]$", "g");
    var result = mypattern.test(mytext);
    if (result === true) {
      $(this).removeClass().addClass("DesignNotedn");
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
  $('.DesignNotedn').remove();

  // remove empty section
  $('section h1[class*="Nonprinting"]:only-child').parent().remove();

  // move non-ISBN text out of isbn spans
  $("span[class='spanISBNisbn']").each(function (){
    var span_txt = $(this).text();
    var myRegexp = /(\D*)(978(\D?\d){10})(.*)/;
    var match = myRegexp.exec(span_txt);
    $(this).text(match[2]);
    $(this).before(match[1]);
    $(this).after(match[4]);
  });

  // // turn links into real hyperlinks
  // $("span.spanhyperlinkurl:not(:has(a))").each(function () {
  //   var newlink = "<a href='" + $(this).text() + "'>" + $(this).text() + "</a>";
  //   var mypattern1 = new RegExp( "https?://", "g");
  //   var result1 = mypattern1.test($(this).text());
  //   var mypattern2 = new RegExp( "^@", "g");
  //   var result2 = mypattern2.test($(this).text());
  //   var mypattern3 = new RegExp( ".@.", "g");
  //   var result3 = mypattern3.test($(this).text());
  //   if (result1 === false && result2 === false && result3 === false) {
  //     newlink = newlink.replace("href='", "href='http://");
  //   }
  //   if (result1 === false && result2 === true) {
  //     newlink = newlink.replace("href='@", "href='https://twitter.com/");
  //   }
  //   if (result2 === false && result3 === true) {
  //     newlink = newlink.replace("href='", "href='mailto:");
  //   }
  //   $(this).empty();
  //   $(this).prepend(newlink); 
  // });

  function replaceHyphenatedStrings() {
    // Next we'll add some special handling for 
    // long strings connected by hyphens.
    // Note that is the link replacements from the function above
    // do not occur before this function, then hyphens within link 
    // text WILL NOT be spaced. (However, link href attributes will
    // always be left alone.)

    // First we need to set a counter and create an empty hash to work with.
    var counter = 1;  
    var hashReplacements = {};

    // Now we'll loop through every non-ISBN paragraph
    $('p:contains("-"):not(:has(span.spanISBNisbn))').each(function (){
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
        $(this).find("*:not(.spanhyperlinkurl)").each(function () {
          $(this).html( $(this).html().replace(/-/g,"<span style='font-size: 2pt;'> </span>-<span style='font-size: 2pt;'> </span>") );
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
                var newString = patternMatches[i].replace(/-/g, "<span style='font-size: 2pt;'> </span>-<span style='font-size: 2pt;'> </span>")
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
      var value = hashReplacements[key]
      var selection = value[0];
      var searchString = value[1];
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
