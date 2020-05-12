from sys import argv

docxfile = argv[1]
custom_doc_property_name = argv[2]
xmlfile = 'docProps/custom.xml'

import os
import zipfile
import shutil
import xml.etree.ElementTree as ET


def read_xml_in_docx(docx, xmlfile):
    document = zipfile.ZipFile(docx, 'a')
    docxfiles = document.namelist()

    if xmlfile in docxfiles:
    	xmlstring = document.read(xmlfile)
    else:
    	xmlstring = ''

    return xmlstring


def check_xml_for_version(xmlstring, custom_doc_property_name):
	root = ET.fromstring(xmlstring)
	custom_doc_prop_value=''

	for child in root:
		if child.attrib['name'] == custom_doc_property_name:
			custom_doc_prop_value = child[0].text

	if not custom_doc_prop_value:
		custom_doc_prop_value = ''

	return custom_doc_prop_value


xmlstring = read_xml_in_docx(docxfile, xmlfile)

if not xmlstring:
	custom_doc_prop_value = ''
else:
	custom_doc_prop_value = check_xml_for_version(xmlstring, custom_doc_property_name)

# pass value back to parent script
print custom_doc_prop_value
