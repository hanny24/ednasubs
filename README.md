ednasubs
========

ednasubs is subtitle downloader for http://edna.cz. It tries to deduce show name, series as well as episode from filename. It also tries to select correct release, otherwise it gives you a simple list to choose from.

Usage
--------
Before anything else, you have to generate a database of TV shows. That can be done using 

``$ ednashows``

You may have to rerun this from time to time, e.g. every time a new show fanpage is created. After that you ready to roll:

``$ ednasubs my-favorite-show-s01e42.avi``

Installation
-------------
Non ruby requirements: zenity

Ruby requirements can be installed using bundler

``$ bundle install``

Notes
------
Please support your favorite TV show websites by visiting occasionally. 

Improvements, e.g. pull- requests, welcomed.