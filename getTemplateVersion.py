from sys import argv

xmlfile = argv[1]
custom_doc_property_name = 'Version'

import xml.etree.ElementTree as ET

def check_xml_for_version(xmlfile, custom_doc_property_name):
	tree = ET.parse(xmlfile)
	root = tree.getroot()

	template_version=''

	for child in root:
		if child.attrib['name'] == custom_doc_property_name:
			template_version = child[0].text

	if not template_version:
		template_version = 'not_found'

	return template_version

template_version = check_xml_for_version(xmlfile, custom_doc_property_name)

# pass value back to parent script
print template_version
