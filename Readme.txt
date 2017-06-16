Recent Document Tracker (RDT) Implements an improved implementation to Windows  
Jumplists by tracking recent documents and folders, then by using document 
type icons in the taskbar tray you can pop-up a menu of recent documents 
sorted by last access time (like Jumplists) with the abilitly to search/filter.
Selecting a menu choice will launch the appropriate program on the file.  

Windows Vista and before had a Recent Documents feature, however I never 
found it that useful as is.  RDT monitors the shortcuts created by the 
Recent Document feature in all of the windows versions and puts it to 
better use.  

You may also launch a searchable filter box to find all documents in the 
history by right mouse button clicking on an RDT tray icon.  Enter text 
into the search box to quickly filter the files displayed (wildcards are 
allowable).  Clicking on a file will launch it with its default program, 
and with the search results the right mouse button over a file to 1) 
exclude it from showing again, 2) pin/unpin it to the menu, 3) launch the 
folder it is contained in.  There are other options available from the
search tree right mouse button.

If you are someone who likes to clear their recent documents regularly, 
then this app is probably not for you.  However if you are someone that 
works with dozens of different office files daily and has a hard time 
remembering where they are, and what you worked on last week then this app 
is perfect.  

Currently extensions are setup with MS Word, Excel, Project, Powerpoint, 
Access, Publisher, Adobe Acrobat and general folders.  You can define new 
icons and associated sets of file extensions using RDT.  To use RDT just run 
the program and icons for the above applications will appear in the system 
tray.  The first time it is used may take a few seconds to a minute 
to scan and verify the recent document shortcuts.  Subsequent runs will be 
much faster.  Left mouse button will pop-up a history of each type 
separated by those in the last day, week and month.  Selecting one will 
launch the document/folder.  Right mouse button to adjust options such as 
hiding certain types (must restart), resetting database, setting limits to 
how many are shown and removing dead shortcuts when document no longer 
exists.  

There are number of settings to control behavior and you can customize
what icons are shown in the tray and the file types associated with them
via the Manage Tray Icons gui. You can now have the same file extension
shown for multiple icons (such as one for MS Word and one for MS Office)

Options to background trim the database either by stale entries or the age 
of the entries is included. You can also clear out the icon cache if needed. 

A feature that binds the Control-Space bar to toggle the topmost capability
of any window ias also available. The window will flash when set on or off.

Portable version of the file are included in the 
downloads section (along with the source code).  If you option to 

Just unzip the portable version into some folder (such as C:\Apps\RDT) and
run the rdt.exe file from there. It will take you through the setup.

permanently remove RDT then also remove the AppData\local\RDT folder within your 
windows user folder.  The AppData\local\RDT folder contains the personalized settings.  

There is a full distribution also available to allow you to make changes 
on your own and optionally build an executable file (using starkit).  See 
the Buildrdt.bat batch file in the output subfolder in the distribution.  
Just make your changes and launch it to rewrap everything together.  

RDT Takes advantage of threading and some features in Tcl/TK 8.6 so those 
are the minimum requirements for the Tcl/Tk engine.

The RDT Tool wouldn't be possible without the following tools and the many 
generous open source contributors: 

    * Tcl/Tk http://www.tcl.tk/software/tcltk/
    * Tclkit + Metakit Engine - http://www.patthoyts.tk/tclkit/ & http://www.equi4.com/tclkit/
    * twapi Tcl library http://twapi.magicsplat.com/ - Ashok P. Nadkarni
    * Shellicon extension - http://www2.tcl.tk/17859 - Mark Janssen


enjoy

tom.wilkason@cox.net
