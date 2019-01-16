from sys import argv

docxfile = argv[1]
custom_doc_property_name = 'Version'
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
	template_version=''

	for child in root:
		if child.attrib['name'] == custom_doc_property_name:
			template_version = child[0].text

	if not template_version:
		template_version = ''

	return template_version


xmlstring = read_xml_in_docx(docxfile, xmlfile)

if not xmlstring:
	template_version = ''
else:
	template_version = check_xml_for_version(xmlstring, custom_doc_property_name)

# pass value back to parent script
print template_version
