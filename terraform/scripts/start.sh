#! /usr/bin/env bash

pkill swift
cd .build/release
./CouchDB-Kitura
cd -
