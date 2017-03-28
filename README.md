Alinex Webobjects
=================================================

[![Build Status](https://travis-ci.org/alinex/node-webobjects.svg?branch=master)](https://travis-ci.org/alinex/node-webobjects)
[![Coverage Status](https://coveralls.io/repos/alinex/node-webobjects/badge.png?branch=master)](https://coveralls.io/r/alinex/node-webobjects?branch=master)
[![Dependency Status](https://gemnasium.com/alinex/node-webobjects.png)](https://gemnasium.com/alinex/node-webobjects)

This package contains an application which starts a small web server to interact
with the program.


> It is one of the modules of the [Alinex Namespace](http://alinex.github.io/code.html)
> following the code standards defined in the [General Docs](http://alinex.github.io/develop).


Install
-------------------------------------------------

[![NPM](https://nodei.co/npm/alinex-webobjects.png?downloads=true&downloadRank=true&stars=true)
 ![Downloads](https://nodei.co/npm-dl/alinex-webobjects.png?months=9&height=3)
](https://www.npmjs.com/package/alinex-webobjects)


Usage
-------------------------------------------------



/<group>/<class>/pid/<val1>,<val2>
/<group>/<class>/<val1>,<val2>

/<group>/<class>/<search>/name

/<group>/<class>


status -> id
title -> id
media_version -> id, name, supplier, package_license
supplier -> id, media_version
package -> id
package_license -> id, media_version

1  -> record mit action column, all records
++ -> list action in new line, only defined records

methoden
  get
  format
  record
  list
  reference
  search


2017-03-27 22:25 GMT+02:00 Alexander Schilling <alexander.reiner.schilling@googlemail.com>:

    /<group>/<class>/id/<val1>,<val2>
    /<group>/<class>/<search>/name
    /<group>/<class>/<search>

    group
      class
        title
        description
        type: database
        get
          id
            schema
              title
              type
            query: sql
          name
            schema
              title
              type
            query: sql
          title
        reference
          field
            title
            description
            access: id

    status -> id
    title -> id
    media_version -> id, name, supplier, package_license
    supplier -> id, media_version
    package -> id
    package_license -> id, media_version

    1  -> record mit action column
    ++ -> list acton in new line


    --
    Alexander Schilling




--
Alexander Schilling



License
-------------------------------------------------

Copyright 2017 Alexander Schilling

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

>  <http://www.apache.org/licenses/LICENSE-2.0>

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
