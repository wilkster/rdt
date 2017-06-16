Recent Document Tracker Implements a similar function to Windows 7 
Jumplists by tracking recent documents and folders, then by using document 
type icons in the taskbar tray you can pop-up a menu of recent documents 
sorted by last access time (like Jumplists).  Selecting a menu choice will 
launch the appropriate program on the file.  

You can also launch a searchable filter box to find all documents in the
history. Using the filter box, select the right mouse button over a file/folder
to 1) exclude it from showing again, 2) pin/unpin it to the menu, 
3) launch the folder it is contained in.

Windows vista and before had a Recent Documents feature, however I never 
found it that useful as is.  RDT monitors the shortcuts created by the 
Recent Document feature and puts it to better use.  

If you are someone who likes to clear their recent documents regularly, 
then this app is probably not for you.  However if you are someone that 
works with dozens of different office files daily and has a hard time 
remembering where they are and what you worked on last week then this app 
is perfect.  

Currently works with MS Word, Excel, Project, Powerpoint, Access, 
Publisher, Adobe Acrobat and general folders.  To use it just run the 
program and icons for the above applications will appear in the system 
tray.  The first time it is used may take a few seconds to a few minutes 
to scan and verify the recent document shortcuts.  Subsequent runs will be 
much faster.  Left mouse button will pop-up a history of each type 
separated by those in the last day, week and month.  Selecting one will 
launch the document/folder.  Right mouse button to adjust options such as 
hiding certain types (must restart), resetting database, setting limits to 
how many are shown and removing dead shortcuts when document no longer 
exists.  

to create your own icons, create a 16x16 icon in your color depth (32bpp typical)
- Place the icon in your .rdt folder under your user name
- name the icon like this "type ext1 ext2 ext3.ico"" where you can add as many 
  extensions as necessary. The type is the tag for the icon in the tray.
  Whatever icon you put in the icon file will be displayed in the tray.
  I like IcoFX as an icon editor myself.

The RDT Tool wouldn't be possible (esp since it took only a few hours to 
write) without the following tools and the many generous open source 
contributors: 

    * Tcl/Tk http://www.tcl.tk/software/tcltk/
    * Tclkit + Metakit Engine - http://www.patthoyts.tk/tclkit/ & http://www.equi4.com/tclkit/
    * twapi Tcl library http://twapi.magicsplat.com/
    * winico icon tool http://tktable.sourceforge.net/winico/winico.html 


enjoy

tom.wilkason@cox.net
