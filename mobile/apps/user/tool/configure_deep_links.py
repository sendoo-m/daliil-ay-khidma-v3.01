#!/usr/bin/env python3
"""Configure the daliil:// URL scheme after `flutter create`."""

import plistlib
import xml.etree.ElementTree as ET
from pathlib import Path


ANDROID = 'http://schemas.android.com/apk/res/android'
ET.register_namespace('android', ANDROID)

manifest_path = Path('android/app/src/main/AndroidManifest.xml')
if manifest_path.exists():
    tree = ET.parse(manifest_path)
    root = tree.getroot()
    permission_name = f'{{{ANDROID}}}name'
    permissions = {
        item.get(permission_name) for item in root.findall('uses-permission')
    }
    for permission in (
        'android.permission.ACCESS_FINE_LOCATION',
        'android.permission.ACCESS_COARSE_LOCATION',
    ):
        if permission not in permissions:
            root.insert(0, ET.Element('uses-permission', {permission_name: permission}))
    activity = tree.find('.//activity')
    if activity is not None and not any(
        item.find(f"data[@{{{ANDROID}}}scheme='daliil']") is not None
        for item in activity.findall('intent-filter')
    ):
        intent_filter = ET.SubElement(activity, 'intent-filter')
        ET.SubElement(
            intent_filter,
            'action',
            {f'{{{ANDROID}}}name': 'android.intent.action.VIEW'},
        )
        ET.SubElement(
            intent_filter,
            'category',
            {f'{{{ANDROID}}}name': 'android.intent.category.DEFAULT'},
        )
        ET.SubElement(
            intent_filter,
            'category',
            {f'{{{ANDROID}}}name': 'android.intent.category.BROWSABLE'},
        )
        ET.SubElement(
            intent_filter,
            'data',
            {
                f'{{{ANDROID}}}scheme': 'daliil',
                f'{{{ANDROID}}}host': 'reset-password',
            },
        )
        tree.write(manifest_path, encoding='utf-8', xml_declaration=True)

plist_path = Path('ios/Runner/Info.plist')
if plist_path.exists():
    with plist_path.open('rb') as source:
        plist = plistlib.load(source)
    url_types = plist.setdefault('CFBundleURLTypes', [])
    plist.setdefault(
        'NSLocationWhenInUseUsageDescription',
        'نستخدم موقعك فقط لعرض الأنشطة القريبة منك.',
    )
    if not any('daliil' in item.get('CFBundleURLSchemes', []) for item in url_types):
        url_types.append(
            {
                'CFBundleURLName': 'com.daliilaykhidma.dalilApp',
                'CFBundleURLSchemes': ['daliil'],
            }
        )
    with plist_path.open('wb') as destination:
        plistlib.dump(plist, destination, sort_keys=False)
