# Internal Extensions to Macmillan's Bookmaker Toolchain

This repository houses the internal extensions to [Macmillan's Bookmaker toolchain](https://github.com/macmillanpublishers/bookmaker). These extensions were written to meet Macmillan's unique content conversion needs, and thus should not be incorporated into the universal conversion process.

The extensions are split into pre- and post-processing steps for each step of the Bookmaker toolchain.

## Extra Content Conversions

### epubmaker_preprocessing

Ruby:

* Adjust img src to point to the main EPUB OEBPS directory
* Remove the link that gets wrapped around any illustration source paragraphs
* For books with only one chapter, rename the chapter to "Begin Reading" (per ebooks group SOP)
* Replace all spacebreak paragraph contents with three asterisks
* Merge contiguous spanhyperlinkurl spans
* ADDONS: Insert any addons specified in bookmaker_assets/addons.json
* ADDONS: Replace addon placeholder text with book metadata
* ADDONS: If an author record is found in the Data Warehouse, uncomment the author newsletter links (if no author record is found, the links will be broken and should therefore stay commented)
* ADDONS - MINI-TOC: If book has multiple authors, pluralize "About the Author" link
* ADDONS - MINI-TOC: If book has multiple authors, add newsletter signup links for each author
* COPYRIGHT PAGE: Adjust copyright page content: "ISBN: 9781234567890 (e-book) => eISBN: 9781234567890", "Printed in the United States of America => (null)", "(print run counter, e.g., 10 9 8 7 6 5 4 3 2) => (null)"
* COPYRIGHT PAGE: Fix copyright symbol
* COPYRIGHT PAGE: Insert mailto: links around email addresses
* TITLEPAGE: If EPUB titlepage image is found, add data-titlepage="yes" attribute to section
* ABOUT THE AUTHOR: Move to end of book (per ebooks group SOP)
* BACK-OF-BOOK AD: Move to end of book (per ebooks group SOP)
* AD CARD: Move to end of book (per ebooks group SOP)
* FRONT SALES: Move to end of book (per ebooks group SOP)
* TOC: Move to end of book (per ebooks group SOP)
* COPYRIGHT PAGE: Move to end of book (per ebooks group SOP)

JavaScript:

* Replaces titlepage content with a titlepage image, if one was submitted
* If no titlepage image was submitted, then replaces the titlepage logo placeholder with an inline image tag
* Adds extra required sales info to the copyright page
* Removes any half-titlepages
* If chapter headings should be numbered, adds the chapter numbers based on the value of the data-label attribute
* Turns any spanhyperlinkurl spans into live hyperlinks (link destination will match the span text)
* Converts small caps spans to real all-caps characters in the HTML (this is necessary because some ereaders don't support text-transform in CSS)
* Removes the class attribute from em tags
* Removes any manually-inserted toc sections
* Removes any content tagged as "print-only" ([data-format="print"])
* Suppress TOC entries for chapters that are the only children of a parent part section
