# Internal Extensions to Macmillan's Bookmaker Toolchain

This repository houses the internal extensions to [Macmillan's Bookmaker toolchain](https://github.com/macmillanpublishers/bookmaker). These extensions were written to meet Macmillan's unique content conversion needs, and thus should not be incorporated into the universal conversion process.

The extensions are split into pre- and post-processing steps for each step of the Bookmaker toolchain.

## What These Scripts Do

### epubmaker_preprocessing

* Converts small caps spans to real all-caps characters in the HTML (this is necessary because some ereaders don't support text-transform in CSS)