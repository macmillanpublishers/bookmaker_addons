var fs = require('fs');
var cheerio = require('cheerio');
var file = process.argv[2];
var booktitle = process.argv[3];
var bookauthor = process.argv[4];
var pisbn = process.argv[5];
var imprint = process.argv[6];
var publisher = process.argv[7];
var jsdom = require('jsdom');

var document = ''//jsdom.jsdom(src);

fs.readFile(file, function editContent (err, contents) {
  const {JSDOM} = jsdom;
  const {document} = (new JSDOM(contents.toString())).window;
  $ = cheerio.load(contents, {
          xmlMode: true
        });

// add titlepage image if applicable
  if ($('section[data-titlepage="yes"]').length) {
    //remove content
    $('section[data-type="titlepage"]').empty();
    //add image holder
    image = '<figure class="Illustrationholderill fullpage"><img src="images/titlepage_fullpage.jpg"/></figure>';
    $('section[data-type="titlepage"]').append(image);
  }

  // add metadata for runheads
  var metabooktitle = '<meta name="title" content="' + booktitle + '"/>';
  var metabookauthor = '<meta name="author" content="' + bookauthor + '"/>';
  var metapisbn = '<meta name="isbn-13" content="' + pisbn + '"/>';
  var metaimprint = '<meta name="imprint" content="' + imprint + '"/>';
  var metapublisher = '<meta name="publisher" content="' + publisher + '"/>';

  $('head').append(metabooktitle);
  $('head').append(metabookauthor);
  $('head').append(metapisbn);
  $('head').append(metaimprint);
  $('head').append(metapublisher);

  // add figure fullpage class as needed
  $('img[src*="fullpage"]').parent().addClass( "fullpage" );

  // remove ebook-only sections
  $('*[data-format="ebook"]').remove();

  var output = $.html();
    fs.writeFile(file, output, function(err) {
      if(err) {
          return console.log(err);
      }

      console.log("Content has been updated! (cheerio)");
  });


  // scan the paragraphs for text containing hyphenated phrases
  var ps = document.getElementsByTagName("p");
  var ts = [];

  for (var i = 0; i < ps.length; ++i) {
      var p = ps[i];
      checkText(p, ts);
  }

  function checkText(e, ts) {
      for (var c = e.firstChild; c; c = c.nextSibling) {
          if (c.nodeType == 1 && c.className != 'spanISBNisbn') {  // 1: Node.ELEMENT_NODE
              // recurse down through inline elements
              checkText(c, ts);
          } else if (c.nodeType == 3) {   //3:  Node.TEXT_NODE
              // the regular expression needs to be extended for non-Latin
              // scripts, also \w does not match accented characters
              if (c.data.match(/\w-\w/)) {
                  ts.push(c);
              }
          }
      }
  }

  for (var i = 0; i < ts.length; ++i) {
      var t = ts[i];
      // repeats as text node can contain multiple phrases
      while (t) {
          // match entire phrase from beginning to end
          var re = /(-)(\b\w{4,6})|(\w{4,6}\b)(?=-)/;
          var result = re.exec(t.data);

          if (result == null || /\bISBN\b/.test(result[0])) break;
          // beginning of phrase
          firstindex = result.index
          // end of phrase (relative)
          lastindex = result[0].length

          // split phrase
          var t2=t.splitText(firstindex);
          if (lastindex > 0) {
              t = t2.splitText(lastindex);
          } else {
              t = null;
          }

          // wrap the phrase in a span element
          var span = document.createElement("span");
          t2.parentNode.insertBefore(span, t2);
          span.appendChild(t2);
          span.className = "prevent_hyphen";
          // console.log("hyphenated phrase: "+t2.data);
      }
  }
    var output = document.documentElement.outerHTML;
  fs.writeFile(file, output, function(err) {
    if(err) {
        return console.log(err);
    }

    console.log("Content has been updated! (jsdom)");
});

});
