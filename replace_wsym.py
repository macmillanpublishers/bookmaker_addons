import sys
import os
import zipfile
from shutil import copyfile
# make sure to install lxml: sudo pip install lxml
from lxml import etree
import traceback

docxfile = sys.argv[1]
charcode = sys.argv[2]
replacement = sys.argv[3]
replacementstring = replacement.decode("utf-8")

# load modules from sectionstart scripts_dir
import imp
zipDOCXpath = os.path.join(sys.path[0],'..','sectionstart_converter','xml_docx_stylechecks','shared_utils','zipDOCX.py')
unzipDOCXpath = os.path.join(sys.path[0],'..','sectionstart_converter','xml_docx_stylechecks','shared_utils','unzipDOCX.py')
os_utilspath = os.path.join(sys.path[0],'..','sectionstart_converter','xml_docx_stylechecks','shared_utils','os_utils.py')
zipDOCX = imp.load_source('zipDOCX', zipDOCXpath)
unzipDOCX = imp.load_source('unzipDOCX', unzipDOCXpath)
os_utils = imp.load_source('os_utils', os_utilspath)

# local vars
doc_xmlfile = 'word/document.xml'
searchstring = ".//w:sym[@w:font='Symbol'][@w:char='%s']" % charcode
# Word namespace vars
wnamespace = 'http://schemas.openxmlformats.org/wordprocessingml/2006/main'
# w14namespace = 'http://schemas.microsoft.com/office/word/2010/wordml'
# vtnamespace = "http://schemas.openxmlformats.org/officeDocument/2006/docPropsVTypes"
# mcnamespace = "http://schemas.openxmlformats.org/markup-compatibility/2006"
# xmlnamespace = "http://www.w3.org/XML/1998/namespace"
# wordnamespaces = {'w': wnamespace, 'w14': w14namespace, 'vt': vtnamespace, 'mc': mcnamespace}


# # # # # # # # # # METHODS

def check_xml_for_wsym(docx, xmlfile, searchstring):
    wsym_check = False
    # read in the dpcument without unzipping
    document = zipfile.ZipFile(docx, 'a')
    docxml_root = etree.fromstring(document.read(xmlfile))
    # scan for symbol in question
    if docxml_root.findall(searchstring, {'w': wnamespace}):
        wsym_check = True
    # print wsym_check  debug
    return wsym_check


def replace_wsym(unzip_dir, doc_xmlfile, searchstring, replace_string):
    # get xml root for queries
    docxml = os.path.join(unzip_dir, doc_xmlfile)
    docxml_tree = etree.parse(docxml)
    docxml_root = docxml_tree.getroot()

    # capture all w:sym instances, set counts
    wsyms = docxml_root.findall(searchstring, {'w': wnamespace})
    wsym_count = len(wsyms)
    wsyms_replaced = 0
    # print "found %s" % wsym_count # debug

    # cycle through and replace w:sym with replacement text
    for sym in wsyms:
        # create a new w:t
        new_text_element = etree.Element("{%s}t" % wnamespace)
        new_text_element.text = replace_string
        # insert new element with replacement text
        sym.addnext(new_text_element)
        # remove w:sym symbol
        sym.getparent().remove(sym)
        wsyms_replaced += 1

    if wsyms_replaced > 0:
        os_utils.writeXMLtoFile(docxml_root, docxml)

    return wsym_count, wsyms_replaced


# # # # # # # # # # RUN
try:
    # check for existence of symbol without unzipping
    wsym_check = check_xml_for_wsym(docxfile, doc_xmlfile, searchstring)

    if wsym_check == True:
        # at least one instance of the symbol exists. Unzip:
        unzip_dir = os.path.join(os.path.dirname(docxfile),"%s_unzipped" % os.path.basename(docxfile))
        unzipDOCX.unzipDOCX(docxfile, unzip_dir)
        # replace symbol in xml, write edited xml out to document.xml
        wsym_count, wsyms_replaced = replace_wsym(unzip_dir, doc_xmlfile, searchstring, replacementstring)
        # make a backup copy of input file
        pre_replacement_docx = os.path.join(os.path.dirname(docxfile),"%s_pre-sym-replacement%s" % (os.path.splitext(docxfile)[0],os.path.splitext(docxfile)[1]))
        if not os.path.exists(pre_replacement_docx):
            copyfile(docxfile, pre_replacement_docx)
        # zip up edited xml & replace input file
        zipDOCX.zipDOCX(unzip_dir, docxfile)
        print "Found {} '{}'(s), replaced {}, with {}".format(wsym_count, charcode, wsyms_replaced, replacement)
    else:
        print "No '%s'(s) found, no replacements made" % charcode

except Exception, e:
    print "error: ", traceback.format_exc()#sys.exc_info(),
