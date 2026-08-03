#!/usr/bin/env python3
"""Validate and install Firebase client configuration in generated projects."""

import json
import plistlib
import shutil
from pathlib import Path


ROOT = Path(__file__).resolve().parent.parent
ANDROID_PACKAGE = "com.daliilaykhidma.dalil_app"
IOS_BUNDLE_ID = "com.daliilaykhidma.dalilApp"
PROJECT_ID = "gen-lang-client-0048255023"


def install_android() -> None:
    source = ROOT / "firebase/android/google-services.json"
    payload = json.loads(source.read_text(encoding="utf-8"))
    package = payload["client"][0]["client_info"]["android_client_info"]["package_name"]
    if package != ANDROID_PACKAGE or payload["project_info"]["project_id"] != PROJECT_ID:
        raise SystemExit("Android Firebase configuration does not match this app")

    target = ROOT / "android/app/google-services.json"
    target.parent.mkdir(parents=True, exist_ok=True)
    shutil.copyfile(source, target)

    settings = ROOT / "android/settings.gradle.kts"
    settings_text = settings.read_text(encoding="utf-8")
    plugin = '    id("com.google.gms.google-services") version "4.4.4" apply false\n'
    if "com.google.gms.google-services" not in settings_text:
        marker = '    id("org.jetbrains.kotlin.android")'
        position = settings_text.find(marker)
        if position < 0:
            raise SystemExit("Unable to configure Google Services in settings.gradle.kts")
        line_end = settings_text.find("\n", position) + 1
        settings_text = settings_text[:line_end] + plugin + settings_text[line_end:]
        settings.write_text(settings_text, encoding="utf-8")

    app_gradle = ROOT / "android/app/build.gradle.kts"
    app_text = app_gradle.read_text(encoding="utf-8")
    if "com.google.gms.google-services" not in app_text:
        marker = '    id("dev.flutter.flutter-gradle-plugin")\n'
        if marker not in app_text:
            raise SystemExit("Unable to configure Google Services in app/build.gradle.kts")
        app_gradle.write_text(
            app_text.replace(marker, marker + '    id("com.google.gms.google-services")\n'),
            encoding="utf-8",
        )


def install_ios() -> None:
    source = ROOT / "firebase/ios/GoogleService-Info.plist"
    with source.open("rb") as stream:
        payload = plistlib.load(stream)
    if payload["BUNDLE_ID"] != IOS_BUNDLE_ID or payload["PROJECT_ID"] != PROJECT_ID:
        raise SystemExit("iOS Firebase configuration does not match this app")

    target = ROOT / "ios/Runner/GoogleService-Info.plist"
    target.parent.mkdir(parents=True, exist_ok=True)
    shutil.copyfile(source, target)

    project = ROOT / "ios/Runner.xcodeproj/project.pbxproj"
    project_text = project.read_text(encoding="utf-8")
    if "GoogleService-Info.plist in Resources" not in project_text:
        build_file = (
            "/* Begin PBXBuildFile section */\n"
            "\t\tDA11F1A00000000000000002 /* GoogleService-Info.plist in Resources */ = "
            "{isa = PBXBuildFile; fileRef = DA11F1A00000000000000001 "
            "/* GoogleService-Info.plist */; };\n"
        )
        file_reference = (
            "/* Begin PBXFileReference section */\n"
            "\t\tDA11F1A00000000000000001 /* GoogleService-Info.plist */ = "
            "{isa = PBXFileReference; lastKnownFileType = text.plist.xml; "
            "path = \"GoogleService-Info.plist\"; sourceTree = \"<group>\"; };\n"
        )
        runner_group = (
            "\t\t97C146F01CF9000F007C117D /* Runner */ = {\n"
            "\t\t\tisa = PBXGroup;\n"
            "\t\t\tchildren = (\n"
        )
        resources = (
            "\t\t97C146EC1CF9000F007C117D /* Resources */ = {\n"
            "\t\t\tisa = PBXResourcesBuildPhase;\n"
            "\t\t\tbuildActionMask = 2147483647;\n"
            "\t\t\tfiles = (\n"
        )
        replacements = (
            ("/* Begin PBXBuildFile section */\n", build_file),
            ("/* Begin PBXFileReference section */\n", file_reference),
            (runner_group, runner_group + "\t\t\t\tDA11F1A00000000000000001 /* GoogleService-Info.plist */,\n"),
            (resources, resources + "\t\t\t\tDA11F1A00000000000000002 /* GoogleService-Info.plist in Resources */,\n"),
        )
        for marker, replacement in replacements:
            if marker not in project_text:
                raise SystemExit("Unable to add GoogleService-Info.plist to Xcode project")
            project_text = project_text.replace(marker, replacement, 1)
        project.write_text(project_text, encoding="utf-8")


if __name__ == "__main__":
    generated = False
    if (ROOT / "android").is_dir():
        install_android()
        generated = True
    if (ROOT / "ios").is_dir():
        install_ios()
        generated = True
    if not generated:
        raise SystemExit("Generate an Android or iOS project before configuring Firebase")
    print("Firebase client configuration installed for Android and iOS.")
