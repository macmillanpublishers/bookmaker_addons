var fs = require('fs');
var cheerio = require('cheerio');
var endnotetxt_class = process.argv[2];
var endnoteid_prefix = process.argv[3];
var bmfiles = JSON.parse(process.argv[4]);
var allfiles = JSON.parse(process.argv[5]);

//// PART 1
//// go check bm sections for div.endnotetext's, get their id's if present
var endnotetxt_id_array = [];
var notes_file = '';
// cycle through bm files
for (var i = 0; i < bmfiles.length; i++) {
  contents = fs.readFileSync(bmfiles[i]);
  $ = cheerio.load(contents, {
           xmlMode: true
         });
  // add any found div's id's to an array
  var endnotetext_els = $("div." + endnotetxt_class);
  if (endnotetext_els.length > 0) {
    endnotetext_els.each(function(){
        endnotetxt_id_array.push($(this).attr("id"));
    });
    // capture the filepath where you found notes and stop checking files
    notes_file = bmfiles[i];
    break;
  }
}
  // console.log(endnotetxt_id_array, notes_file) // < for debug

// Parts 2 & 3: if we found stuff above, look for refs and create links
if (endnotetxt_id_array.length > 0) {

  // create an array of expected endnote ref id's based on endnotetexts array
  var endnoteref_ids = endnotetxt_id_array.map(function(x){
    return endnoteid_prefix + '_' + x.split('_').pop()});
  var en_textlink_dict = {};
  var notes_file_basename = notes_file.split('/').pop();

//// PART 2:
//// locate and track refs & link refs to notes file
  // cycle through all html files in OEBPS
  for (var i = 0; i < allfiles.length; i++) {
    var ref_found = false;
    contents = fs.readFileSync(allfiles[i]);
    $ = cheerio.load(contents, {
              xmlMode: true
            });
    // cycle through possible endnote refs per file
    for (let j in endnoteref_ids) {
      var ref_span = $("span#" + endnoteref_ids[j]);
      // if we find this ref in this file,
      if (ref_span.length > 0) {
        // .. create link and wrap enote mark in it,
        var newlink = '<a data-type="noteref" href="' + notes_file_basename + '#' + endnotetxt_id_array[j] + '"/>';
        ref_span.each(function() {
          $(this).contents().wrap(newlink);
        });
        // .. add to a hash for creating reverse links later,
        filebasename = allfiles[i].split('/').pop();
        en_textlink_dict[endnotetxt_id_array[j]] = filebasename + "#" + endnoteref_ids[j];
        // .. and flag edited html to be written-out to fs
        ref_found = true;
      }
    }
    // write changes back to file as needed
    if (ref_found == true) {
      var output = $.html();
      fs.writeFileSync(allfiles[i], output);
      // console.log("added endnote ref links to " + allfiles[i]); // < debug
    }
  }
  // console.log(en_textlink_dict) // < for debug

//// PART 3:
//// link notes file text items back to refs
  contents = fs.readFileSync(notes_file);
  $ = cheerio.load(contents, {
          xmlMode: true
        });
  // iterate through keys of our dict, looking for ref-spans per div.endnotetxt
  for(entxt_id in en_textlink_dict) {
    var target_span = $("div#"+ entxt_id +" p:first-of-type span.EndnoteReference");
    // if we find the span.ref related to the id, we add a link, with link text of the id #
    if (target_span.length > 0) {
      reftext = entxt_id.split('_').pop();
      var newlink = '<a href="' + en_textlink_dict[entxt_id] + '">' + reftext + '</a>';
      target_span.append(newlink);
    }
  }
  // write edited html back out to file
  var output = $.html();
  fs.writeFileSync(notes_file, output);

  console.log(endnotetxt_id_array.length + " endnotes found, links added");
} else {
  console.log("No endnotes found to link");
}
