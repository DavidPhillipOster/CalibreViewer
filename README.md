# CalibreViewer

CalibreViewer is a macOS and an iOS program for viewing the [Calibre](https://calibre-ebook.com) ebook management metadata file.

Calibre is © KOVID GOYAL

fmdb - an Objective-C wrapper for sqlite is https://github.com/ccgus/fmdb by Gus Mueller of Flying Meat

## To Build:

* Open the Xcode project and in the Info panel of the Evaluate target change the `com.example` prefix of the bundle Identifier from `com.example.${PRODUCT_NAME:rfc1034identifier}`  to a domain you control.

* Adjust how the code is signed by selecting the project in Xcode's file navigator, then the target, then in Xcode's Signing&Capabilities panel.

## To Use:
The Mac version uses a cached copy of the Calibre metadata.db file and while you are interacting with that it tries to
update the cache from the master copy. as you type in the search box, it takes space separated "words" and
matches showing you all items that have every "words" in the search string. When you double-click on an item it
sends an appleEvent to the Finder to tell it to open the folder containing the book.

The iOS version could show a share-sheet to let you copy the book to another app, but this version currently does
not do that.

## License
Apache 2.
