var fs = require('fs');
var cheerio = require('cheerio');
var file = process.argv[2];

fs.readFile(file, function editContent (err, contents) {
  $ = cheerio.load(contents, {
          xmlMode: true
        });

// Add links back to TOC to chapter heads
  $("section[data-type='chapter'] h1").each(function () {
    var newlink = "<a href='toc01.html'>" + $( this ).text() + "</a>";
    $(this).empty();
    $(this).prepend(newlink); 
  });

// Add links back to TOC to appendix heads
  $("section[data-type='appendix'] h1").each(function () {
    var newlink = "<a href='toc01.html'>" + $( this ).text() + "</a>";
    $(this).empty();
    $(this).prepend(newlink); 
  });

// add link back to TOC to preface heads
  $("section.frontsales h1").each(function () {
    var newlink = "<a href='toc01.html'>" + $( this ).text() + "</a>";
    $(this).empty();
    $(this).prepend(newlink); 
  });

// Add links back to TOC to part heads
  $("div[data-type='part'] h1").each(function () {
    var newlink = "<a href='toc01.html'>" + $( this ).text() + "</a>";
    $(this).empty();
    $(this).prepend(newlink); 
  });

/*
skipping html files:  copyright page, dedication,colophons, title page, toc
Y<section data-type="preface" class="" id="d1e449"><h1 class="FMHeadfmh">Author&#x2019;s Note</h1>
Y<section data-type=preface class=""<h1 class="FMHeadfmh">Acknowledgments</h1>
Y<section data-type="preface" class="frontsales" id="d1e28"><h1 class="FrontSalesTitlefst">Praise for Witches of Lychford</h1>
Y<div data-type="part" class="" id="d1e479"><h1 class="PartNumberpn">Part One</h1>
Y<section data-type="preface" class="adcard" id="d1e188"><h1 class="AdCardMainHeadacmh">Also by Paul Cornell</h1>

// add link back to TOC to Acknowledgments, Author's Note
  $("section[data-type='preface'] h1.FMHeadfmh").each(function () {
  //$("section[data-type='preface'] h1:contains(Acknowledgments)").each(function () {   
    var newlink = "<a href='toc01.html'>" + $( this ).text() + "</a>";
    $(this).empty();
    $(this).prepend(newlink); 
  });

// add link back to TOC to frontsales
  $("section.frontsales h1").each(function () {
    var newlink = "<a href='toc01.html'>" + $( this ).text() + "</a>";
    $(this).empty();
    $(this).prepend(newlink); 
  });

// add link back to TOC to adcard head
  $('section.adcard h1').each(function () {
    var newlink = "<a href='toc01.html'>" + $( this ).text() + "</a>";
    $(this).empty();
    $(this).prepend(newlink); 
  });
*/

  var output = $.html();
	  fs.writeFile(file, output, function(err) {
	    if(err) {
	        return console.log(err);
	    }

	    console.log("Content has been updated!");
	});
});