from sys import argv
from lxml import etree
from StringIO import StringIO

docxfile = argv[1]
symbolchar = argv[2]
xmlfile = 'word/document.xml'

import os
import zipfile
import shutil
import json
import sys

# read document.xml in as string
def read_xml_in_docx(docx, xmlfile):
    document = zipfile.ZipFile(docx, 'a')
    docxfiles = document.namelist()

    if xmlfile in docxfiles:
    	xmlstring = document.read(xmlfile)
    else:
    	xmlstring = ''

    return xmlstring

# parse document.xml, return strings surrounding symbol
def check_xml_for_version(xmlstring, symbolchar):
	tree = etree.parse(StringIO(xmlstring))
	root = tree.getroot()
	wnamespace = 'http://schemas.openxmlformats.org/wordprocessingml/2006/main'
	namespaces = {'w': wnamespace}
	symbolstring_dict = {}

	# select all instances of the symbol
	symbolstring = ".//*w:sym[@w:char='%s']" % symbolchar
	for child in root.findall(symbolstring, namespaces):

		# get all text before symbol in paragraph
		beforetest = True
		beforestring = ""
		beforeelement = child.getparent().getprevious()
		while beforetest == True:
			# test to see if beforeelement exists, exit loop if not
			try:
				len(beforeelement.tag)
			except:	
				beforetest = False

			if beforetest == True:
				# exit loop if beforeelement is paragraph opener (w:pPr)
				if beforeelement.tag == "{%s}pPr" % wnamespace:
					beforetest = False
				# if beforeelement is a 'run (w:r)', prepend all text from run to beforestring
				elif beforeelement.tag == "{%s}r" % wnamespace:
					beforestring = ("".join([x for x in beforeelement.itertext()]) + beforestring)
				# increment beforeelement
				beforeelement = beforeelement.getprevious()	

		# get all text after the symbol in paragraph
		aftertest = True
		afterstring = ""
		afterelement = child.getparent().getnext()
		while aftertest == True:
			# test to see if afterelement exists, exit loop if not
			try:
				len(afterelement.tag)
			except:	
				aftertest = False

			if aftertest == True:
				# exit loop if afterelement is paragraph opener (w:pPr)				
				if afterelement.tag == "{%s}pPr" % wnamespace:
					aftertest = False
				# if afterelement is a 'run (w:r)', append all text from run to afterstring					
				elif afterelement.tag == "{%s}r" % wnamespace:
					afterstring = afterstring + "".join([x for x in afterelement.itertext()])
				# increment afterelement	
				afterelement = afterelement.getnext()

		# add strings to dictionary as a pair
		symbolstring_dict[beforestring] = afterstring

	return symbolstring_dict
	

# read document.xml in as string
xmlstring = read_xml_in_docx(docxfile, xmlfile)

if not xmlstring:
	symbolstring_dict = {}
else:	
	symbolstring_dict = check_xml_for_version(xmlstring, symbolchar)

# return symbolstring_dict as json
json.dump(symbolstring_dict, sys.stdout)