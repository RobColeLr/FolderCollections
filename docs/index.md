---
title: robcole.com - FolderCollections
...

# robcole.com - FolderCollections

Folder Collections - Lightroom Plugin

Makes a set of collections that mirror your folders so you can access in Develop Module.

Featuring:

* **Synchronizes automatically during startup**, and automatically or manually after startup.
* **Stacks in folder collections can match stacks in folders proper** (this feature is deprecated: functionality replaced with a more robust implementation in [Stacker][1])

### System Requirements

* **Lightroom 5 or 4: All features.**
* **Lightroom 3: Stack matching won't work.**
* **Only tested in Windows so far (Lr4 and Lr5), but (except for stack matching) should work on Mac too.**

 

Quick Links (intra-page)

[Background Information][2]  
[Screenshots][3]  
[How to Use][4]  
[Folder Collections FAQ (Frequently Asked Questions)][5]  
[Revision History][6]  
[Download][7]

_**See the readme file after downloading for usage and other notes.**_

 

* * *

### Folder Collections - Screenshots

 

File Menu -> Plugin Extras  
![][8]  
Common functions are accessed via the file menu.

 

Plugin Manager

![][9]

 

 

### Background/Introduction

I got nuthin'...

 

### Definitions (for the purposes of Folder Collections)

 

### How to Use Folder Collections

\- Install (see readme file in downloaded zip file)  
\- [Configure in plugin manager][10]  
\- [File Menu][11]  

 

### Plugin Manager Configuration

See [elare plugin framework][12] for **common settings**.

**Additional Settings and Controls**

| ----- |
| Auto-processing control |  Checked: select folder collections will be kept synchronized to source folders. Unchecked: manual sync would be required. This is recommended - it's more convenient, works well, and requires very few CPU cycles. |  
| Auto-sync collection sets |  Checked: Parental folder collection sets will be kept synchronized to parental source folders. Unchecked: manual sync required if need be. It is not recommended to check this since it can result in lengthy repetitive calculations that are usually not necessary. If you do decide to check this, just be sure not to select top-level folder collections unless it is your intention to have them constantly synchronized - this could be useful, but normally isn't. |  
| Auto-check status |  Status of auto-processing/sync. |  
|   |    |  
| Update Folder Collections |  Updates entire tree of folder collections. |  
| Report |  Compares folders to folder collections and provides info. |  
|   |    | 

### File Menu

Access via Lightroom's menu bar: File Menu -> Plugin Extras

| ----- |
| Sync Selected Sources |  Updates folder collections to mirror corresponding folders. This can be used instead of auto-sync after restructuring folders. Only synchronizes the selected folder collection sources. - to update whole tree, use plugin manager. |  
| Go To Folders |  Convenience function which selects the "real" folders corresponding to selected folder collections, in case you need to use the "real" folders to move physical files around, which can't be done from the folder collections. |  
| Rebuild Stacks | 

*** Deprecated - consider using [Stacker][1] instead.

Will stack photos in folder collections to match corresponding folders. Operates on selected folder collections and/or sets, recursively - unstacks, then restacks.

 |  
| Update Stacks | 

*** Deprecated - consider using [Stacker][1] instead.

Like 'Rebuild Stacks', except ignores pre-existing stacks, thus just picking up new stacks in folders without disturbing existing folder collection stacks.

 | 

 

* * *

 

### Folder Collections FAQ (Frequently Asked Questions)

#### (no particular order)

* * *

These FAQs come partly from users, and partly from my imagination. Please let me know if there are errors or omissions in this FAQ - thanks.

NOTE: The following Q&A's assume that the plugin is working as I expect... If, after your best effort, still "no go", please let me know.

* * *

Question: Why would I ever need or want such a thing as Folder Collections?

Answer: If folders are your primary unit of photo organization, and you spend a lot of time in the Develop Module, folder collections can be a welcome convenience, since you don't have to switch back to Library module just to select a different folder.

* * *

Question: Why would I not want to use Folder Collections?

Answer: If folders are just buckets and your primary unit of organization is collections which you already have set up, then Folder Collections probably won't be of much value to you.

* * *

Question: I deleted a file, but it reappeared...(?)

Answer: It's easy to forget the folder collections are not folders - and the selected folder is usually being automatically sync'd with the true folder. While in folder collection, to permanently delete (from folder collection and true folder), use Ctrl-Shift-Alt-Delete (Windows) or the Mac equivalent.
* * *

Question: What's this [folder] collection?

Answer: Unlike folders, which can include photos or other folders, collection sets can't contain photos. So, instead photos corresponding to parental folders are put into a child collection of the same name as the parent, except with [] around it, to distinguish.

* * *

Question: How do you mirror folder stacks in folder collections?

Answer: Using AutoHotkey in Windows. This has the potential to be problematic. I use this feature regularly, but please let me know if you have problems, OK?

* * *

Question: Any other hot tips I should know about?

Answer: Yes:

* Use Ctrl-Shift-Alt-Delete (Windows) or the Mac equivalent to delete a photo or virtual copy while viewing a folder collection.
* * *

Question: What are the limitations of Folder Collections and what are your plans for the future?

Answer:

* I was hoping to use smart collections so Lightroom would handle auto-updating, but no way to do it given limitation of smart collection criteria. Thus plugin handles auto-updating instead. Since usually people will follow recommendation and not enable auto-sync of parent collection sets, those need to be synchronized manually (or full update), after source folders are restructured.
* Stack mirroring leaves something to be desired (and @2012-06-01, only works on Windows) - it works OK for me (I sometimes have to dismiss one or two Lightroom errors in the course of doing a whole catalog rebuild or update), but is a clunky kluge implemented as such to work around inadequate support for doing it "right".
* There are still some minor but annoying bugs in v2.0.1 I'm trying to work out, having to do with the conversion of a collection to a collection set (e.g. auto-sync, when folders have been added to previously un-foldered folder), and such stuff - do standby...
* * *

 

### Folder Collections Revision History

(reverse chronological order) 

 

**Version 2.2.8 released 2015-01-17**

\- Removed stack functions from file menu (plugin extras) in Mac environment.

 

**Version 2.2.7 released 2014-07-31**

\- Fixed bug: Lr5.6 compatibility fix - critical.

 

**Version 2.2.5 released 2014-06-03**

\- Tried to get it work with Lr mobile folders too, but could not succeed due to a bug in Lightroom - sorry. At least it won't go belly up now (all other folders should work as intended).

 

**********Version 2.2.4 released 2014-05-31**

\- Continuation of fix that will hopefully allow users with photos on unmapped windows network drives (e.g. real network drives or folders created on behalf of Lightroom Mobile which mimick network drives) to use it too - let me know if I'm right (or wrong) - thanks.

 

**Version 2.2.3 released 2014-05-31**

\- Made a fix that will hopefully allow users with photos on unmapped windows network drives to use it too - let me know if I'm right (or wrong) - thanks.

 

**Version 2.2.2 released 2014-03-30**

\- Fixed so if plugin is disabled, it won't initialize (populate + review). The way it was before, ya had to remove the dang thang to de-activate it for testing purposes..

 

**Version 2.2.1 released 2013-09-14**

\- Better error message for case when root drive is being shown as parent in folder pane, which it should not be.

 

**Version 2.2 released 2013-09-13**

\- Fixed bug: Stack mirroring upon startup was only working if Lr started up in grid mode. I wish somebody told me about this bug. It's been there for a long time, but I didn't notice it because I use Stacker for mirroring folder stacks in collections, and so hadn't exercised the Folder Collection stacking feature in a long time. If I don't know about 'em, I can't fix 'em...

\- Also, stack mirroring upon startup is now cancelable with impunity (stacks of course will not all have been built/updated). 

\- Fixed bug whose symptom was error: "type() is nil..." or something to that effect.

 

**Version 2.1.2, released 2013-03-27**

\- Fixed bug: was not working when photos in catalog were in root of drive (as opposed to being in a folder).

******************************Version 2.1.1, released 2013-02-24**

\- Fixed a subtle bug in catalog updating method which may have been responsible for initialization errors, especially when building folder collections for the first time.

**Version 2.1, released 2011-06-04**

\- Fairly extensive changes, mostly targeted at working around bugs in Lightroom/SDK, mostly impact auto-sync when folders have been moved or renamed...

\- Report function scrutinizes much more thoroughly than before, to catch any discrepancy between folders and the folder collections that represent them.

**Version 2.0.1, released 2011-06-01**

\- Added stack mirroring (Windows only at the moment). Note: will not work on systems that don't use English keyboard keystrokes for selecting photos, and stacking/unstacking/collapsing/and grouping stacks, i.e. ctrl-a, alt-p-a-u, alt-p-a-c, and alt-p-a-g, respectively.

**Version 2.0, released 2011-05-31**

\- Added stack mirroring (Windows only at the moment). Note: will not work on systems that don't use English keyboard keystrokes for selecting photos, and stacking/unstacking/collapsing/and grouping stacks, i.e. ctrl-a, alt-p-a-u, alt-p-a-c, and alt-p-a-g, respectively.

**Version 1.2, released 2011-05-29**

\- Automatically performs independent integrity check and validation after re-building and/or updating folder collections.

\- Modified to incorporate enhancements in recently released Lr4.1 SDK.

**Version 1.1.1, released 2011-05-28**

\- Fixed problem when loading plugin into an empty catalog, there was an error message being displayed.

\- Fixed problem when root of catalog folder was not root of drive - symptom was disappearing folder collection upon sync.  

**Version 1.1, released 2011-05-26**

\- Misc enhancements & a few bug fixes, mostly having to do with auto-mirroring.

**Version 1.0, released 2011-05-25**

\- Initial release.
* * *

####  

#### Please (IDENTIFY THE PLUGIN) [let me know what you think][13], and please (IDENTIFY THE PLUGIN) [report bugs][14].

 

### Download

_acceptance of Download Terms & Conditions will be required_

[Folder Collections 2.2.8][15] \- Latest & greatest: this is the one to download.

[Folder Collections 2.2.7][16] \- A previous version, in case of problem with latest.

[1]: https://web.archive.org/web/20150206152934/http%3A/www.robcole.com/Rob/ProductsAndServices/StackerLrPlugin
[2]: https://web.archive.org#background
[3]: https://web.archive.org#screenshots
[4]: https://web.archive.org#howtouse
[5]: https://web.archive.org#faq
[6]: https://web.archive.org#revision_history
[7]: https://web.archive.org#download
[8]: https://web.archive.org/web/20150206152934im_/http%3A/www.robcole.com/Rob/ProductsAndServices/_support/file_menu.gif
[9]: https://web.archive.org/web/20150206152934im_/http%3A/www.robcole.com/Rob/ProductsAndServices/FolderCollectionsLrPlugin/_support/plugin_manager.gif
[10]: https://web.archive.org#config
[11]: https://web.archive.org#file_menu
[12]: https://web.archive.org/web/20150206152934/http%3A/www.robcole.com/Rob/ProductsAndServices/ElarePluginFramework
[13]: https://web.archive.org/web/20150206152934/http%3A/www.robcole.com/Rob/ContactMe
[14]: https://web.archive.org/web/20150206152934/http%3A/www.robcole.com/Rob/ProblemReport
[15]: /web/20150206152934/http://www.robcole.com/Rob/_common/DownloadEasy/Download.cfm?dir=FolderCollectionsLrPlugin&file=rc_FolderCollections_(lrplugin)_2.2.8.zip
[16]: /web/20150206152934/http://www.robcole.com/Rob/_common/DownloadEasy/Download.cfm?dir=FolderCollectionsLrPlugin&file=rc_FolderCollections_(lrplugin)_2.2.7.zip

  