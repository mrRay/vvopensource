\mainpage
vvopensource
============


Introduction
------------

I write software for a living at [Vidvox](www.vidvox.net).  The more I write, the more I find myself using a couple basic classes, or putting together frameworks so I can re-use code.  This project is an ever-growing collection of simple frameworks which I can link against to reuse code I already wrote and make my life easier; hopefully, it makes your life a bit easier too.

All of these frameworks are contained in a single XCode project- as I write more frameworks, I link against code in other frameworks, so collecting everything together in a single project ensures that you can get everything necessary to compile all of these frameworks in one go- there are no external dependencies.  All of the code is always being worked on, and you should never assume that anything is "finished"- I would recommend updating the trunk whenever you get a chance.  Get in touch with me if you bump into an unfinished method or other oddity/problem- the code posted here is used in any number of other applications, and I'm always willing to fix or work on it.


How to get help
---------------

Please open an "issue".  If i'm really busy (a frequent occurrence) it may take a while for me to get back to you- sorry in advance!  Documentation is generated with 'Doxygen', and can be found here: [http://www.vidvox.net/rays_oddsnends/vvopensource_doc/index.html](http://www.vidvox.net/rays_oddsnends/vvopensource_doc/index.html)


What does this project include/do/make?
---------------------------------------

  * VVBasics is an Objective-C framework with a number of common classes which I find to be generally useful; other frameworks and applications in this project link against VVBasics.

  * VVOSC is an Objective-C framework for quickly and easily working with OSC data.  Capable of doing everything necessary to send and receive OSC data.  There are also targets for compiling, assembling, and installing an SDK which allows you to link against and use VVOSC on iPhones.

  * VVMIDI is an Objective-C framework for quickly and easily working with MIDI data.

  * VVUIToolbox is an objective-c framework that I use extensively to ease the process of creating UI items.  It contains a number of objects that standardize the act of creating, drawing, and interacting with sprites that work transparently with both NS and GL views.
  
  * VVBufferPool is an objective-c framework for creating and managing GL-backed resources.  This framework is used as the basis for the rendering engines I build for various proejcts, and is focused on the general goal of simplifying the task of "rendering to a texture" in an extensible manner to better work with a variety of APIs and formats.
  
  * DDMathParser is the [DDMathParser project by Dave DeLong](https://github.com/davedelong/DDMathParser) packaged up as a framework.  this is a slightly older version of DDMathParser (the last version capable of compiling 32-bit binaries capable of running on 10.6).  DDMathParser is used by VVISFKit to parse and evaluate mathematical expressions- it's a really neat project, you should check it out!
  
  * JSONKit is the [JSONKit project by John Engelhart](https://github.com/johnezang/JSONKit) packaged up as a framework.  VVISFKit uses JSONKit to read JSON blobs (NSJSONSerialization wasn't available until 10.7 and everything in this project can compile and run in 10.6).
  
  * VVISFKit is an objective-c framework that opens and renders ISF files.  ISF is a simple/minimal image filter format based on GLSL- more about ISF files can be found [here](http://vidvox.net/rays_oddsnends/ISF.html).
  
  * OSCTestApp is a Cocoa application used for testing and debugging OSC Applications (created entirely with VVOSC).  Capable of both sending and receiving a number of OSC data types, it also demonstrates the use of bonjour/zero-configuration networking to automatically auto-locate and set up OSC Input Ports for OSC destinations found on the local network.  In other words, two copies of OSCTestApp on different machines on the same local network will "see" each other, and automatically do the backend work necessary to send data to one another.
  
  * MIDITestApp is a Cocoa application (created using VVMIDI) used to demonstrate the sending and receiving of MIDI data.
  
  * MIDIviaOSC is a Cocoa application (created using VVMIDI and VVOSC) that lets you send MIDI data to another computer on the internet via OSC

  * the CrashReporterTestApp is a Cocoa application (created using VVBasics) which demonstrates the use of the VVCrashReporter class and can also be used to test your server-side implementation
  
  * GLScene Test App demonstrates how to do use the VVBufferPool framework to easily render-to-texture with a VVBuffer using generic GL drawing commands, as well as how to create a VVBuffer/GL texture from an image file.
  
  * QCGLScene Test App demonstrates how to use VVBufferPool to render QC compositions to GL textures, as well as how to do MSAA rendering for smoother output images under some circumstances
  
  * CIGLScene Test App demonstrates how to use VVBufferPool to convert CIImages to GL textures- this makes it very, very easy to work with CIFilters and GL textures.
  
  * ISFGLScene Test App demonstrates how to use VVBufferPool and VVISFKit to open, interact with, and render ISF files to GL textures
  
  * QT and Hap Test App demonstrates how to use VVBufferPool to render QuickTime movies to GL textures.  Also shows how to use VVBufferPool to decode Hap video frames.


I'm not a programmer, I just want to download a MIDI/OSC test application!
--------------------------------------------------------------------------

Here's an OSC test application:
http://vidvox.com/rays_oddsnends/vvopensource_downloads/OSCTestApp_0.2.4.zip

Here's an application that sends MIDI input on one computer to another computer over the network/internet using OSC:
http://vidvox.com/rays_oddsnends/vvopensource_downloads/MIDIviaOSC_0.1.3.zip

Here's an extremely crude MIDI test application ("MIDIMonitor" from snoize is much more comprehensive and fully-featured!):
http://vidvox.com/rays_oddsnends/vvopensource_downloads/MIDITestApp_1.0.5.zip


How to use these frameworks in your Mac application
---------------------------------------------------

The general idea is to compile the framework/frameworks you want to use, add them to your XCode project so you may link against them, and then set up a build phase to copy the framework into your application bundle.  This is fairly important: most of the time when you link against a framework, the framework is expected to be installed on your OS.  VVOSC, VVBasics, and VVMIDI are different: your application will include a compiled copy of the relevant framework(s), so you're guaranteed that the framework won't change outside of your control (which means you won't inherit bugs or have to deal with changed APIs until you're ready to do so).  Here's the exact procedure:

  1.  In XCode, close the VVOpenSource project (if it is open), and then open your project.
  2.  In the Finder, drag "VVOpenSource.xcodeproj" into your project's workspace.
  3.  Switch back to XCode, and locate the "Build Phases" section for your project/application's target.
  4.  Add a dependency for "vvopensource-Build Mac Frameworks".  This will ensure that all the frameworks in the vvopensource project get compiled before your project, so there won't be any missing dependencies.
  5.  Add the frameworks you want to use to the "Link Binary with Libraries" section.
  6.  Create a new "Copy Files" build phase, set its destination to the "Frameworks" folder, and add the frameworks you linked against in the previous step- the goal is to copy the frameworks you need into the "Frameworks" folder inside your app package.  When you click the "+" button to add the frameworks, they will be listed in the "Products" folder in the "vvopensource" project in your workspace.
  7.  Switch to the "Build Settings" section of your project's target, locate the "Runpath Search Paths" settings, and add the following paths: "@loader_path/../Frameworks" and "@executable_path/../Frameworks".
  8.  That's it- you're done now.  You can import/include objects from the framework in your source just as you normally would.


How to use these frameworks in a plugin
---------------------------------------

If you're writing a plugin, you need to weak-link against these frameworks.  If you don't do this and the host app which loads your plugin has a different version of these frameworks installed, you won't know which version of the framework will get used- which usually means a crash and/or generally confusing and buggy behavior.  You can prevent this by weak-linking against the frameworks: your plugin will still contain its own copy of the framework, but if the host app has already loaded a different version of the framework that will be used instead.

  1.  Follow the steps listed above for using these frameworks in a Mac application- you're going to be embedding a copy of these frameworks in your plugin just as you would for a mac app.
  2.  Double-click your plugin/target in the left-hand list of your project window (or select it and get its info).  Click on the "Build" tab, locate the "Other Linker Flags" setting, and add the following flags: "-weak_framework VVBasics", "-weak_framework VVOSC", "-weak_framework VVMIDI".


How to use VVOSC in your iPhone application
-------------------------------------------

In addition to frameworks for development of mac apps, this project can produce static libraries for use with iOS app creation.  Here's how to use the static libs in your project:
  1.  In XCode, close the VVOpenSource project (if it is open), and then open your project.
  2.  In the Finder, drag "VVOpenSource.xcodeproj" into your project's workspace
  3.  Switch back to XCode, and locate the "Build Phases" settings for your project's target.
  4.  Add a target dependency for "Build iOS static libs (VVOpenSource)".
  5.  Add "libVVBasics.a" and "libVVOSC.a" to the "Link Binary with Libraries" section.
  6.  In XCode, switch to the "Build Settings" for your application, and under the "Other Linker Flags" setting add the flag "-ObjC".
  7.  That's it- you're done now.  You can import/include objects from the VVOSC framework in your source code as you normally would (#import \<VVOSC/VVOSC.h\>).

Here's a quick video demonstrating the above steps:[http://vidvox.net/rays_oddsnends/addingVVOSC.mov].


Using VVBasics/VVOSC/etc. in closed-source iOS applications
-----------------------------------------------------------

At some point it was brought to my attention that the LGPL doesn't cover static libraries, so I hereby grant permission to treat the static lib compiled by this project as if it were a dynamic lib with respect to the terms of the LGPL.  All the terms and provisions which apply to dynamic libs are conferred to the VVOSC SDK.  If you have a question about this, feel free to either email me directly or open an issue in the project for clarification.


Documentation and sample code
-----------------------------

Doxygen was used to generate documentation for most things in this project, which can be found here:

[http://www.vidvox.net/rays_oddsnends/vvopensource_doc/index.html]

...if you're reading this on the doc page, start by checking out the "Modules", which breaks down the documentation by framework!


Licensing
---------

This project is made available under the terms of the LGPL: http://www.gnu.org/copyleft/lesser.html.  Some classes in this project use code from other open-source projects- all third-party code and licensing information is located in the top-level "external" directory.  At present, the third-party code used includes MAZeroingWeakRef from Mike Ash, DDMathParser from Dave DeLong, and JSONKit by John Engelhart.
