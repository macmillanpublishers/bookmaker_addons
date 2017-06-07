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

  // some special handling for paras with long hyphenated phrases
  $('p:contains("-")').each(function (){
    var para_txt = $(this).text();
    var mypattern = /((\S+-){4,})/g;
    var result = mypattern.test(para_txt);
    if (result === true) {
      $(this).addClass('longstring');
    }
  });

  var output = $.html();
    fs.writeFile(file, output, function(err) {
      if(err) {
          return console.log(err);
      }

      console.log("Content has been updated!");
  });
});
